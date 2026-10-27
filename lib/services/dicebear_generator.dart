import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:dicebear_core/dicebear_core.dart';
import 'package:dicebear_styles/avataaars.dart';
import 'package:shared_preferences/shared_preferences.dart';

class DicebearGenerator {
  static final Map<String, String> _svgCache = {};

  /// Stabil gyorsitotar-kulcs: fuggetlen a map beszurasi sorrendjetol.
  /// A profiloldal es a szerkeszto mashogy epitheti fel ugyanazt
  /// az opt-mapet, a kulcsnak megis egyeznie kell.
  static String cacheKey(Map<String, String> opts) {
    final keys = opts.keys.toList()..sort();
    return keys.map((k) => '$k=${opts[k]}').join('&');
  }

  static const _prefsPrefix = 'avatar_svg_v1::';
  static const _prefsIndexKey = 'avatar_svg_keys_v1';

  /// Ennyi SVG tarolodik lemezcache-ben legfeljebb (LRU).
  static const int persistedCap = 40;

  static String _prefsKey(String key) => '$_prefsPrefix$key';

  static Map<String, String> withoutBackground(Map<String, String> opts) {
    final copy = Map<String, String>.of(opts);
    copy.remove('backgroundColor');
    return copy;
  }

  /// Azonnali, szinkron memoriatalalat — ezzel rajzol a profiloldal
  /// uj latogatasnal is, ujrageneralas es villanas nelkul.
  static String? cachedSvg(Map<String, String> opts) {
    final hit = _svgCache[cacheKey(opts)];
    if (hit != null) return hit;
    // Kompatibilitas a regi (beszurasi sorrend fuggo) kulcsokkal:
    // egyszer meg kiszolgaljuk, es at is koltoztetjuk az uj kulcs ala.
    final legacy = _svgCache[opts.toString()];
    if (legacy != null) {
      _svgCache[cacheKey(opts)] = legacy;
    }
    return legacy;
  }

  static Future<SharedPreferences?> _prefs() async {
    try {
      return await SharedPreferences.getInstance();
    } catch (_) {
      return null;
    }
  }

  static Future<String?> _loadPersisted(String key) async {
    final prefs = await _prefs();
    if (prefs == null) return null;
    try {
      final svg = prefs.getString(_prefsKey(key));
      if (svg == null || svg.isEmpty) return null;
      return svg;
    } catch (_) {
      return null;
    }
  }

  static Future<void> _savePersisted(String key, String svg) async {
    final prefs = await _prefs();
    if (prefs == null) return;
    try {
      await prefs.setString(_prefsKey(key), svg);
      final index = prefs.getStringList(_prefsIndexKey) ?? const [];
      final next = [
        key,
        for (final k in index)
          if (k != key) k,
      ];
      // LRU-levagas: a felesleg file-jait is toroljuk.
      if (next.length > persistedCap) {
        for (final k in next.sublist(persistedCap)) {
          await prefs.remove(_prefsKey(k));
        }
      }
      await prefs.setStringList(
        _prefsIndexKey,
        next.sublist(
          0,
          next.length > persistedCap ? persistedCap : next.length,
        ),
      );
    } catch (_) {
      // A lemezcache csak gyorsitas: hiba eseten csendben eldobjuk.
    }
  }

  static Future<String> generateAvatarSvgAsync(Map<String, String> opts) async {
    final key = cacheKey(opts);
    final mem = _svgCache[key] ?? _svgCache[opts.toString()];
    if (mem != null) {
      _svgCache[key] = mem;
      return mem;
    }

    // Ujrainditas utan is cachebol: eloszor a lemez, csak utoljara szamol.
    final persisted = await _loadPersisted(key);
    if (persisted != null) {
      _svgCache[key] = persisted;
      return persisted;
    }

    final svgString = await compute(generateAvatarSvg, opts);

    _svgCache[key] = svgString;
    unawaited(_savePersisted(key, svgString));
    return svgString;
  }

