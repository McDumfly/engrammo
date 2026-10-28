import 'package:engrammo/screens/learning_path.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('Part header opens chapters of the current track only', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: LearningPathPage()));

    // A fő listában még nincs fejezetlista.
    expect(find.text('Chapters'), findsNothing);

    // Az első Part-kártyára koppintva fejezetlista nyílik.
    await tester.tap(find.text('Attention gate').first);
    await tester.pumpAndSettle();

    // Csak az aktuális pálya (Sensory) 5 fejezete látszik.
    expect(find.text('Chapters'), findsOneWidget);
    expect(find.text('5 chapters • Sensory track'), findsOneWidget);
    expect(find.byKey(const ValueKey('chapter-0')), findsOneWidget);
    // Más pálya fejezete (Palace Builder, Spatial) nincs a listában.
    expect(find.byKey(const ValueKey('chapter-2')), findsNothing);
    expect(find.text('Palace Builder'), findsNothing);
    // Friss fiók nulláról indul: nincs mock 3/12, minden fejezet 0/12.
    expect(find.text('0/12 done'), findsWidgets);
    expect(find.text('3/12 done'), findsNothing);

    // A jelenlegi fejezet (Echo Trail, index 0) automatikusan lenyitva:
    // benne a partok, rajtuk a feladatszám.
    expect(find.byKey(const ValueKey('chapter-0-part-0')), findsOneWidget);
    expect(find.byKey(const ValueKey('chapter-0-part-1')), findsOneWidget);
    expect(
      find.text('blocking the next-item effect • 4 tasks'),
      findsOneWidget,
    );

    // Ugyanazon pálya második fejezete görgetéssel elérhető.
    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('chapter-8')),
      200,
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('chapter-8')), findsOneWidget);

    // Más fejezet kezdetben csukva.
    expect(find.byKey(const ValueKey('chapter-8-part-0')), findsNothing);

    // Fejezet lenyitható.
    await tester.tap(find.text('Echo Chamber').first);
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('chapter-8-part-0')), findsOneWidget);

    // Partra koppintva a leckék jönnek (visszagörgetve a lista elejére).
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
