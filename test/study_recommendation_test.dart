import 'dart:convert';

import 'package:engrammo/models/memory_verdict.dart' show InterviewAnswer;
import 'package:engrammo/models/study_recommendation.dart';
import 'package:engrammo/services/meta_ai_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() => MetaAIService.consentForTest = true);
  tearDown(() => MetaAIService.consentForTest = null);

  group('heuristicStudyRecommendation', () {
    test('clear winner becomes the starting track', () {
      final r = heuristicStudyRecommendation(
        scores: const [40, 40, 100, 40, 40, 40],
        hardHits: const [0, 0, 1, 0, 0, 0],
      );
      expect(r.track, 2);
      expect(r.fallback, isTrue);
      expect(r.rationale, contains('spatial'));
      expect(r.rationale, contains('second'));
    });

    test('interview verdict picks among the tied top only', () {
      final r = heuristicStudyRecommendation(
        scores: const [100, 100, 60, 0, 0, 0],
        hardHits: const [0, 0, 0, 0, 0, 0],
        latenciesMs: const [0, 0, 0, 0, 0, 0],
        interviewKind: 1,
      );
      expect(r.track, 1);
      final r2 = heuristicStudyRecommendation(
        scores: const [100, 100, 60, 0, 0, 0],
        interviewKind: 4,
      );
      expect(r2.track, inInclusiveRange(0, 1));
    });

    test('balanced profile starts with the first tied, saying so', () {
      final r = heuristicStudyRecommendation(
        scores: const [100, 100, 60, 0, 0, 0],
      );
      expect(r.track, 0);
      expect(r.rationale, contains('Balanced'));
    });

    test('blank scores start at the first track, honestly', () {
      final r = heuristicStudyRecommendation(
        scores: const [0, 0, 0, 0, 0, 0],
      );
      expect(r.track, 0);
      expect(r.rationale, contains('No clear signal'));
      final r2 = heuristicStudyRecommendation(scores: null);
      expect(r2.track, 0);
    });

    test('blank scores with an interview verdict follow the interview', () {
      final r = heuristicStudyRecommendation(
        scores: const [0, 0, 0, 0, 0, 0],
        interviewKind: 3,
      );
      expect(r.track, 3);
      expect(r.rationale, contains('interview'));
    });
  });

  group('parseStudyRecommendationContent', () {
    test('parses track index and rationale', () {
      final r = parseStudyRecommendationContent(
        '{"track": 2, "rationale": "Start with spatial."}',
      );
      expect(r, isNotNull);
      expect(r!.track, 2);
      expect(r.rationale, contains('spatial'));
      expect(r.fallback, isFalse);
    });

    test('accepts track names and json fences', () {
      final r = parseStudyRecommendationContent(
        '```json\n{"track": "Working memory", "rationale": "ok"}\n```',
      );
      expect(r, isNotNull);
      expect(r!.track, 1);
    });

    test('rejects garbage and out-of-range tracks', () {
      expect(parseStudyRecommendationContent('not json'), isNull);
      expect(parseStudyRecommendationContent('{"track": 9}'), isNull);
      expect(parseStudyRecommendationContent('{"track": "Unknown"}'), isNull);
    });
  });

  group('MetaAIService.studyRequestBody', () {
    test('constrains the choice to the tied top', () {
      final body = MetaAIService.studyRequestBody(
        scores: const [100, 100, 60, 0, 0, 0],
        answersText: 'Q: imagery? A: I see faces clearly.',
        tiedTop: const [0, 1],
      );
      expect(body['model'], MetaAIService.taskModel);
      expect((body['response_format'] as Map)['type'], 'json_object');
      final messages = body['messages'] as List;
      final joined = messages
          .map((m) => (m as Map)['content'].toString())
          .join('\n');
      expect(joined, contains('faces clearly'));
      expect(joined, contains('ONLY'));
      expect(joined.toLowerCase(), contains('practice emphasis'));
    });

    test('clear winner is a must-pick, not a choice', () {
      final body = MetaAIService.studyRequestBody(
        scores: const [40, 40, 100, 40, 40, 40],
        answersText: '',
        tiedTop: const [2],
      );
      final messages = body['messages'] as List;
      final joined = messages
          .map((m) => (m as Map)['content'].toString())
          .join('\n');
      expect(joined, contains('MUST'));
      expect(joined, contains('2'));
    });
  });

  group('MetaAIService.recommendStudyTrack', () {
    test('no key falls back to the heuristic choice', () async {
      SharedPreferences.setMockInitialValues({});
      final r = await MetaAIService.recommendStudyTrack(
        scores: const [40, 40, 100, 40, 40, 40],
        answers: const [InterviewAnswer(questionId: 'q1-face')],
        apiKeyOverride: '',
      );
      expect(r.fallback, isTrue);
      expect(r.track, 2);
    });

    test('live answer inside the tied top is accepted', () async {
      SharedPreferences.setMockInitialValues({});
      final client = MockClient((_) async {
        return http.Response(
          jsonEncode({
            'choices': [
              {
                'message': {
                  'content':
                      '{"track": 1, "rationale": "Start with working memory."}',
                },
              },
            ],
          }),
          200,
        );
      });
      final r = await MetaAIService.recommendStudyTrack(
        scores: const [100, 100, 60, 0, 0, 0],
        answers: const [InterviewAnswer(questionId: 'q1-face')],
        tiedTop: const [0, 1],
        client: client,
        apiKeyOverride: 'test-key',
      );
      expect(r.fallback, isFalse);
      expect(r.track, 1);
    });

    test('live answer outside the tied top falls back', () async {
      SharedPreferences.setMockInitialValues({});
      final client = MockClient((_) async {
        return http.Response(
          jsonEncode({
            'choices': [
              {
                'message': {
                  'content':
                      '{"track": 5, "rationale": "Start with semantic."}',
                },
              },
            ],
          }),
          200,
        );
      });
      final r = await MetaAIService.recommendStudyTrack(
        scores: const [100, 100, 60, 0, 0, 0],
        answers: const [InterviewAnswer(questionId: 'q1-face')],
        tiedTop: const [0, 1],
        client: client,
        apiKeyOverride: 'test-key',
      );
      expect(r.fallback, isTrue);
      expect(r.track, inInclusiveRange(0, 1));
    });
  });
}
