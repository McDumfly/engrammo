import 'package:engrammo/screens/learning_path.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('a fejezetkártya fix marad, csak az útvonal gördül', (
    WidgetTester tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(const MaterialApp(home: LearningPathPage()));
    await tester.pumpAndSettle();

    final pager = find.byKey(const ValueKey('chapter-pager'));
    final firstStation = find.byKey(
      const ValueKey('path-lesson-0-0-0'),
    );
    expect(pager, findsOneWidget);
    expect(firstStation, findsOneWidget);

    final pagerBefore = tester.getTopLeft(pager);
    final stationBefore = tester.getTopLeft(firstStation);

    await tester.drag(
      find.byType(SingleChildScrollView),
      const Offset(0, -400),
    );
    await tester.pumpAndSettle();

    // Az útvonal tényleg elgördült...
    final stationAfter = tester.getTopLeft(firstStation);
    expect(stationAfter.dy, lessThan(stationBefore.dy));

    // ...de a fejezetkártya a helyén maradt.
    expect(pager, findsOneWidget);
    final pagerAfter = tester.getTopLeft(pager);
    expect(pagerAfter.dy, pagerBefore.dy);
  });
}
