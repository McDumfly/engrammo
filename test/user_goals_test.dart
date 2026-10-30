import 'package:engrammo/models/dynamic_task.dart';
import 'package:engrammo/models/user_goals.dart';
import 'package:engrammo/services/env_loader.dart';
import 'package:engrammo/services/memory_store.dart';
import 'package:engrammo/services/meta_ai_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    EnvLoader.resetForTest();
  });

  group('goal ids', () {
    test('new ids carry the prefix and differ', () {
      final a = newGoalId();
      final b = newGoalId();
      expect(a, startsWith('goal-'));
      expect(b, startsWith('goal-'));
      expect(a, isNot(equals(b)));
    });

    test('custom target detection covers all prefixes', () {
      expect(isCustomGoalTarget('goal-123-abc'), isTrue);
      expect(isCustomGoalTarget('goal:123'), isTrue);
      expect(isCustomGoalTarget('custom:123'), isTrue);
      expect(isCustomGoalTarget('phone-numbers'), isFalse);
      expect(isCustomGoalTarget(''), isFalse);
    });

    test('fresh goals are unanalyzed with a stable id', () {
      final goal = UserGoal.fresh(title: 'Door code');
      expect(goal.id, startsWith('goal-'));
      expect(goal.title, 'Door code');
      expect(goal.analysis, isNull);
      expect(goal.practiceCount, 0);
    });
  });

  group('offline goal analysis', () {
    GoalAnalysis analyze(String title, [String extra = '']) =>
        localGoalAnalysis(title: title, details: extra);

    test('maps everyday wishes onto fixed targets', () {
      final cases = <String, String>{
        'Colleagues’ names before Monday': 'names',
        'Recognize faces at the party': 'faces',
        'The new door code 4917': 'numbers-codes',
        'Mum’s phone number': 'phone-numbers',
        'History years 1848 and 1956': 'years-dates',
        'Family birthdays': 'birthdays',
        'Electricity bill deadline': 'deadlines',
        'Shopping list for Saturday': 'todos-errands',
        'First verse of the poem': 'poems-verses',
        'Ten English words for the test': 'foreign-words',
        'Exam definitions chapter 4': 'exam-facts',
        'Everything that happened today': 'whole-day',
      };
      for (final entry in cases.entries) {
        final analysis = analyze(entry.key);
        expect(
          analysis.track,
          inInclusiveRange(0, 5),
          reason: entry.key,
        );
        expect(analysis.strategy, isNotEmpty, reason: entry.key);
        expect(analysis.paradigms, isNotEmpty, reason: entry.key);
        expect(analysis.source, isNotEmpty, reason: entry.key);
        expect(analysis.plan.length, greaterThanOrEqualTo(2), reason: entry.key);
      }
      expect(analyze('Mum’s phone number').paradigms, contains('chunk-span'));
      expect(analyze('Ten English words').paradigms, contains('keyword-pair'));
      expect(analyze('Family birthdays').track, 1);
      expect(analyze('First verse of the poem').track, 4);
    });

    test('English-only: Hungarian input falls back to retrieval practice', () {
      for (final wish in [
        'Telefonszámok fejben',
        'születésnapok',
        'vizsga tételek',
        'bevásárlólista',
        'angol szavak',
        'határidők',
        'mi történt ma',
      ]) {
        final analysis = analyze(wish);
        expect(analysis.track, 5, reason: wish);
        expect(analysis.paradigms, contains('paired-associate'), reason: wish);
      }
      expect(analyze('phone numbers').paradigms, contains('chunk-span'));
      expect(analyze('birthdays').track, 1);
      expect(analyze('exam concepts').paradigms, contains('paired-associate'));
      expect(analyze('shopping list').track, 4);
      expect(analyze('English words').paradigms, contains('keyword-pair'));
      expect(analyze('deadline').paradigms, contains('prospective-cue'));
      expect(analyze('what happened today').paradigms, contains('day-replay'));
    });

    test('short keywords cannot fire inside longer words', () {
      expect(analyze('shopping list').track, 4);
      expect(
        analyze('English conversation').paradigms,
        contains('keyword-pair'),
      );
      expect(analyze('I never remember birthdays').track, 1);
      expect(
        analyze('building vocabulary').paradigms,
        contains('keyword-pair'),
      );
      expect(analyze('reception names').paradigms, contains('face-name'));
    });

    test('unknown wishes fall back to retrieval practice', () {
      final analysis = analyze('quantum bridge rainbow');
      expect(analysis.track, 5);
      expect(analysis.paradigms, contains('paired-associate'));
      expect(analysis.source, isNotEmpty);
      expect(validateGoalAnalysis(analysis), isEmpty);
    });

    test('difficulty grows with material size', () {
      expect(goalDifficultyFor(''), 1);
      expect(goalDifficultyFor('Anna'), 1);
      expect(goalDifficultyFor('a' * 40), 2);
      expect(goalDifficultyFor('a' * 200), 3);
      expect(
        localGoalAnalysis(title: 'x', material: 'b' * 200).difficulty,
        3,
      );
    });
  });

  group('goal analysis schema', () {
    const validJson =
        '{"track":1,"strategy":"Chunk into groups of 3.",'
        '"paradigms":["chunk-span"],"source":"Miller (1956)",'
        '"plan":["Split into 3s.","Image each group."],"difficulty":2}';

    test('parses a valid answer, fences included', () {
      final plain = parseGoalAnalysisContent(validJson);
      expect(plain, isNotNull);
      expect(plain!.track, 1);
      expect(plain.paradigms, ['chunk-span']);
      expect(plain.difficulty, 2);
      final fenced = parseGoalAnalysisContent('```json\n$validJson\n```');
      expect(fenced, isNotNull);
      expect(fenced, equals(plain));
    });

    test('normalizes the echoic alias', () {
      final parsed = parseGoalAnalysisContent(
        validJson.replaceAll('chunk-span', 'echoic-probe').replaceAll(
          '"track":1',
          '"track":0',
        ),
      );
      expect(parsed, isNotNull);
      expect(parsed!.paradigms, ['iconic-probe']);
    });

    test('rejects off-schema answers', () {
      expect(parseGoalAnalysisContent('not json'), isNull);
      expect(parseGoalAnalysisContent('{"track":1}'), isNull);
      expect(
        parseGoalAnalysisContent(validJson.replaceAll('"track":1', '"track":9')),
        isNull,
      );
      expect(
        parseGoalAnalysisContent(
          validJson.replaceAll('chunk-span', 'dream-scan'),
        ),
        isNull,
      );
      expect(
        parseGoalAnalysisContent(
          validJson.replaceAll(
            'Chunk into groups of 3.',
            '  ',
          ),
        ),
        isNull,
      );
      expect(
        parseGoalAnalysisContent(
          '{"track":1,"strategy":"s","paradigms":["chunk-span"],'
          '"source":"x","plan":["only one"],"difficulty":1}',
        ),
        isNull,
      );
    });

    test('validator names each violation', () {
      const base = GoalAnalysis(
        track: 1,
        strategy: 's',
        paradigms: ['chunk-span'],
        source: 'x',
        plan: ['a', 'b'],
      );
      expect(validateGoalAnalysis(base), isEmpty);
      expect(
        validateGoalAnalysis(base.copyWith(track: 7)),
        contains('track must be 0-5'),
      );
      expect(
        validateGoalAnalysis(base.copyWith(strategy: ' ')),
        contains('empty strategy'),
      );
      expect(
        validateGoalAnalysis(base.copyWith(paradigms: ['nope'])),
        contains('unknown paradigm nope'),
      );
      expect(
        validateGoalAnalysis(base.copyWith(plan: ['a'])),
        contains('plan needs 2-6 steps'),
      );
      expect(
        validateGoalAnalysis(base.copyWith(difficulty: 0)),
        contains('difficulty must be 1-5'),
      );
    });

    test('every allowed paradigm maps to a drill kind', () {
      const expected = {
        'backward-span': 'sequence',
        'iconic-probe': 'sensory',
        'echoic-probe': 'sensory',
        'brown-peterson': 'interference',
        'chunk-span': 'number',
        'loci-drill': 'spatial',
        'picture-recall': 'visual',
        'pattern-span': 'pattern',
        'story-recall': 'episodic',
        'category-exemplar': 'semantic',
        'paired-associate': 'verbal',
        'face-name': 'face',
        'keyword-pair': 'foreign',
        'prospective-cue': 'prospective',
        'poem-chunk': 'poem',
        'day-replay': 'replay',
      };
      for (final entry in expected.entries) {
        expect(paradigmToKind(entry.key), entry.value, reason: entry.key);
      }
      expect(expected.keys.toSet(), allowedGoalParadigms);
    });

    test('goal prompt constrains the model to the registry', () {
      final prompt = goalAnalysisPrompt(
        title: 'Door code',
        material: '4917',
        locale: 'en',
      );
      expect(prompt, contains('chunk-span'));
      expect(prompt, contains('4917'));
      expect(prompt, contains('ONLY from the list'));
      expect(prompt, contains('Never diagnose'));
    });

    test('English-only: goal prompt is English even with locale hu', () {
      final prompt = goalAnalysisPrompt(
        title: 'Door code',
        material: '4917',
        locale: 'hu',
      );
      expect(prompt, contains('chunk-span'));
      expect(prompt, contains('4917'));
      expect(prompt, contains('ONLY from the list'));
      expect(prompt, contains('Never diagnose'));
      expect(prompt, isNot(contains('CSAK')));
      expect(prompt, isNot(contains('Soha')));
    });
  });

  group('custom goals inside dynamic tasks', () {
    const goalId = 'goal-1-test';

    test('request exposes the goal strategy, label, and source', () {
      const req = DynamicTaskRequest(
        targetId: goalId,
        customLabel: 'Door code',
        customStrategy: 'Chunk into groups of 3.',
        customSource: 'Miller (1956)',
      );
      expect(req.isCustomGoal, isTrue);
      expect(req.effectiveStrategy, 'Chunk into groups of 3.');
      expect(req.effectiveLabel, 'Door code');
      expect(req.effectiveSource, 'Miller (1956)');
      const fixed = DynamicTaskRequest(targetId: 'names');
      expect(fixed.isCustomGoal, isFalse);
      expect(fixed.effectiveLabel, 'Names');
    });

    test('local builder stays valid for custom goals', () {
      const req = DynamicTaskRequest(
        targetId: goalId,
        customLabel: 'Door code',
        customStrategy: 'Chunk into groups of 3.',
        customSource: 'Miller (1956)',
        userMaterial: '4917',
        seed: 'g',
      );
      final task = localDynamicTask(req);
      expect(validateDynamicTask(req, task), isEmpty);
      expect(task.title, contains('Door code'));
      expect(task.source, 'Miller (1956)');
      expect(task.blocks.first.type, DynamicBlockType.info);
    });

    test('material shape picks the input field', () {
      DynamicTask build(String material) => localDynamicTask(
        DynamicTaskRequest(
          targetId: goalId,
          customLabel: 'g',
          customStrategy: 's',
          userMaterial: material,
          seed: 'g',
        ),
      );
      expect(build('06301234567').blocks[1].type, DynamicBlockType.phone);
      expect(build('March 14').blocks[1].type, DynamicBlockType.date);
      expect(build('Anna and Bill').blocks[1].type, DynamicBlockType.text);
    });

    test('teacher and diagnose use the goal strategy', () {
      final prompt = MetaAIService.teacherRequestBody(
        targetId: goalId,
        customLabel: 'Door code',
        customStrategy: 'Chunk into groups of 3.',
      );
      expect(prompt['messages'].toString(), contains('Door code'));
      expect(
        MetaAIService.localTeacherAnswer(
          goalId,
          customLabel: 'Door code',
          customStrategy: 'Chunk into groups of 3.',
        ),
        contains('Chunk into groups of 3'),
      );
      expect(
        MetaAIService.localDiagnoseAnswer(
          goalId,
          'the last digits',
          customStrategy: 'Chunk into groups of 3.',
        ),
        contains('Chunk into groups of 3'),
      );
    });
  });

  group('goal analysis service', () {
    test('request body pins model, format, and guardrails', () {
      final body = MetaAIService.goalAnalysisRequestBody(
        title: 'Door code',
        material: '4917',
        locale: 'en',
      );
      expect(body['model'], MetaAIService.taskModel);
      expect(body['response_format'], {'type': 'json_object'});
      final messages = body['messages'] as List;
      expect(messages.length, 2);
      expect(messages.toString(), contains('4917'));
      expect(messages.toString(), contains('Never diagnose'));
    });

    test('English-only: request body is English even with locale hu', () {
      final body = MetaAIService.goalAnalysisRequestBody(
        title: 'Door code',
        material: '4917',
        locale: 'hu',
      );
      expect(body['model'], MetaAIService.taskModel);
      final messages = body['messages'] as List;
      expect(messages.toString(), contains('4917'));
      expect(messages.toString(), contains('Never diagnose'));
      expect(messages.toString(), contains('"track"'));
      expect(messages.toString(), isNot(contains('Soha')));
    });

    test('no key falls back to the offline reading', () async {
      final answer = await MetaAIService.analyzeGoal(
        title: 'Mum’s phone number',
        material: '06301234567',
      );
      expect(answer.fallback, isTrue);
      expect(answer.analysis.paradigms, contains('chunk-span'));
      expect(validateGoalAnalysis(answer.analysis), isEmpty);
    });
  });

  group('goal store', () {
    test('add, load, update, practice, delete', () async {
      expect(await MemoryStore.loadUserGoals(), isEmpty);
      final now = DateTime(2026, 1, 1);
      final goal = UserGoal.fresh(title: 'Door code', material: '4917');
      await MemoryStore.addUserGoal(
        goal.copyWith(
          createdAt: now,
          updatedAt: now,
          analysis: localGoalAnalysis(title: goal.title),
        ),
      );
      var goals = await MemoryStore.loadUserGoals();
      expect(goals, hasLength(1));
      expect(goals.first.analysis, isNotNull);
      expect(goals.first.analysis!.paradigms, contains('chunk-span'));

      await MemoryStore.updateUserGoal(
        goals.first.copyWith(material: '4917-22'),
      );
      goals = await MemoryStore.loadUserGoals();
      expect(goals.first.material, '4917-22');

      final practiced = await MemoryStore.recordGoalPractice(goals.first.id);
      expect(practiced, isNotNull);
      expect(practiced!.practiceCount, 1);
      expect(practiced.lastPracticedAt, isNotNull);

      await MemoryStore.deleteUserGoal(goals.first.id);
      expect(await MemoryStore.loadUserGoals(), isEmpty);
    });

    test('corrupt rows never kill the list', () async {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList('user_goals_v1', [
        'not-json',
        '{"id":"","title":""}',
      ]);
      expect(await MemoryStore.loadUserGoals(), isEmpty);
    });

    test('goals serialize round-trip', () {
      final goal = UserGoal.fresh(
        title: 't',
        details: 'd',
        material: 'm',
        now: DateTime(2026, 2, 2),
      ).copyWith(analysis: localGoalAnalysis(title: 'phone 123'));
      final back = UserGoal.fromJson(goal.toJson());
      expect(back.id, goal.id);
      expect(back.title, 't');
      expect(back.material, 'm');
      expect(back.analysis, equals(goal.analysis));
    });
  });
}
