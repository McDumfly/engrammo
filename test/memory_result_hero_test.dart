import 'package:engrammo/l10n/app_localizations.dart';
import 'package:engrammo/models/memory_verdict.dart';
import 'package:engrammo/models/study_recommendation.dart';
import 'package:engrammo/screens/memory_profile.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// A4: the result page shows exactly ONE conclusion — the AI pick.
/// The verdict card appears only when it disagrees with the pick.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    AppLocalizations.useCode(AppLocalizations.englishCode);
  });

  Future<void> pumpResult(
    WidgetTester tester, {
    required MemoryVerdict verdict,
    required StudyRecommendation rec,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        home: MemoryResultPage(
          scores: const [40, 40, 100, 40, 40, 40],
          verdict: verdict,
          recommendation: rec,
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  const aiRec = StudyRecommendation(track: 2, rationale: 'Start with spatial.');

  testWidgets('agreeing verdict leaves the single AI pick hero', (
    WidgetTester tester,
  ) async {
    await pumpResult(
      tester,
      verdict: const MemoryVerdict(
        kind: 2,
        confidence: 0.9,
        rationale: 'Spatial profile.',
      ),
      rec: aiRec,
    );
    expect(find.text('Your AI pick: Spatial'), findsOneWidget);
    expect(find.text('AI read of your profile: Spatial'), findsNothing);
    expect(find.text('100%'), findsOneWidget);
  });

  testWidgets('disagreeing verdict adds one dated read card', (
    WidgetTester tester,
  ) async {
    await pumpResult(
      tester,
      verdict: const MemoryVerdict(
        kind: 1,
        confidence: 0.8,
        rationale: 'Working memory profile.',
      ),
      rec: aiRec,
    );
    expect(find.text('Your AI pick: Spatial'), findsOneWidget);
    expect(
      find.text('AI read of your profile: Working memory'),
      findsOneWidget,
    );
  });

  testWidgets('local estimate hero is labelled honestly', (
    WidgetTester tester,
  ) async {
    await pumpResult(
      tester,
      verdict: const MemoryVerdict(
        kind: 0,
        confidence: 0.4,
        rationale: 'Unclear.',
        fallback: true,
      ),
      rec: const StudyRecommendation(
        track: 0,
        rationale: 'No clear signal.',
        fallback: true,
      ),
    );
    expect(find.text('Local estimate: Sensory'), findsOneWidget);
  });
}
