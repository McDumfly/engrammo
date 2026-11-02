import 'package:engrammo/models/dynamic_task.dart';
import 'package:engrammo/models/meta_task.dart';
import 'package:engrammo/screens/lesson_player.dart';
import 'package:engrammo/services/meta_ai_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('végtelen kredit: minden képkocka AI-festést kap', () {
    test('chapterImageBudget minden fejezetben az összes kört festi', () {
      for (var chapter = 0; chapter < 8; chapter++) {
        expect(chapterImageBudget(chapter, 5), 5, reason: 'chapter $chapter');
      }
      expect(chapterImageBudget(0, 0), 0);
      expect(chapterImageBudget(6, 1), 1);
    });
  });

  group('minimális gondolkodás: minden chat-hívás minimal effort', () {
    test('minden kéréstörzs reasoning_effortje minimal', () {
      const scores = [100, 60, 40, 100, 0, 40];
      final bodies = <String, Map<String, dynamic>>{
        'task': MetaAIService.taskRequestBody(
          const MetaTaskRequest(kind: 'number', difficulty: 3),
        ),
        'pattern': MetaAIService.patternRequestBody(size: 9, count: 4),
        'pictureObjects': MetaAIService.pictureObjectsRequestBody(
          labels: const ['door', 'lamp'],
          count: 2,
        ),
        'interview': MetaAIService.interviewRequestBody(
          scores: scores,
          answersText: 'a',
        ),
        'study': MetaAIService.studyRequestBody(
          scores: scores,
          answersText: 'a',
        ),
        'coach': MetaAIService.coachRequestBody(question: 'q'),
        'teacher': MetaAIService.teacherRequestBody(targetId: 'todos-errands'),
        'dynamicTask': MetaAIService.dynamicTaskRequestBody(
          const DynamicTaskRequest(targetId: 'todos-errands'),
        ),
        'diagnose': MetaAIService.diagnoseRequestBody(
          targetId: 'todos-errands',
          forgotNote: 'f',
        ),
        'goalAnalysis': MetaAIService.goalAnalysisRequestBody(title: 't'),
        'recap': MetaAIService.recapRequestBody(
          correct: 1,
          total: 2,
          trackLabel: 'l',
        ),
        'practiceTip': MetaAIService.practiceTipRequestBody(
          gameId: 'verbal',
          level: 1,
        ),
        'duelHype': MetaAIService.duelHypeRequestBody(
          foeName: 'f',
          kindLabel: 'k',
        ),
        'duelRound': MetaAIService.duelRoundRequestBody(
          paradigm: 'p',
          correct: true,
        ),
        'duelScout': MetaAIService.duelScoutRequestBody(
          kindLabel: 'k',
          rating: 1000,
          wins: 1,
          matches: 2,
        ),
        'wordBatch': MetaAIService.wordBatchRequestBody(count: 4),
        'gameRecap': MetaAIService.gameRecapRequestBody(
          gameId: 'verbal',
          score: 1,
          best: 2,
        ),
        'wonderPreview': MetaAIService.wonderPreviewRequestBody(
          route: 'r',
          stations: const ['a'],
        ),
        'glimmerTake': MetaAIService.glimmerTakeRequestBody(
          gameId: 'verbal',
          score: 1,
          best: 2,
        ),
        'openTip': MetaAIService.openTipRequestBody(
          gameId: 'verbal',
          level: 1,
        ),
      };
      for (final e in bodies.entries) {
        expect(
          e.value['reasoning_effort'],
          'minimal',
          reason: '${e.key} request body',
        );
      }
    });
  });
}
