import 'package:engrammo/screens/learning_path.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('friss fiókkal csak az első fejezet látszik a pályán', (
    WidgetTester tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(const MaterialApp(home: LearningPathPage()));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('path-lesson-0-0-0')), findsOneWidget);
    expect(find.text('Chapter 1 of 6'), findsOneWidget);
    expect(find.byKey(const ValueKey('path-lesson-8-0-0')), findsNothing);
    expect(find.text('Chapter 2 of 6'), findsNothing);
  });

  testWidgets('a fejezetlapozó a következő fejezetre vált', (
    WidgetTester tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(const MaterialApp(home: LearningPathPage()));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('chapter-next')), findsNothing);
    expect(find.byKey(const ValueKey('chapter-prev')), findsNothing);

    await tester.tap(find.byKey(const ValueKey('chapter-dot-1')));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('path-lesson-8-0-0')), findsOneWidget);
    expect(find.text('Chapter 2 of 6'), findsOneWidget);
    expect(find.byKey(const ValueKey('path-lesson-0-0-0')), findsNothing);

    await tester.tap(find.byKey(const ValueKey('chapter-dot-0')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('path-lesson-0-0-0')), findsOneWidget);
    expect(find.byKey(const ValueKey('path-lesson-8-0-0')), findsNothing);
  });

  testWidgets('a fejezetkártya simításra vált', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(const MaterialApp(home: LearningPathPage()));
    await tester.pumpAndSettle();

    await tester.fling(
      find.byKey(const ValueKey('chapter-pager')),
      const Offset(-300, 0),
      800,
    );
    await tester.pumpAndSettle();
    expect(find.text('Chapter 2 of 6'), findsOneWidget);

    await tester.fling(
      find.byKey(const ValueKey('chapter-pager')),
      const Offset(300, 0),
      800,
    );
    await tester.pumpAndSettle();
    expect(find.text('Chapter 1 of 6'), findsOneWidget);
  });

  testWidgets('befejezett fejezet után automatikusan a következő nyílik', (
    WidgetTester tester,
  ) async {
    final rows = <String>[];
    for (var s = 0; s < 3; s++) {
      for (var l = 0; l < 4; l++) {
        rows.add('0-$s-$l=3');
      }
    }
    SharedPreferences.setMockInitialValues({'chapter_progress_v1': rows});
    await tester.pumpWidget(const MaterialApp(home: LearningPathPage()));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('path-lesson-8-0-0')), findsOneWidget);
    expect(find.byKey(const ValueKey('path-lesson-0-0-0')), findsNothing);
  });
}
