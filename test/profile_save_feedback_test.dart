import 'package:engrammo/screens/settings_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  Finder fieldByHint(String hint) => find.byWidgetPredicate(
    (w) => w is TextField && w.decoration?.hintText == hint,
  );

  Color? enabledBorderColor(TextField field) {
    final border = field.decoration?.enabledBorder;
    if (border is OutlineInputBorder) return border.borderSide.color;
    return null;
  }

  testWidgets('sikeres profilmentés után zöld a név és a username kerete', (
    tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: SettingsScreen()));
    await tester.pumpAndSettle();

    await tester.enterText(fieldByHint('Your name'), 'Teszt Elek');
    await tester.enterText(fieldByHint('username'), 'teszt_elek');
    await tester.tap(find.text('SAVE PROFILE'));
    await tester.pumpAndSettle();

    expect(find.text('Saved ✓'), findsOneWidget);
    const successGreen = Color(0xFF16A34A);
    final nameField = tester.widget<TextField>(fieldByHint('Your name'));
    final usernameField = tester.widget<TextField>(fieldByHint('username'));
    expect(enabledBorderColor(nameField), successGreen);
    expect(enabledBorderColor(usernameField), successGreen);
  });

  testWidgets('érvénytelen username-nél nincs zöld keret és nincs mentés', (
    tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: SettingsScreen()));
    await tester.pumpAndSettle();

    await tester.enterText(fieldByHint('username'), 'x');
    await tester.tap(find.text('SAVE PROFILE'));
    await tester.pumpAndSettle();

    expect(find.text('Saved ✓'), findsNothing);
    const successGreen = Color(0xFF16A34A);
    final usernameField = tester.widget<TextField>(fieldByHint('username'));
    expect(enabledBorderColor(usernameField), isNot(successGreen));
  });
}
