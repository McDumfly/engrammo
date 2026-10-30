import 'package:engrammo/screens/learning_path.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('masodik lecke friss fiokkal nem nyithato (sorrend zar)', (
    WidgetTester tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(const MaterialApp(home: LearningPathPage()));
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('2 names in a row'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('2 names in a row'));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('lesson-coach-next')), findsNothing);
    expect(find.byType(LearningPathPage), findsOneWidget);
  });

  testWidgets('elso lecke utan a masodik megnyilik', (
    WidgetTester tester,
  ) async {
    SharedPreferences.setMockInitialValues({
      'chapter_progress_v1': ['0-0-0=3'],
    });
    await tester.pumpWidget(const MaterialApp(home: LearningPathPage()));
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('2 names in a row'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('2 names in a row'));
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('lesson-coach-next')),
      300,
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('lesson-coach-next')), findsOneWidget);
  });

  testWidgets('harmadik lecke egy kesz utan is zarva marad', (
    WidgetTester tester,
  ) async {
    SharedPreferences.setMockInitialValues({
      'chapter_progress_v1': ['0-0-0=3'],
    });
    await tester.pumpWidget(const MaterialApp(home: LearningPathPage()));
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('During introductions'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('During introductions'));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('lesson-coach-next')), findsNothing);
    expect(find.byType(LearningPathPage), findsOneWidget);
  });

  testWidgets('part-nezetben a kesobbi lecke Locked es nem nyithato', (
    WidgetTester tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(const MaterialApp(home: LearningPathPage()));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Attention gate').first);
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('chapter-0-part-0')),
      -300,
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('chapter-0-part-0')));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('part-lesson-2')), findsOneWidget);
    expect(find.text('Locked'), findsWidgets);

    await tester.tap(find.byKey(const ValueKey('part-lesson-2')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('lesson-coach-next')), findsNothing);
  });
}
