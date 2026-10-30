import 'package:engrammo/screens/learning_path.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('a Learning track képernyőn van Retake memory test opció', (
    WidgetTester tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(const MaterialApp(home: LearningPathPage()));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('stats-track-icon')));
    await tester.pumpAndSettle();

    expect(find.text('Learning track'), findsOneWidget);
    expect(find.text('Retake memory test'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('track-retake-assessment')),
      findsOneWidget,
    );
  });

  testWidgets('a retake kártya a memóriateszt bevezetőjére visz', (
    WidgetTester tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(const MaterialApp(home: LearningPathPage()));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('stats-track-icon')));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('track-retake-assessment')));
    await tester.pumpAndSettle();

    expect(find.text('One rule: no cheating.'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('START — I PLAY FAIR'),
      300,
    );
    await tester.pumpAndSettle();
    expect(find.text('START — I PLAY FAIR'), findsOneWidget);
  });

  testWidgets('a sávválasztás az új első sor mellett is működik', (
    WidgetTester tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(const MaterialApp(home: LearningPathPage()));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('stats-track-icon')));
    await tester.pumpAndSettle();

    expect(find.text('Sensory'), findsOneWidget);
    expect(find.text('Spatial'), findsOneWidget);

    await tester.tap(find.text('Spatial'));
    await tester.pumpAndSettle();

    expect(find.text('Learning track'), findsNothing);
    expect(find.byType(LearningPathPage), findsOneWidget);
  });
}
