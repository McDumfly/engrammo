import 'package:engrammo/models/user_goals.dart';
import 'package:engrammo/screens/learning_path.dart';
import 'package:engrammo/services/memory_store.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('a My goals ikon a felső sávban van, külön sor nélkül', (
    WidgetTester tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(const MaterialApp(home: LearningPathPage()));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('path-my-goals')), findsOneWidget);
    expect(find.text('My goals'), findsNothing);
  });

  testWidgets('a My goals ikon a célok oldalára visz', (
    WidgetTester tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(const MaterialApp(home: LearningPathPage()));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('path-my-goals')));
    await tester.pumpAndSettle();

    expect(find.text('My goals'), findsOneWidget);
    expect(find.byKey(const ValueKey('goals-list')), findsOneWidget);
  });

  testWidgets('a célok száma jelvényként látszik a My goals ikonon', (
    WidgetTester tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    await MemoryStore.addUserGoal(
      UserGoal.fresh(title: 'first', now: DateTime(2026, 1, 1)),
    );
    await MemoryStore.addUserGoal(
      UserGoal.fresh(title: 'second', now: DateTime(2026, 1, 2)),
    );
    await tester.pumpWidget(const MaterialApp(home: LearningPathPage()));
    await tester.pumpAndSettle();

    final goalsButton = find.byKey(const ValueKey('path-my-goals'));
    expect(goalsButton, findsOneWidget);
    expect(
      find.descendant(of: goalsButton, matching: find.text('2')),
      findsOneWidget,
    );
  });
}
