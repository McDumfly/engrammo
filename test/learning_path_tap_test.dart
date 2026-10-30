import 'package:engrammo/screens/learning_path.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('nincs Continue gomb, az állomás koppintásra indít', (
    WidgetTester tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(const MaterialApp(home: LearningPathPage()));
    await tester.pumpAndSettle();

    expect(find.text('Continue'), findsNothing);

    await tester.ensureVisible(find.byKey(const ValueKey('path-lesson-0-0-0')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('path-lesson-0-0-0')));
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('lesson-coach-next')),
      300,
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('lesson-coach-next')), findsOneWidget);
  });

  testWidgets('lockolt állomás koppintásra sem indul el', (
    WidgetTester tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(const MaterialApp(home: LearningPathPage()));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('path-lesson-0-1-0')), findsOneWidget);
    await tester.ensureVisible(find.byKey(const ValueKey('path-lesson-0-1-0')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('path-lesson-0-1-0')));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('lesson-coach-next')), findsNothing);
    expect(find.byType(LearningPathPage), findsOneWidget);
  });

  testWidgets('kész lecke újracsinálható az állomásról', (
    WidgetTester tester,
  ) async {
    SharedPreferences.setMockInitialValues({
      'chapter_progress_v1': ['0-0-0=3'],
    });
    await tester.pumpWidget(const MaterialApp(home: LearningPathPage()));
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.byKey(const ValueKey('path-lesson-0-0-0')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('path-lesson-0-0-0')));
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('lesson-coach-next')),
      300,
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('lesson-coach-next')), findsOneWidget);
  });
}
