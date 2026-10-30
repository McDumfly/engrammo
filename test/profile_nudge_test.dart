import 'package:engrammo/screens/kreeds_profile.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('ProfileSignInNudge: szoveg + koppintas visszahiv', (
    tester,
  ) async {
    var tapped = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ProfileSignInNudge(onTap: () => tapped++),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Save your progress'), findsOneWidget);
    expect(
      find.text('Sign in to sync scores, streak and avatar to any device.'),
      findsOneWidget,
    );

    await tester.tap(find.text('Save your progress'));
    await tester.pumpAndSettle();
    expect(tapped, 1);
  });

  testWidgets('profil backend nelkul: nincs bejelentkezesi kartya', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(const MaterialApp(home: KreedsProfilePage()));
    await tester.pumpAndSettle();

    expect(find.text('Save your progress'), findsNothing);
    expect(find.byType(ProfileSignInNudge), findsNothing);
  });
}
