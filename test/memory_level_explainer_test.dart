import 'package:engrammo/models/claims_policy.dart';
import 'package:engrammo/services/meta_ai_service.dart';
import 'package:engrammo/widgets/ai_help_button.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('memory level explainer', () {
    test('helper explains the level formula', () {
      final answer = MetaAIService.localCoachAnswer(
        'How is memory level calculated?',
      );
      expect(answer, contains('average'));
      expect(answer, contains('1–11'));
    });

    test('assessment quick prompts offer the level question', () {
      expect(
        quickPromptsFor(AiHelpTopics.assessment).join(' ').toLowerCase(),
        contains('memory level'),
      );
    });

    test('battle quick prompts offer the level question', () {
      expect(
        quickPromptsFor(AiHelpTopics.battle).join(' ').toLowerCase(),
        contains('memory level'),
      );
    });

    test('level explainer names the score sources and the mapping', () {
      expect(levelExplainer, contains('40'));
      expect(levelExplainer, contains('60'));
      expect(levelExplainer, contains('1–11'));
      for (final token in bannedClaimTokens) {
        expect(
          levelExplainer.toLowerCase(),
          isNot(contains(token)),
          reason: 'banned token "$token"',
        );
      }
    });

    test('level explainer says practice raises the level', () {
      expect(levelExplainer, contains('practice raises the level'));
      expect(levelExplainer, isNot(contains('do not change it')));
      for (final token in bannedClaimTokens) {
        expect(
          levelExplainer.toLowerCase(),
          isNot(contains(token)),
          reason: 'banned token "$token"',
        );
      }
    });

    test('raise-level question is answered with the growth rule', () {
      for (final q in [
        'How do I raise my memory level?',
        'Hogyan nő a szintem?',
      ]) {
        final answer = MetaAIService.localCoachAnswer(q);
        expect(answer, contains('practice raises the level'), reason: q);
      }
    });

    test('stars and battle answers mention level growth', () {
      expect(
        MetaAIService.localCoachAnswer('How do stars work?'),
        contains('raising memory level'),
      );
      expect(
        MetaAIService.localCoachAnswer('How does a duel work?'),
        contains('raising memory level'),
      );
    });

    test('cloud coach prompt says practice raises the level', () {
      final body = MetaAIService.coachRequestBody(
        question: 'How is memory level calculated?',
      );
      final messages = body['messages'] as List;
      expect(
        messages[0]['content'] as String,
        contains('practice raises the level'),
      );
      expect(
        messages[0]['content'] as String,
        isNot(contains('do not change it')),
      );
    });

    test('path and lesson quick prompts offer the raise-level question', () {
      expect(
        quickPromptsFor(AiHelpTopics.path),
        contains('How do I raise my memory level?'),
      );
      expect(
        quickPromptsFor(AiHelpTopics.lesson),
        contains('How do I raise my memory level?'),
      );
    });
  });
}
