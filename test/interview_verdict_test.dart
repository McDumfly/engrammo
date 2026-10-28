import 'package:engrammo/models/interview.dart';
import 'package:engrammo/models/memory_verdict.dart';
import 'package:engrammo/services/meta_ai_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('interviewQuestions', () {
    test('six questions, four options each, unique ids', () {
      expect(interviewQuestions.length, 6);
      final ids = interviewQuestions.map((q) => q.id).toList();
      expect(ids.toSet().length, ids.length);
      for (final q in interviewQuestions) {
        expect(q.prompt, isNotEmpty);
        expect(q.options.length, 4);
      }
    });

    test('every memory kind is reachable through option weights', () {
      final reached = <int>{};
      for (final q in interviewQuestions) {
        for (final o in q.options) {
          reached.addAll(o.weights.keys);
        }
      }
      expect(reached, containsAll([0, 1, 2, 3, 4, 5]));
    });

    test('never names the memory palace (untaught at this stage)', () {
      for (final q in interviewQuestions) {
        expect(q.prompt.toLowerCase(), isNot(contains('palace')));
        expect(q.hint.toLowerCase(), isNot(contains('palace')));
        for (final o in q.options) {
          expect(o.label.toLowerCase(), isNot(contains('palace')));
        }
      }
    });
  });

  group('parseVerdictContent', () {
    test('parses kind index, confidence and rationale', () {
      final v = parseVerdictContent(
        '{"dominant": 2, "confidence": 0.8, "rationale": "Strong spatial answers."}',
      );
      expect(v, isNotNull);
      expect(v!.kind, 2);
      expect(v.confidence, 0.8);
      expect(v.rationale, contains('spatial'));
      expect(v.fallback, isFalse);
    });

    test('accepts kind names and json fences', () {
      final v = parseVerdictContent(
        '```json\n{"dominant": "Visual", "confidence": 0.7, "rationale": "ok"}\n```',
      );
      expect(v, isNotNull);
      expect(v!.kind, 3);
    });

    test('rejects garbage and out-of-range kinds', () {
      expect(parseVerdictContent('not json'), isNull);
      expect(parseVerdictContent('{"dominant": 9}'), isNull);
      expect(parseVerdictContent('{"dominant": "Unknown"}'), isNull);
    });
  });

  group('heuristicVerdict (offline fallback)', () {
    test('clear score winner survives neutral answers', () {
      final answers = [
        for (final q in interviewQuestions)
          InterviewAnswer(questionId: q.id, picked: 1),
      ];
      final v = heuristicVerdict(
        scores: const [40, 40, 100, 40, 40, 40],
        hardHits: const [0, 0, 1, 0, 0, 0],
        answers: answers,
      );
      expect(v.kind, 2);
      expect(v.fallback, isTrue);
    });

    test('interview weights break a score tie', () {
      // All tied at 100: the interview leg must still crown someone.
      final answers = [
        for (final q in interviewQuestions)
          InterviewAnswer(questionId: q.id, picked: 0),
      ];
      final v = heuristicVerdict(
        scores: const [100, 100, 100, 100, 100, 100],
        hardHits: const [1, 1, 1, 1, 1, 1],
        answers: answers,
      );
      expect(v.kind, inInclusiveRange(0, 5));
      expect(v.rationale, isNotEmpty);
    });

    test('custom text keywords count toward the matching kind', () {
      final withMaps = heuristicVerdict(
        scores: const [60, 60, 60, 60, 60, 60],
        hardHits: const [0, 0, 0, 0, 0, 0],
        answers: [
          const InterviewAnswer(
            questionId: 'q2-house-walk',
            custom: 'I easily walk through my house and navigate maps in my head',
          ),
        ],
      );
      final silent = heuristicVerdict(
        scores: const [60, 60, 60, 60, 60, 60],
        hardHits: const [0, 0, 0, 0, 0, 0],
        answers: const [InterviewAnswer(questionId: 'q2-house-walk')],
      );
      expect(withMaps.kind, 2);
      expect(silent.kind, isNot(2));
    });
  });

  group('MetaAIService.interviewRequestBody', () {
    test('carries scores and answers as JSON chat request', () {
      final body = MetaAIService.interviewRequestBody(
        scores: const [100, 60, 40, 100, 0, 40],
        answersText: 'Q: imagery? A: I see faces clearly.',
      );
      expect(body['model'], MetaAIService.taskModel);
      expect(
        (body['response_format'] as Map)['type'],
        'json_object',
      );
      final messages = body['messages'] as List;
      final joined = messages
          .map((m) => (m as Map)['content'].toString())
          .join('\n');
      expect(joined, contains('100'));
      expect(joined, contains('faces clearly'));
      expect(joined.toLowerCase(), contains('dominant'));
    });
  });

  group('MetaAIService.analyzeMemoryType', () {
    test('no key falls back to the heuristic verdict', () async {
      final v = await MetaAIService.analyzeMemoryType(
        scores: const [40, 40, 100, 40, 40, 40],
        hardHits: const [0, 0, 1, 0, 0, 0],
        answers: const [InterviewAnswer(questionId: 'q1-face')],
        apiKeyOverride: '',
      );
      expect(v.fallback, isTrue);
      expect(v.kind, inInclusiveRange(0, 5));
    });
  });
}
