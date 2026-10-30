import 'package:flutter/services.dart';

class EnvLoader {
  EnvLoader._();

  static final Map<String, String> _values = {};
  static bool _loaded = false;

  static Future<void> load({String assetPath = '.env'}) async {
    if (_loaded) return;
    _loaded = true;
    try {
      final raw = await rootBundle.loadString(assetPath);
      _values.addAll(parse(raw));
    } catch (_) {
    }
  }

  static Map<String, String> parse(String raw) {
    final out = <String, String>{};
    for (final line in raw.split('\n')) {
      final t = line.trim();
      if (t.isEmpty || t.startsWith('#')) continue;
      final i = t.indexOf('=');
      if (i <= 0) continue;
      var value = t.substring(i + 1).trim();
      if (value.length >= 2 &&
          ((value.startsWith('"') && value.endsWith('"')) ||
              (value.startsWith("'") && value.endsWith("'")))) {
        value = value.substring(1, value.length - 1);
      }
      out[t.substring(0, i).trim()] = value;
    }
    return out;
  }

  static void loadFromStringForTest(String raw) {
    _values
      ..clear()
      ..addAll(parse(raw));
    _loaded = true;
  }

  static void resetForTest() {
    _values.clear();
    _loaded = false;
  }

  static String get apiKey {
    final first = (_values['MODEL_API_KEY'] ?? '').trim();
    if (first.isNotEmpty) return first;
    return (_values['META_API_KEY'] ?? '').trim();
  }
}
