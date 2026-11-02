import 'package:engrammo/screens/kreeds_profile.dart';
import 'package:engrammo/screens/settings_screen.dart';
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

  testWidgets('beállítások: vendég módban megjelenik a kijelentkezés', (
    tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: SettingsScreen()));
    await tester.pumpAndSettle();
    expect(find.text('Sign out'), findsNothing);

    await authService.continueAsGuest();
    await tester.pumpAndSettle();
    expect(find.text('Sign out'), findsOneWidget);
  });

  testWidgets('profil: vendég módban látszik a kijelentkezés és működik', (
    tester,
  ) async {
    await authService.continueAsGuest();
    expect(authService.guestMode, isTrue);

    await tester.pumpWidget(const MaterialApp(home: KreedsProfilePage()));
    await tester.pumpAndSettle();

    final verticalScrollable = find.byWidgetPredicate(
      (w) => w is Scrollable && w.axisDirection == AxisDirection.down,
    );
    await tester.scrollUntilVisible(
      find.text('Sign out'),
      300,
      scrollable: verticalScrollable,
    );
    await tester.pumpAndSettle();
    expect(find.text('Sign out'), findsOneWidget);

    await tester.tap(find.text('Sign out'));
    await tester.pumpAndSettle();
    expect(authService.guestMode, isFalse);
    expect(find.text('Sign out'), findsNothing);
  });
}
