import 'package:engrammo/screens/kreeds_profile.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('mérés nélkül CTA-kártya, nem hamis Sensory 0%', (tester) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(const MaterialApp(home: KreedsProfilePage()));
    await tester.pumpAndSettle();

    expect(find.text('Discover your memory type'), findsOneWidget);
    expect(find.text('STRONGEST TYPE'), findsNothing);

    // A CTA a csalásmentes bevezetőt nyitja, onnan indul a mérés.
    await tester.tap(find.text('Discover your memory type'));
    await tester.pumpAndSettle();
    expect(find.text('One rule: no cheating.'), findsOneWidget);
    await tester.tap(find.text('START — I PLAY FAIR'));
    await tester.pumpAndSettle();
    expect(find.text('Memory assessment 1/12'), findsOneWidget);
  });

  testWidgets('mérés után erős típus + újramérés', (tester) async {
    SharedPreferences.setMockInitialValues({
      'memory_scores_v1': ['40', '100', '60', '0', '40', '100'],
    });
    await tester.pumpWidget(const MaterialApp(home: KreedsProfilePage()));
    await tester.pumpAndSettle();

    expect(find.text('STRONGEST TYPE'), findsOneWidget);
    // Egyszer az identitáskártyán, egyszer a memóriatérképen.
    expect(find.text('Working memory'), findsNWidgets(2));
    expect(find.text('Retake'), findsOneWidget);
    expect(find.text('Discover your memory type'), findsNothing);
  });
}
