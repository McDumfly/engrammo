import 'package:engrammo/models/interview.dart';
import 'package:engrammo/screens/assessment_interview.dart';
import 'package:engrammo/screens/memory_profile.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('paging through every interview question never crashes', (
    WidgetTester tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(
      MaterialApp(
        home: AssessmentInterviewPage(
          scores: const [100, 80, 60, 40, 20, 0],
          hardHits: const [1, 0, 0, 0, 0, 0],
          latenciesMs: const [1000, 1000, 1000, 1000, 1000, 1000],
        ),
      ),
    );
    await tester.pumpAndSettle();

    for (var i = 0; i < interviewQuestions.length; i++) {
      final q = interviewQuestions[i];
      expect(find.text(q.prompt), findsOneWidget);
      await tester.ensureVisible(find.text(q.options.first.label));
      await tester.tap(find.text(q.options.first.label));
      await tester.pump();
      final next = i + 1 < interviewQuestions.length ? 'NEXT' : 'ANALYZE ME';
      await tester.ensureVisible(find.text(next));
      await tester.tap(find.text(next));
      await tester.pumpAndSettle();
    }

    expect(find.byType(MemoryResultPage), findsOneWidget);
  });
}
