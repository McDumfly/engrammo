import 'strings_en.dart';
import 'strings_hu.dart';

class AppLocalizations {
  AppLocalizations._();

  static const String englishCode = 'en';
  static const String hungarianCode = 'hu';
  static const List<String> supportedCodes = [englishCode, hungarianCode];

  static String _code = englishCode;

  static String get localeCode => _code;
  static bool get isHungarian => _code == hungarianCode;

  static void useCode(String code) {
    _code = code == hungarianCode ? hungarianCode : englishCode;
  }

  static String text(String key) {
    if (isHungarian) return huStrings[key] ?? enStrings[key] ?? key;
    return enStrings[key] ?? key;
  }

  static String englishText(String key) => enStrings[key] ?? key;

  static String format(String key, [Map<String, Object>? args]) {
    var value = text(key);
    if (args != null) {
      args.forEach((name, raw) {
        value = value.replaceAll('{$name}', '$raw');
      });
    }
    return value;
  }

  static String formatFor(
    String locale,
    String key, [
    Map<String, Object>? args,
  ]) {
    var value = locale == hungarianCode
        ? (huStrings[key] ?? enStrings[key] ?? key)
        : (enStrings[key] ?? key);
    if (args != null) {
      args.forEach((name, raw) {
        value = value.replaceAll('{$name}', '$raw');
      });
    }
    return value;
  }
}

String tr(String key, [Map<String, Object>? args]) =>
    AppLocalizations.format(key, args);

String enText(String key) => AppLocalizations.englishText(key);

String trFor(String locale, String key, [Map<String, Object>? args]) =>
    AppLocalizations.formatFor(locale, key, args);
