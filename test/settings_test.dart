import 'package:engrammo/services/app_feedback.dart';
import 'package:engrammo/services/app_settings.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  tearDown(() async {
    await appSettings.setDarkMode(false);
    await appSettings.setHaptics(true);
  });

  test('Alapból világos téma és bekapcsolt rezgés', () {
    final settings = AppSettings();
    expect(settings.darkMode, isFalse);
    expect(settings.haptics, isTrue);
  });

  test('A kapcsolók értéke mentődik és visszatöltődik', () async {
    final settings = AppSettings();
    await settings.load();
    await settings.setDarkMode(true);
    await settings.setHaptics(false);

    final reloaded = AppSettings();
    await reloaded.load();
    expect(reloaded.darkMode, isTrue);
    expect(reloaded.haptics, isFalse);
  });

  test('Kikapcsolt rezgés mellett az AppFeedback némít', () async {
    expect(AppFeedback.enabled, isTrue);
    await appSettings.setHaptics(false);
    expect(AppFeedback.enabled, isFalse);
    await AppFeedback.light();
    await appSettings.setHaptics(true);
    expect(AppFeedback.enabled, isTrue);
  });
}
