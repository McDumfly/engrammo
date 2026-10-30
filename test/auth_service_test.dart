import 'package:engrammo/screens/auth_screen.dart';
import 'package:engrammo/services/auth_service.dart';
import 'package:engrammo/services/cloud_sync.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  tearDown(() {
    authService.exitGuest();
    CloudSync.currentUid = null;
  });

  test('backend nélkül: belépés hibát dob, az app mégis továbbmegy', () async {
    expect(authService.backendAvailable, isFalse);
    expect(authService.signedIn, isFalse);
    expect(authService.showApp, isTrue);

    await expectLater(
      authService.signInWithEmail('a@b.c', '123456'),
      throwsA(isA<AuthBackendUnavailable>()),
    );
    await expectLater(
      authService.registerWithEmail('Nev', 'a@b.c', '123456'),
      throwsA(isA<AuthBackendUnavailable>()),
    );
    await expectLater(
      authService.signInWithGoogle(),
      throwsA(isA<AuthBackendUnavailable>()),
    );
    expect(authService.signedIn, isFalse);
  });

  test('backend nélkül: vendég-folytatás helyi módban megy tovább', () async {
    expect(authService.backendAvailable, isFalse);
    await authService.continueAsGuest();
    expect(authService.guestMode, isTrue);
    expect(authService.signedIn, isFalse);
    expect(authService.showApp, isTrue);
  });

  test('friss állapot: nincs névtelen és nincs megmaradó fiók', () {
    expect(authService.signedIn, isFalse);
    expect(authService.isAnonymous, isFalse);
    expect(authService.isPermanentAccount, isFalse);
    expect(authService.needsAccountNudge, isFalse);
  });

  test('felhő-szinkron kijelentkezve csendben nem csinál semmit', () async {
    await CloudSync.pushNow();
    await CloudSync.pushFromLocal('nincs-ilyen-uid');
    await CloudSync.pullToLocal('nincs-ilyen-uid');
  });

  testWidgets('AuthScreen: belépés + regisztráció + Google-gomb', (
    tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: AuthScreen()));
    await tester.pumpAndSettle();

    expect(find.text('Welcome back'), findsOneWidget);
    expect(find.text('SIGN IN'), findsOneWidget);
    expect(find.text('CONTINUE WITH GOOGLE'), findsOneWidget);
    expect(find.text('Continue without account'), findsOneWidget);

    await tester.tap(find.text('Register'));
    await tester.pumpAndSettle();
    expect(find.text('Create account'), findsOneWidget);
    expect(find.text('CREATE ACCOUNT'), findsOneWidget);
  });
}
