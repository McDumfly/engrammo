import 'package:engrammo/screens/kreeds_profile.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('compactNumber', () {
    test('ezer alatt valtozatlanul irja ki', () {
      expect(compactNumber(999), '999');
      expect(compactNumber(12), '12');
    });

    test('ezreseknel E helyett K-t ir', () {
      expect(compactNumber(8450), '8.4K');
      expect(compactNumber(1000), '1.0K');
    });
  });

  testWidgets('gyors kartyak: friss fiok nullarol indul', (tester) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(const MaterialApp(home: KreedsProfilePage()));
    await tester.pumpAndSettle();

    // Friss fiók: nincs mock név, pont vagy széria.
    expect(find.text('New learner'), findsOneWidget);
    expect(find.text('@new_learner'), findsOneWidget);
    expect(find.text('8.4K'), findsNothing);
    expect(find.text('8.4E'), findsNothing);

    // A sor a kepernyo alja fele van, gorgesd lathatova.
    await tester.scrollUntilVisible(find.text('battle'), 300);
    await tester.pumpAndSettle();

    // Training kartya helyett battle Elo (az Elo alapértelmezetten 1000).
    expect(find.text('training'), findsNothing);
    expect(find.text('battle'), findsOneWidget);
    expect(find.text('1000'), findsOneWidget);

    // Liga: rangsorolás nélkül gondolatjel, az első ligában kezdve,
    // nem a korábbi mock "Infinite Mind" / "#7" / kézzel írt "Gold".
    expect(find.text('—'), findsOneWidget);
    expect(find.text('Awakening Mind I'), findsOneWidget);
    expect(find.text('Infinite Mind'), findsNothing);
    expect(find.text('#7'), findsNothing);
    expect(find.text('Gold'), findsNothing);
  });
}
