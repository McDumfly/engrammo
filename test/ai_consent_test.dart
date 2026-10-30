import 'dart:convert';

import 'package:engrammo/models/interview.dart' show interviewQuestions;
import 'package:engrammo/models/memory_verdict.dart' show InterviewAnswer;
import 'package:engrammo/screens/assessment_interview.dart';
import 'package:engrammo/screens/memory_profile.dart';
import 'package:engrammo/screens/settings_screen.dart';
import 'package:engrammo/services/meta_ai_service.dart';
import 'package:engrammo/widgets/app_buttons.dart';
import 'package:engrammo/widgets/recall_inputs.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    MetaAIService.consentForTest = null;
    MetaAIService.secureStoreForTest = null;
  });

  tearDown(() {
    MetaAIService.consentForTest = null;
    MetaAIService.secureStoreForTest = null;
  });

  http.Response okCoach(String text) => http.Response(
    jsonEncode({
      'choices': [
        {
          'finish_reason': 'stop',
          'message': {'content': text, 'role': 'assistant'},
        },
      ],
    }),
    200,
  );

  group('AI cloud consent gate', () {
    test('default OFF and persisted round-trip', () async {
      expect(await MetaAIService.cloudConsent(), isFalse);
      await MetaAIService.setCloudConsent(true);
      expect(await MetaAIService.cloudConsent(), isTrue);
      await MetaAIService.setCloudConsent(false);
      expect(await MetaAIService.cloudConsent(), isFalse);
    });

    test('no send without consent even with a key', () async {
      var calls = 0;
      final client = MockClient((_) async {
        calls++;
        return okCoach('live');
      });
      final answer = await MetaAIService.askCoach(
        'szia',
        client: client,
        apiKeyOverride: 'test-key',
      );
      expect(answer.fallback, isTrue);
      expect(calls, 0);
    });

    test('interview send blocked without consent', () async {
      var calls = 0;
      final client = MockClient((_) async {
        calls++;
        return okCoach('{"dominant": 2}');
      });
      final verdict = await MetaAIService.analyzeMemoryType(
        scores: const [40, 40, 100, 40, 40, 40],
        answers: const [InterviewAnswer(questionId: 'q1-face')],
        client: client,
        apiKeyOverride: 'test-key',
      );
      expect(verdict.fallback, isTrue);
      expect(calls, 0);
    });

    test('consent ON lets the live call through', () async {
      MetaAIService.consentForTest = true;
      var calls = 0;
      final client = MockClient((_) async {
        calls++;
        return okCoach('Elo valasz');
      });
      final answer = await MetaAIService.askCoach(
        'szia',
        client: client,
        apiKeyOverride: 'test-key',
      );
      expect(calls, 1);
      expect(answer.fallback, isFalse);
      expect(answer.text, contains('Elo valasz'));
    });
  });

  group('recall keyboard hardening', () {
    testWidgets('recall field disables rewrite/suggest/capitalize', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: RecallTextField(hint: 'Type', onSubmit: (_) {}),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final field = tester.widget<TextField>(
        find.byKey(const ValueKey('recall-input')),
      );
      expect(field.autocorrect, isFalse);
      expect(field.enableSuggestions, isFalse);
      expect(field.textCapitalization, TextCapitalization.none);
    });
  });

  group('assessment safeguards', () {
    testWidgets('progress starts at 1/13 on the first probe', (tester) async {
      SharedPreferences.setMockInitialValues({});
      await tester.pumpWidget(
        const MaterialApp(home: MemoryAssessmentPage()),
      );
      await tester.pumpAndSettle();
      final bar = tester.widget<LinearProgressIndicator>(
        find.descendant(
          of: find.byType(AppBar),
          matching: find.byType(LinearProgressIndicator),
        ),
      );
      expect(bar.value, closeTo(1 / 13, 1e-9));
    });

    testWidgets('back during assessment asks first', (tester) async {
      SharedPreferences.setMockInitialValues({});
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (ctx) => Scaffold(
              body: Center(
                child: TextButton(
                  key: const ValueKey('open-assessment'),
                  onPressed: () => Navigator.of(ctx).push(
                    MaterialPageRoute(
                      builder: (_) => const MemoryAssessmentPage(),
                    ),
                  ),
                  child: const Text('open'),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('open-assessment')));
      await tester.pumpAndSettle();

      await tester.tap(find.byType(EngramBackButton));
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('assessment-exit-dialog')),
        findsOneWidget,
      );

      await tester.tap(find.byKey(const ValueKey('assessment-exit-stay')));
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('assessment-exit-dialog')),
        findsNothing,
      );
      expect(find.byType(MemoryAssessmentPage), findsOneWidget);

      await tester.tap(find.byType(EngramBackButton));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('assessment-exit-leave')));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('open-assessment')), findsOneWidget);
    });
  });

  group('interview ask-first', () {
    Future<void> openInterview(WidgetTester tester) async {
      SharedPreferences.setMockInitialValues({});
      MetaAIService.secureStoreForTest = {'meta_api_key_v1': 'k'};
      await tester.pumpWidget(
        MaterialApp(
          home: AssessmentInterviewPage(
            scores: const [40, 40, 100, 40, 40, 40],
            hardHits: const [0, 0, 1, 0, 0, 0],
            latenciesMs: const [0, 0, 0, 0, 0, 0],
          ),
        ),
      );
      await tester.pumpAndSettle();
      for (var i = 1; i < interviewQuestions.length; i++) {
        await tester.ensureVisible(find.text('NEXT'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('NEXT'));
        await tester.pumpAndSettle();
      }
    }

    testWidgets('live key without consent asks before analyze', (
      tester,
    ) async {
      await openInterview(tester);
      await tester.ensureVisible(find.text('ANALYZE ME'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('ANALYZE ME'));
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('interview-consent-dialog')),
        findsOneWidget,
      );
    });

    testWidgets('stay offline proceeds with local verdict', (tester) async {
      await openInterview(tester);
      await tester.ensureVisible(find.text('ANALYZE ME'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('ANALYZE ME'));
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(const ValueKey('interview-consent-offline')),
      );
      await tester.pumpAndSettle();
      expect(await MetaAIService.cloudConsent(), isFalse);
      expect(find.byType(MemoryResultPage), findsOneWidget);
    });
  });

  group('settings consent switch', () {
    testWidgets('switch reflects and persists consent', (tester) async {
      SharedPreferences.setMockInitialValues({});
      await tester.pumpWidget(
        const MaterialApp(home: SettingsScreen()),
      );
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Allow cloud AI analysis'));
      await tester.pumpAndSettle();
      final switches = find.byType(Switch);
      expect(switches, findsNWidgets(3));
      expect(tester.widget<Switch>(switches.last).value, isFalse);

      await tester.tap(switches.last);
      await tester.pumpAndSettle();
      expect(await MetaAIService.cloudConsent(), isTrue);
      expect(tester.widget<Switch>(switches.last).value, isTrue);
    });
  });
}
