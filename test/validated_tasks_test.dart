import 'dart:convert';

import 'package:engrammo/models/item_banks.dart' show assessmentStories;
import 'package:engrammo/models/meta_task.dart';
import 'package:engrammo/models/validated_tasks.dart'
    show
        brownPetersonDelay,
        itemCountFor,
        paradigmPrompt,
        specForId,
        specForKind,
        validateTask;
import 'package:engrammo/services/memory_store.dart';
import 'package:engrammo/services/meta_ai_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    MetaAIService.consentForTest = true;
  });

  tearDown(() {
    MetaAIService.consentForTest = null;
  });

  group('Validated tasks: every local task traces to a paradigm', () {
    const kinds = [
      'sensory',
      'working',
      'spatial',
      'visual',
      'episodic',
      'semantic',
      'sequence',
      'number',
      'verbal',
      'pattern',
      'duel',
      'order',
      'face',
      'foreign',
      'prospective',
      'poem',
      'replay',
      'interference',
    ];

    test('local fallback carries paradigm + source for every kind', () async {
      for (final kind in kinds) {
        final task = await MetaAIService.generateTask(
          MetaTaskRequest(kind: kind, difficulty: 2, seed: 't-$kind'),
        );
        expect(task.fallback, isTrue, reason: 'no key in tests: $kind');
        expect(
          task.paradigm,
          isNotEmpty,
          reason: 'paradigm id required: $kind',
        );
        expect(task.source, isNotEmpty, reason: 'study source required: $kind');
      }
    });

    test('local fallback always offers exactly 4 options', () async {
      for (final kind in kinds) {
        for (var d = 1; d <= 5; d++) {
          final task = await MetaAIService.generateTask(
            MetaTaskRequest(kind: kind, difficulty: d, seed: 't-$kind-$d'),
          );
          expect(
            task.options.length,
            4,
            reason: '4 options required: $kind d$d',
          );
          expect(task.items, isNotEmpty, reason: 'stimulus required: $kind');
          expect(
            task.correct,
            inInclusiveRange(0, 3),
            reason: 'correct index in range: $kind',
          );
          expect(
            task.options.toSet().length,
            4,
            reason: 'options must differ: $kind d$d',
          );
        }
      }
    });

    test('local fallback is deterministic per seed', () async {
      const req = MetaTaskRequest(
        kind: 'semantic',
        difficulty: 3,
        seed: 'seed-42',
      );
      final a = await MetaAIService.generateTask(req);
      final b = await MetaAIService.generateTask(req);
      expect(a.items, orderedEquals(b.items));
      expect(a.options, orderedEquals(b.options));
      expect(a.correct, b.correct);
      expect(a.paradigm, b.paradigm);
    });

    test('AI payload outside the paradigm is rejected', () {
      const req = MetaTaskRequest(kind: 'working', difficulty: 2);
      final bad = MetaAIService.parseTaskContent(
        '{"prompt":"x","items":["1","2"],"question":"q?",'
        '"options":["a","b"],"correct":0}',
        req,
      );
      expect(bad, isNull);
      final empty = MetaAIService.parseTaskContent(
        '{"prompt":"x","items":[],"question":"q?",'
        '"options":["a","b","c","d"],"correct":9}',
        req,
      );
      expect(empty, isNull);
      final badIndex = MetaAIService.parseTaskContent(
        '{"prompt":"x","items":["4","2","9"],"question":"q?",'
        '"options":["a","b","c","d"],"correct":9}',
        req,
      );
      expect(badIndex, isNull);
    });

    test('every local task passes its own paradigm validation', () async {
      for (final kind in kinds) {
        for (var d = 1; d <= 5; d++) {
          final req = MetaTaskRequest(
            kind: kind,
            difficulty: d,
            seed: 'v-$kind-$d',
          );
          final task = await MetaAIService.generateTask(req);
          expect(
            validateTask(req, task),
            isEmpty,
            reason: 'local $kind d$d must be valid',
          );
          expect(task.paradigm, specForKind(kind).id);
        }
      }
    });

    test('registry covers every kind incl. unknown, ids round-trip', () {
      for (final kind in [...kinds, 'typo-kind', '']) {
        final spec = specForKind(kind);
        expect(spec.id, isNotEmpty);
        expect(spec.source, isNotEmpty);
        expect(specForId(spec.id).id, spec.id);
      }
      expect(
        [for (var d = 1; d <= 5; d++) itemCountFor('number', d)],
        [4, 6, 9, 12, 15],
      );
    });

    test('sensory maps to iconic probe, old echoic stamps resolve', () {
      expect(specForKind('sensory').id, 'iconic-probe');
      expect(specForId('echoic-probe').id, 'iconic-probe');
      expect(specForKind('sensory').source, contains('Sperling'));
    });

    test('interference runs the true Brown-Peterson procedure', () {
      expect(specForKind('interference').id, 'brown-peterson');
      expect(
        [for (var d = 1; d <= 5; d++) brownPetersonDelay(d)],
        [3, 3, 6, 9, 18],
      );
      final hint = paradigmPrompt(
        const MetaTaskRequest(kind: 'interference', difficulty: 5),
      );
      expect(hint, contains('brown-peterson'));
      expect(hint, contains('18 seconds'));
    });

    test('bad trigrams fail validation (vowels, repeats, wrong shape)', () {
      const req = MetaTaskRequest(kind: 'interference', difficulty: 3);
      MetaTask candidate(List<String> items, List<String> options) =>
          MetaTask(
            prompt: 'p',
            items: items,
            question: 'q?',
            options: options,
            correct: 0,
            createdAt: DateTime(2026, 1, 1),
          );
      expect(
        validateTask(
          req,
          candidate(['XJR'], ['XJR', 'KPL', 'ZVM', 'BQT']),
        ),
        isEmpty,
      );
      expect(
        validateTask(
          req,
          candidate(['XAR'], ['XAR', 'KPL', 'ZVM', 'BQT']),
        ),
        isNotEmpty,
        reason: 'vowel trigram rejected',
      );
      expect(
        validateTask(
          req,
          candidate(['XXR'], ['XXR', 'KPL', 'ZVM', 'BQT']),
        ),
        isNotEmpty,
        reason: 'repeat trigram rejected',
      );
    });

    test('lesson stories never draw reserved assessment items', () async {
      final assess = assessmentStories.map((s) => s.text).toSet();
      for (var i = 0; i < 30; i++) {
        final task = await MetaAIService.generateTask(
          MetaTaskRequest(kind: 'episodic', difficulty: 2, seed: 'bank-$i'),
        );
        expect(assess, isNot(contains(task.items.first)));
      }
    });
  });

  group('Interview tie-only rule', () {
    test('clear winner is forced, ties restrict the pick', () {
      final forced = MetaAIService.interviewRequestBody(
        scores: const [40, 100, 40, 40, 40, 40],
        answersText: 'n/a',
        tiedTop: const [1],
      );
      final forcedText = _joinedMessages(forced);
      expect(forcedText, contains('CLEAR winner'));
      expect(forcedText, contains('MUST return that index'));
      final tied = MetaAIService.interviewRequestBody(
        scores: const [100, 100, 40, 40, 40, 40],
        answersText: 'n/a',
        tiedTop: const [0, 1],
      );
      final tiedText = _joinedMessages(tied);
      expect(tiedText, contains('TIED'));
      expect(tiedText, contains('ONLY'));
      expect(tiedText, contains('0, 1'));
    });

    test('AI verdict outside the tied top is discarded', () async {
      MockClient clientFor(int dominant) => MockClient((_) async {
        return http.Response(
          jsonEncode({
            'choices': [
              {
                'message': {
                  'content': jsonEncode({
                    'dominant': dominant,
                    'confidence': 0.9,
                    'rationale': 'Mock verdict.',
                  }),
                },
              },
            ],
          }),
          200,
        );
      });
      final outside = await MetaAIService.analyzeMemoryType(
        scores: const [40, 100, 40, 40, 40, 40],
        answers: const [],
        tiedTop: const [1],
        client: clientFor(5),
        apiKeyOverride: 'k',
      );
      expect(outside.fallback, isTrue);
      final inside = await MetaAIService.analyzeMemoryType(
        scores: const [40, 100, 40, 40, 40, 40],
        answers: const [],
        tiedTop: const [1],
        client: clientFor(1),
        apiKeyOverride: 'k',
      );
      expect(inside.fallback, isFalse);
      expect(inside.kind, 1);
    });
  });

  group('Assessment parallel forms', () {
    test('finished runs rotate Forms A-D', () async {
      expect(await MemoryStore.loadAssessmentRuns(), 0);
      await MemoryStore.saveScores([100, 40, 40, 40, 40, 40]);
      expect(await MemoryStore.loadAssessmentRuns(), 1);
      await MemoryStore.saveScores([100, 40, 40, 40, 40, 40]);
      expect(await MemoryStore.loadAssessmentRuns(), 2);
    });

    test('cloud download does not consume a form turn', () async {
      await MemoryStore.saveScoresWithoutNotify([40, 40, 40, 40, 40, 40]);
      expect(await MemoryStore.loadAssessmentRuns(), 0);
    });
  });
}

String _joinedMessages(Map<String, dynamic> body) {
  final messages = body['messages'] as List;
  return messages.map((m) => (m as Map)['content'].toString()).join('\n');
}
