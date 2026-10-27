import 'package:engrammo/screens/learning_path.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('Part header opens chapters with progress and expandable parts',
      (WidgetTester tester) async {
    await tester.pumpWidget(const MaterialApp(home: LearningPathPage()));

    // A fő listában még nincs fejezetlista.
    expect(find.text('Chapters'), findsNothing);

    // Az első Part-kártyára koppintva fejezetlista nyílik.
    await tester.tap(find.text('First room').first);
    await tester.pumpAndSettle();

    // Fejezetek egymás alatt, progressbarral.
    expect(find.text('Chapters'), findsOneWidget);
    expect(find.byKey(const ValueKey('chapter-0')), findsOneWidget);
    expect(find.byKey(const ValueKey('chapter-2')), findsOneWidget);
    expect(find.text('3/12 done'), findsWidgets);

    // A jelenlegi fejezet (Palace Builder, index 2) automatikusan lenyitva:
    // benne a partok, rajtuk a feladatszám.
    expect(
      find.byKey(const ValueKey('chapter-2-part-0')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('chapter-2-part-1')),
      findsOneWidget,
    );
    expect(
      find.text('loci method • 5 stations • 4 tasks'),
      findsOneWidget,
    );

    // Más fejezet kezdetben csukva.
    expect(
      find.byKey(const ValueKey('chapter-0-part-0')),
      findsNothing,
    );

    // Fejezet lenyitható.
    await tester.tap(find.text('Echo Trail').first);
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('chapter-0-part-0')),
      findsOneWidget,
    );

    // Partra koppintva a leckék jönnek.
    await tester.ensureVisible(
      find.byKey(const ValueKey('chapter-2-part-0')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('chapter-2-part-0')));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('part-lesson-1')),
      findsOneWidget,
    );
    expect(find.text('Step 1 of 4'), findsOneWidget);
  });
}
