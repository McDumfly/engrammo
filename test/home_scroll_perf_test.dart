import 'package:engrammo/screens/learning_path.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  Finder flowList(WidgetTester tester) {
    final lists = find.descendant(
      of: find.byType(LearningPathPage),
      matching: find.byType(SingleChildScrollView),
    );
    expect(lists, findsOneWidget);
    return lists.first;
  }

  testWidgets('a folyó listájában nincs Opacity-réteg', (
    WidgetTester tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(const MaterialApp(home: LearningPathPage()));
    await tester.pumpAndSettle();

    final list = flowList(tester);
    final opacities = find.descendant(of: list, matching: find.byType(Opacity));
    expect(opacities, findsNothing);
  });

  testWidgets('a folyó listájában nincs elmosott árnyék', (
    WidgetTester tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(const MaterialApp(home: LearningPathPage()));
    await tester.pumpAndSettle();

    final list = flowList(tester);
    final containers = find.descendant(
      of: list,
      matching: find.byType(Container),
    );
    var blurred = 0;
    for (final element in containers.evaluate()) {
      final widget = element.widget as Container;
      final decoration = widget.decoration;
      if (decoration is! BoxDecoration) continue;
      final shadows = decoration.boxShadow;
      if (shadows == null) continue;
      for (final shadow in shadows) {
        if (shadow.blurRadius > 0) blurred++;
      }
    }
    expect(blurred, 0);
  });
}
