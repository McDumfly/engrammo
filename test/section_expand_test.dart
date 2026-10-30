import 'package:engrammo/screens/learning_path.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('Part header opens chapters of the current track only', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: LearningPathPage()));

    expect(find.text('Chapters'), findsNothing);

    await tester.tap(find.text('Attention gate').first);
    await tester.pumpAndSettle();

    expect(find.text('Chapters'), findsOneWidget);
    expect(find.text('6 chapters • Sensory track'), findsOneWidget);
    expect(find.byKey(const ValueKey('chapter-0')), findsOneWidget);
    expect(find.byKey(const ValueKey('chapter-2')), findsNothing);
    expect(find.text('Palace Builder'), findsNothing);
    expect(find.text('0/12 done'), findsWidgets);
    expect(find.text('3/12 done'), findsNothing);

    expect(find.byKey(const ValueKey('chapter-0-part-0')), findsOneWidget);
    expect(find.byKey(const ValueKey('chapter-0-part-1')), findsOneWidget);
    expect(
      find.text('blocking the next-item effect • 4 tasks'),
      findsOneWidget,
    );

    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('chapter-8')),
      200,
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('chapter-8')), findsOneWidget);

    expect(find.byKey(const ValueKey('chapter-8-part-0')), findsNothing);

    await tester.tap(find.text('Echo Chamber').first);
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('chapter-8-part-0')), findsOneWidget);

    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('chapter-0-part-0')),
      -300,
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('chapter-0-part-0')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('part-lesson-1')), findsOneWidget);
    expect(find.text('Step 1 of 4'), findsOneWidget);
  });
}
