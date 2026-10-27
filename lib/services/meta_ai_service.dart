import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../models/meta_image.dart';
import '../models/meta_segment.dart';
import '../models/meta_task.dart';

/// Egy Meta-hívás naplóbejegyzése (verseny-demó megfigyelhetőség).
class MetaCallEntry {
  final String model;
  final String kind;
  final DateTime at;
  final bool success;
  final bool fallback;
  final String note;

  const MetaCallEntry({
    required this.model,
    required this.kind,
    required this.at,
    required this.success,
    required this.fallback,
    this.note = '',
  });

  Map<String, dynamic> toJson() => {
    'model': model,
    'kind': kind,
    'at': at.toIso8601String(),
    'success': success,
    'fallback': fallback,
    'note': note,
  };

  factory MetaCallEntry.fromJson(Map<String, dynamic> json) {
    final at = DateTime.tryParse(json['at'] as String? ?? '');
    return MetaCallEntry(
      model: (json['model'] as String?) ?? 'unknown',
      kind: (json['kind'] as String?) ?? 'task',
      at: at ?? DateTime.fromMillisecondsSinceEpoch(0),
      success: (json['success'] as bool?) ?? false,
      fallback: (json['fallback'] as bool?) ?? true,
      note: (json['note'] as String?) ?? '',
    );
  }
}

/// Best-effort Meta AI réteg a helyi generátorok mögött.
///
/// - Ha nincs `--dart-define META_API_BASE_URL` / `META_API_KEY`,
///   vagy nincs háló, a hívók a mai helyi tartalmat kapják vissza
///   `fallback: true` jelöléssel (az app nem omlik össze).
/// - Minden kísérlet naplózódik ([lastCalls], perzisztálva is).
/// - Kulcs soha nem kerül `firebase_options.dart`-szerű fájlba.
class MetaAIService {
  static const String taskModel = 'muse-spark-task-v1';
  static const String imageModel = 'muse-image-v1';
  static const String segmentModel = 'sam-3.1-palace-v1';

  static const _baseUrlEnv = 'META_API_BASE_URL';
  static const _apiKeyEnv = 'META_API_KEY';

  static const _logKey = 'meta_call_log_v1';
  static const int logCap = 50;

  static const int httpTimeoutSec = 8;

  static final List<MetaCallEntry> _calls = [];

  /// Legutóbbi hívások (legfrissebb elöl).
  static List<MetaCallEntry> get lastCalls =>
      List<MetaCallEntry>.unmodifiable(_calls);

  static String get baseUrl =>
      const String.fromEnvironment(_baseUrlEnv, defaultValue: '');

  static String get apiKey =>
      const String.fromEnvironment(_apiKeyEnv, defaultValue: '');

  static bool get configured => baseUrl.isNotEmpty && apiKey.isNotEmpty;

