import 'dart:convert';

import 'package:flutter/services.dart';

import '../models/recall_scoring.dart' show normalizeAnswer;
import '../services/meta_ai_service.dart' show PictureRecallRound;
import '../utils/test_mode.dart';

/// Honest offline-proof demo: a recording of a REAL sample-room run.
///
/// The JSON files `assets/demo/sample_run_<locale>.json` are created ONLY
/// by the debug capture tool from a live run — never hand-written. While
/// they are missing [DemoReplay.load] returns null and the app behaves
/// exactly as today.
class DemoReplay {
  final DateTime recordedAt;
  final String locale;
  final List<List<Object>> events;
  final List<String> labels;
  final List<List<double>> boxes;
  final List<String> masks;
  final int totalMs;
  final List<String> items;
  final List<String> links;
  final List<String> dreams;
  final List<Map<String, dynamic>> receipt;

  const DemoReplay({
    required this.recordedAt,
    required this.locale,
    required this.events,
    required this.labels,
    required this.boxes,
    required this.masks,
    required this.totalMs,
    required this.items,
    required this.links,
    required this.dreams,
    required this.receipt,
  });

  /// Loads the recorded run for [locale], or null when the asset is
  /// missing. Never throws. Test-fast: no asset lookup under flutter
  /// test, where the files never exist — the app then behaves exactly
  /// as today.
  static Future<DemoReplay?> load(String locale) async {
    if (isFlutterTest) return null;
    try {
      final code = locale == 'hu' ? 'hu' : 'en';
      final raw = await rootBundle.loadString(
        'assets/demo/sample_run_$code.json',
      );
      final parsed = jsonDecode(raw);
      if (parsed is! Map<String, dynamic>) return null;
      return DemoReplay.fromJson(parsed);
    } catch (_) {
      return null;
    }
  }

  /// Parses a recorded run. Never throws: malformed parts become empty.
  factory DemoReplay.fromJson(Map<String, dynamic> json) {
    List<String> stringsOf(Object? raw) {
      if (raw is! List) return const [];
      return [for (final e in raw) '$e'];
    }

    List<List<double>> boxesOf(Object? raw) {
      if (raw is! List) return const [];
      final out = <List<double>>[];
      for (final e in raw) {
        if (e is! List) continue;
        try {
          out.add([for (final n in e) (n as num).toDouble()]);
        } catch (_) {
          // Skip malformed boxes.
        }
      }
      return out;
    }

    List<List<Object>> eventsOf(Object? raw) {
      if (raw is! List) return const [];
      final out = <List<Object>>[];
      for (final e in raw) {
        if (e is! List || e.length < 4) continue;
        try {
          final ms = (e[0] as num).toInt();
          final kind = '${e[1]}';
          if (kind != 'labels' && kind != 'sam') continue;
          final done = (e[2] as num).toInt();
          final total = (e[3] as num).toInt();
          out.add(<Object>[ms, kind, done, total]);
        } catch (_) {
          // Skip malformed events.
        }
      }
      out.sort((a, b) => (a[0] as int).compareTo(b[0] as int));
      return out;
    }

    List<Map<String, dynamic>> receiptOf(Object? raw) {
      if (raw is! List) return const [];
      final out = <Map<String, dynamic>>[];
      for (final e in raw) {
        if (e is Map<String, dynamic>) {
          out.add(Map<String, dynamic>.of(e));
        } else if (e is Map) {
          out.add({for (final k in e.keys) '$k': e[k]});
        }
      }
      return out;
    }

    final scanRaw = json['scan'];
    final scan = scanRaw is Map<String, dynamic>
        ? scanRaw
        : <String, dynamic>{};
    final recordedRaw = json['recordedAt'] as String?;
    return DemoReplay(
      recordedAt:
          DateTime.tryParse(recordedRaw ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
      locale: (json['locale'] as String?) ?? 'en',
      events: eventsOf(scan['events']),
      labels: stringsOf(scan['labels']),
      boxes: boxesOf(scan['boxes']),
      masks: stringsOf(scan['masks']),
      totalMs: (scan['totalMs'] as num?)?.toInt() ?? 41000,
      items: stringsOf(json['items']),
      links: stringsOf(json['links']),
      dreams: stringsOf(json['dreams']),
      receipt: receiptOf(json['receipt']),
    );
  }

  Map<String, dynamic> toJson() => {
    'v': 1,
    'recordedAt': recordedAt.toIso8601String(),
    'locale': locale,
    'scan': {
      'events': events,
      'labels': labels,
      'boxes': boxes,
      'masks': masks,
      'totalMs': totalMs,
    },
    'items': items,
    'links': links,
    'dreams': dreams,
    'receipt': receipt,
  };

  /// Returns the recorded links only when [items] equal the recorded
  /// ones (after [normalizeAnswer]). Otherwise null: a custom list
  /// always needs a live Muse Spark call.
  List<String>? linksFor(List<String> items) {
    if (items.length != this.items.length) return null;
    for (var i = 0; i < items.length; i++) {
      if (normalizeAnswer(items[i]) != normalizeAnswer(this.items[i])) {
        return null;
      }
    }
    return List<String>.of(links);
  }

  /// Replays the recorded scan timeline, firing the same callbacks the
  /// live round uses, sped up by [speed] (41 s at 1x becomes ~7 s at 6x).
  /// Returns a live round on [dataUrl] with the recorded geometry, so
  /// downstream filtering and walk order stay unchanged.
  Future<PictureRecallRound> playScan({
    required String dataUrl,
    void Function(double progress, String stage)? onProgress,
    void Function(int done, int total)? onSamItem,
    void Function(List<String> labels, List<List<double>> boxes)? onObjects,
    double speed = 6,
  }) async {
    final safeSpeed = speed <= 0 ? 6 : speed;
    var prevMs = 0;
    for (final e in events) {
      final ms = (e[0] as int).clamp(0, 1 << 30);
      final kind = e[1] as String;
      final done = e[2] as int;
      final total = e[3] as int;
      final waitMs = ((ms - prevMs) / safeSpeed).round().clamp(0, 60000);
      prevMs = ms;
      if (!isFlutterTest && waitMs > 0) {
        await Future<void>.delayed(Duration(milliseconds: waitMs));
      }
      if (kind == 'labels') {
        onObjects?.call(List<String>.of(labels), [
          for (final b in boxes) List<double>.of(b),
        ]);
        onProgress?.call(0.35, 'read');
      } else {
        onSamItem?.call(done, total);
        final frac = total > 0 ? (done / total).clamp(0.0, 1.0) : 0.0;
        onProgress?.call(0.35 + 0.6 * frac, 'sam');
      }
    }
    onProgress?.call(1.0, 'done');
    return PictureRecallRound(
      imageUrl: dataUrl,
      scene: '',
      objects: List<String>.of(labels),
      boxes: [for (final b in boxes) List<double>.of(b)],
      masks: List<String>.of(masks),
      live: true,
    );
  }
}