  /// Generates many avatars in ONE isolate with ONE style parse.
  /// Opening a tab fires dozens of previews — without batching each of
  /// them would spawn its own isolate and re-parse the whole style.
  static Future<Map<String, String>> generateManyAsync(
    List<Map<String, String>> allOpts,
  ) async {
    final result = <String, String>{};
    final missing = <Map<String, String>>[];
    final missingKeys = <String>[];
    for (final opts in allOpts) {
      final key = cacheKey(opts);
      final hit = _svgCache[key] ?? _svgCache[opts.toString()];
      if (hit != null) {
        _svgCache[key] = hit;
        result[key] = hit;
      } else {
        missing.add(opts);
        missingKeys.add(key);
      }
    }
    if (missing.isEmpty) return result;
    // Amit a lemezcache mar tud, azt nem szamoljuk ujra.
    final prefs = await _prefs();
    final rest = <Map<String, String>>[];
    final restKeys = <String>[];
    for (var i = 0; i < missing.length; i++) {
      String? svg;
      try {
        svg = prefs?.getString(_prefsKey(missingKeys[i]));
      } catch (_) {
        svg = null;
      }
      if (svg != null && svg.isNotEmpty) {
        _svgCache[missingKeys[i]] = svg;
        result[missingKeys[i]] = svg;
      } else {
        rest.add(missing[i]);
        restKeys.add(missingKeys[i]);
      }
    }
    if (rest.isEmpty) return result;
    final fresh = await compute(_generateMany, rest);
    for (var i = 0; i < rest.length; i++) {
      final svg = fresh[rest[i].toString()];
      if (svg == null) continue;
      _svgCache[restKeys[i]] = svg;
      result[restKeys[i]] = svg;
      unawaited(_savePersisted(restKeys[i], svg));
    }
    return result;
  }

  static Map<String, String> _generateMany(List<Map<String, String>> allOpts) {
    final style = Style.parse(avataaars);
    return {
      for (final opts in allOpts) opts.toString(): _svgWithStyle(style, opts),
    };
  }

  static String generateAvatarSvg(Map<String, String> opts) {
    return _svgWithStyle(Style.parse(avataaars), opts);
  }

  static String _svgWithStyle(Style style, Map<String, String> opts) {
    // Build a strictly validated map for DiceBear
    final Map<String, Object> dicebearOptions = {};

    if (opts['skinColor'] != null) {
      dicebearOptions['skinColor'] = [opts['skinColor']!];
    }

    // Map internal short keys to exact DiceBear 'Variant' keys
    if (opts['eyes'] != null) {
      dicebearOptions['eyesVariant'] = [opts['eyes']!];
    }
    if (opts['mouth'] != null) {
      dicebearOptions['mouthVariant'] = [opts['mouth']!];
    }
    if (opts['eyebrows'] != null) {
      dicebearOptions['eyebrowsVariant'] = [opts['eyebrows']!];
    }
    if (opts['top'] != null) {
      dicebearOptions['topVariant'] = [opts['top']!];
    }
    if (opts['clothes'] != null) {
      dicebearOptions['clothesVariant'] = [opts['clothes']!];
    }
    if (opts['clothesGraphic'] != null) {
      dicebearOptions['clothesGraphicVariant'] = [opts['clothesGraphic']!];
    }

    // Map colors
    if (opts['hairColor'] != null) {
      dicebearOptions['hairColor'] = [opts['hairColor']!];
    }
    if (opts['hatColor'] != null) {
      dicebearOptions['hatColor'] = [opts['hatColor']!];
    }
    if (opts['facialHairColor'] != null) {
      dicebearOptions['facialHairColor'] = [opts['facialHairColor']!];
    }
    if (opts['clothesColor'] != null) {
      dicebearOptions['clothesColor'] = [opts['clothesColor']!];
    }
    if (opts['accessoriesColor'] != null) {
      dicebearOptions['accessoriesColor'] = [opts['accessoriesColor']!];
    }

    // Background behind everything. Only opaque values are passed —
    // 'transparent' (the default) keeps the current behavior untouched.
    final bg = opts['backgroundColor'];
    if (bg != null && bg.isNotEmpty && bg != 'transparent') {
      dicebearOptions['backgroundColor'] = [bg];
    }

    // Handle 'none' conditions strictly via Probabilities
    if (opts['facialHair'] == 'none') {
      dicebearOptions['facialHairProbability'] = 0;
    } else if (opts['facialHair'] != null) {
      dicebearOptions['facialHairVariant'] = [opts['facialHair']!];
      dicebearOptions['facialHairProbability'] = 100;
    }

    if (opts['accessories'] == 'none') {
      dicebearOptions['accessoriesProbability'] = 0;
    } else if (opts['accessories'] != null) {
      dicebearOptions['accessoriesVariant'] = [opts['accessories']!];
      dicebearOptions['accessoriesProbability'] = 100;
    }

    final avatar = Avatar(style, dicebearOptions);
    return avatar.svg;
  }
}
