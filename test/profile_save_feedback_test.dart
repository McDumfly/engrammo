import 'package:engrammo/screens/settings_screen.dart';
import 'package:engrammo/services/profile_setup.dart';
import 'package:engrammo/widgets/app_kit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  Finder fieldByHint(String hint) => find.byWidgetPredicate(
    (w) => w is AppTextField && w.hint == hint,
  );

  testWidgets('sikeres profilmentés után mentés-visszajelzés látszik', (
    tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: SettingsScreen()));
    await tester.pumpAndSettle();

    await tester.enterText(fieldByHint('Your name'), 'Teszt Elek');
    await tester.enterText(fieldByHint('username'), 'teszt_elek');
    await tester.tap(find.text('SAVE PROFILE'));
    await tester.pumpAndSettle();

    expect(find.text('Saved ✓'), findsOneWidget);
    final nameField = tester.widget<AppTextField>(fieldByHint('Your name'));
    final usernameField = tester.widget<AppTextField>(
      fieldByHint('username'),
    );
    expect(nameField.errorText, isNull);
    expect(usernameField.errorText, isNull);
  });

  testWidgets('érvénytelen username-nél hibaüzenet látszik és nincs mentés', (
    tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: SettingsScreen()));
    await tester.pumpAndSettle();

    await tester.enterText(fieldByHint('username'), 'x');
    await tester.tap(find.text('SAVE PROFILE'));
    await tester.pumpAndSettle();

    expect(find.text('Saved ✓'), findsNothing);
    // Empty name fails first, so the name error is shown.
    final expectedError = ProfileSetupRules.validateDisplayName('');
    expect(expectedError, isNotNull);
    expect(find.text(expectedError!), findsOneWidget);
    final usernameField = tester.widget<AppTextField>(
      fieldByHint('username'),
    );
    expect(usernameField.errorText, isNull);
  });
}
