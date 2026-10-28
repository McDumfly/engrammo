import 'package:flutter/services.dart';

/// A gitignore-olt `.env` fájl tartalma sima `flutter run` esetén is.
///
/// A `--dart-define` csak fordításkor jut be az appba, ezért a sima
/// indítás (VS Code F5 / `flutter run`) eddig nem látta a `.env`-be írt
/// kulcsot — csak a `tool/run.sh` látta. Ez a betöltő a becsomagolt
/// `.env` assetet olvassa vissza futáskor, így nem kell külön szkript.
///
/// A `.env` továbbra is gitignore-olt: a kulcs csak a saját gépeden
/// lévő buildbe kerül be, gitre soha.
class EnvLoader {
  EnvLoader._();

  static final Map<String, String> _values = {};
  static bool _loaded = false;

  /// Betöltés egyszer, az első képkocka előtt ([main]-ből hívva).
  /// Hiányzó fájl esetén csendben üres marad (offline tartalék fut).
  static Future<void> load({String assetPath = '.env'}) async {
    if (_loaded) return;
    _loaded = true;
    try {
      final raw = await rootBundle.loadString(assetPath);
      _values.addAll(parse(raw));
    } catch (_) {
      // Nincs becsomagolt `.env` (pl. friss klón): marad az üres.
    }
  }

  /// `.env` szöveg feldolgozása (`KEY=érték`, `#` megjegyzéssel).
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

  /// Teszt / előnézet: nyers szövegből betöltés asset nélkül.
  static void loadFromStringForTest(String raw) {
    _values
      ..clear()
      ..addAll(parse(raw));
    _loaded = true;
  }

  /// Visszaállítás tesztek közé (üres állapot).
  static void resetForTest() {
    _values.clear();
    _loaded = false;
  }

  /// A `.env`-ből jövő kulcs (első a `MODEL_API_KEY`, utána a régi név).
  static String get apiKey {
    final first = (_values['MODEL_API_KEY'] ?? '').trim();
    if (first.isNotEmpty) return first;
    return (_values['META_API_KEY'] ?? '').trim();
  }
}
