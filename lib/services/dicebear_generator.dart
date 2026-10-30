import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:dicebear_core/dicebear_core.dart';
import 'package:dicebear_styles/avataaars.dart';
import 'package:shared_preferences/shared_preferences.dart';

class DicebearGenerator {
  static final Map<String, String> _svgCache = {};

  static String cacheKey(Map<String, String> opts) {
    final keys = opts.keys.toList()..sort();
    return keys.map((k) => '$k=${opts[k]}').join('&');
  }

  static const _prefsPrefix = 'avatar_svg_v1::';
  static const _prefsIndexKey = 'avatar_svg_keys_v1';

  static const int persistedCap = 40;

  static String _prefsKey(String key) => '$_prefsPrefix$key';

  static Map<String, String> withoutBackground(Map<String, String> opts) {
    final copy = Map<String, String>.of(opts);
    copy.remove('backgroundColor');
    return copy;
  }

  static String? cachedSvg(Map<String, String> opts) {
    final hit = _svgCache[cacheKey(opts)];
    if (hit != null) return hit;
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
    }
  }

  static Future<String> generateAvatarSvgAsync(Map<String, String> opts) async {
    final key = cacheKey(opts);
    final mem = _svgCache[key] ?? _svgCache[opts.toString()];
    if (mem != null) {
      _svgCache[key] = mem;
      return mem;
    }

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
    final Map<String, Object> dicebearOptions = {};

    if (opts['skinColor'] != null) {
      dicebearOptions['skinColor'] = [opts['skinColor']!];
    }

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

    final bg = opts['backgroundColor'];
    if (bg != null && bg.isNotEmpty && bg != 'transparent') {
      dicebearOptions['backgroundColor'] = [bg];
    }

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