  /// Napló betöltése a helyi tárolóból (beállítás-képernyőnek).
  static Future<List<MetaCallEntry>> loadLog() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getStringList(_logKey) ?? const [];
      return [
        for (final e in raw)
          if (e.isNotEmpty)
            MetaCallEntry.fromJson(
              jsonDecode(e) as Map<String, dynamic>,
            ),
      ];
    } catch (_) {
      return const [];
    }
  }

  static Future<void> _log(MetaCallEntry entry) async {
    _calls.insert(0, entry);
    if (_calls.length > logCap) {
      _calls.removeRange(logCap, _calls.length);
    }
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(_logKey, [
        for (final e in _calls.take(logCap)) jsonEncode(e.toJson()),
      ]);
    } catch (_) {
      // A napló csak megfigyelhetőség: hiba esetén eldobjuk.
    }
  }

  /// Feladat-generálás: Spark először, hiba esetén helyi tartalék.
  static Future<MetaTask> generateTask(
    MetaTaskRequest req, {
    http.Client? client,
  }) async {
    if (!configured) {
      final t = _localTask(req);
      await _log(
        MetaCallEntry(
          model: taskModel,
          kind: 'task:${req.kind}',
          at: DateTime.now(),
          success: true,
          fallback: true,
          note: 'nincs META_API konfig, helyi tartalék',
        ),
      );
      return t;
    }
    try {
      final c = client ?? http.Client();
      final res = await c
          .post(
            Uri.parse('$baseUrl/v1/task'),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $apiKey',
            },
            body: jsonEncode(req.toJson()),
          )
          .timeout(const Duration(seconds: httpTimeoutSec));
      if (res.statusCode >= 200 && res.statusCode < 300) {
        final data = jsonDecode(res.body);
        if (data is Map<String, dynamic>) {
          final task = MetaTask.fromJson(data).copyWith(
            model: taskModel,
            fallback: false,
          );
          await _log(
            MetaCallEntry(
              model: taskModel,
              kind: 'task:${req.kind}',
              at: DateTime.now(),
              success: true,
              fallback: false,
            ),
          );
          return task;
        }
      }
      throw StateError('HTTP ${res.statusCode}');
    } catch (e) {
      debugPrint('MetaAIService.generateTask tartalék: $e');
      final t = _localTask(req);
      await _log(
        MetaCallEntry(
          model: taskModel,
          kind: 'task:${req.kind}',
          at: DateTime.now(),
          success: false,
          fallback: true,
          note: e.toString(),
        ),
      );
      return t;
    }
  }

  /// Kép-generálás: Muse minta először, hiba esetén üres tartalék.
  static Future<MetaImage> generateImage(
    MetaImageRequest req, {
    http.Client? client,
  }) async {
    if (!configured) {
      await _log(
        MetaCallEntry(
          model: imageModel,
          kind: 'image',
          at: DateTime.now(),
          success: true,
          fallback: true,
          note: 'nincs META_API konfig, helyi tartalék',
        ),
      );
      return MetaImage(
        promptHash: req.promptHash,
        cacheKey: req.cacheKey,
        createdAt: DateTime.now(),
      );
    }
    try {
      final c = client ?? http.Client();
      final res = await c
          .post(
            Uri.parse('$baseUrl/v1/image'),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $apiKey',
            },
            body: jsonEncode(req.toJson()),
          )
          .timeout(const Duration(seconds: httpTimeoutSec));
      if (res.statusCode >= 200 && res.statusCode < 300) {
        final data = jsonDecode(res.body);
        if (data is Map<String, dynamic>) {
          final img = MetaImage.fromJson(data).copyWith(
            promptHash: req.promptHash,
            cacheKey: req.cacheKey,
            model: imageModel,
            fallback: false,
          );
          await _log(
            MetaCallEntry(
              model: imageModel,
              kind: 'image',
              at: DateTime.now(),
              success: true,
              fallback: false,
            ),
          );
          return img;
        }
      }
      throw StateError('HTTP ${res.statusCode}');
    } catch (e) {
      debugPrint('MetaAIService.generateImage tartalék: $e');
      await _log(
        MetaCallEntry(
          model: imageModel,
          kind: 'image',
          at: DateTime.now(),
          success: false,
          fallback: true,
          note: e.toString(),
        ),
      );
      return MetaImage(
        promptHash: req.promptHash,
        cacheKey: req.cacheKey,
        createdAt: DateTime.now(),
      );
    }
  }

  /// Térbeli szegmentálás (SAM 3.1): csak a Palace útvonal hívja.
  static Future<MetaSegment> segment(
    MetaSegmentRequest req, {
    http.Client? client,
  }) async {
    if (!configured) {
      await _log(
        MetaCallEntry(
          model: segmentModel,
          kind: 'segment',
          at: DateTime.now(),
          success: true,
          fallback: true,
          note: 'nincs META_API konfig, üres maszk',
        ),
      );
      return MetaSegment(createdAt: DateTime.now());
    }
    try {
      final c = client ?? http.Client();
      final res = await c
          .post(
            Uri.parse('$baseUrl/v1/segment'),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $apiKey',
            },
            body: jsonEncode(req.toJson()),
          )
          .timeout(const Duration(seconds: httpTimeoutSec));
      if (res.statusCode >= 200 && res.statusCode < 300) {
        final data = jsonDecode(res.body);
        if (data is Map<String, dynamic>) {
          final seg = MetaSegment.fromJson(data).copyWith(
            model: segmentModel,
            fallback: false,
          );
          await _log(
            MetaCallEntry(
              model: segmentModel,
              kind: 'segment',
              at: DateTime.now(),
              success: true,
              fallback: false,
            ),
          );
          return seg;
        }
      }
      throw StateError('HTTP ${res.statusCode}');
    } catch (e) {
      debugPrint('MetaAIService.segment tartalék: $e');
      await _log(
        MetaCallEntry(
          model: segmentModel,
          kind: 'segment',
          at: DateTime.now(),
          success: false,
          fallback: true,
          note: e.toString(),
        ),
      );
      return MetaSegment(createdAt: DateTime.now());
    }
  }

  // ── Helyi tartalékok (a mai generátorok Meta-alakra hozva) ──────

  static final _rnd = Random();

  static MetaTask _localTask(MetaTaskRequest req) {
    final now = DateTime.now();
    switch (req.kind) {
      case 'number':
        final digits = 3 + (req.difficulty.clamp(1, 5) - 1);
        final sb = StringBuffer('${1 + _rnd.nextInt(9)}');
        for (var i = 1; i < digits; i++) {
          sb.write(_rnd.nextInt(10));
        }
        final num = sb.toString();
        final opts = <String>{num};
        while (opts.length < 4) {
          final d = StringBuffer('${1 + _rnd.nextInt(9)}');
          for (var i = 1; i < digits; i++) {
            d.write(_rnd.nextInt(10));
          }
          opts.add(d.toString());
        }
        final list = opts.toList()..shuffle(_rnd);
        return MetaTask(
          prompt: 'Jegyezd meg ezt a számot!',
          items: [num],
          question: 'Melyik számot láttad?',
          options: list,
          correct: list.indexOf(num),
          explanation: 'Képi társítás: bonts chunks-okra (pl. $num).',
          createdAt: now,
        );
      case 'verbal':
        const pool = ['alma', 'híd', 'kert', 'lámpa', 'tenger', 'kulcs'];
        final w = pool[_rnd.nextInt(pool.length)];
        final opts = <String>{w};
        while (opts.length < 4) {
          opts.add(pool[_rnd.nextInt(pool.length)]);
        }
        final list = opts.toList()..shuffle(_rnd);
        return MetaTask(
          prompt: 'Láttad ezt a szót?',
          items: [w],
          question: 'Melyik szó szerepelt?',
          options: list,
          correct: list.indexOf(w),
          explanation: 'Kulcsszó-technika: kösd képhez a szót.',
          createdAt: now,
        );
      case 'sequence':
        final len = 3 + req.difficulty.clamp(1, 5);
        final seq = [for (var i = 0; i < len; i++) '${_rnd.nextInt(9)}'];
        return MetaTask(
          prompt: 'Ismételd meg a villanó sorozatot!',
          items: seq,
          question: 'Mi volt a sorrend?',
          options: [seq.join('-'), seq.reversed.join('-')],
          correct: 0,
          explanation: 'Chunking: hármasával csoportosítsd.',
          createdAt: now,
        );
      case 'visual':
      case 'spatial':
        final cells = [for (var i = 0; i < 9; i++) '$i'];
        cells.shuffle(_rnd);
        final lit = cells.take(3).toList();
        return MetaTask(
          prompt: 'Melyik csempe világított?',
          items: lit,
          question: 'Melyik csempe volt köztük?',
          options: [lit.first, '9', '8', '7'],
          correct: 0,
          explanation: 'Loci: helyezd a mintát egy palota-útvonalra.',
          createdAt: now,
        );
      default:
        final seq = [for (var i = 0; i < 3; i++) '${_rnd.nextInt(10)}'];
        return MetaTask(
          prompt: 'Jegyezd meg ezt a számsort!',
          items: seq,
          question: 'Mi volt a középső szám?',
          options: [seq[1], '5', seq[0], seq[2]],
          correct: 0,
          explanation: 'Figyelem-kapu: mondd ki magadban egyszer.',
          createdAt: now,
        );
    }
  }
}
