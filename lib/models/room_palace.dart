import '../l10n/app_localizations.dart' show trFor;
import 'fsrs_card.dart';
import 'recall_scoring.dart' show fuzzyWordMatch, normalizeAnswer;

/// One memory palace built on the learner's own room photo.
/// Device-only: never synced (the photo is private), see MemoryStore.
class RoomPalace {
  final String id; // 'room:<millisecondsSinceEpoch>'
  final DateTime createdAt;
  final String imageRef; // square JPEG data URL (768x768)
  final List<String> stations; // object names, walk order
  final List<List<double>>
  boxes; // normalized [x0,y0,x1,y1] per station, may be empty
  final List<String> masks; // raw SAM mask tokens per station, may be empty
  final List<String>
  items; // what the learner memorizes, items[i] sits at stations[i]
  final List<String> links; // vivid image sentence per item
  final bool live; // true = stations came from Muse Spark + SAM
  final FsrsCard card;
  final List<String> dreams; // persisted dream scenes per station (data URLs)
  final bool
  sample; // true = built on the bundled sample room, not the learner's

  const RoomPalace({
    required this.id,
    required this.createdAt,
    required this.imageRef,
    this.stations = const [],
    this.boxes = const [],
    this.masks = const [],
    this.items = const [],
    this.links = const [],
    this.live = false,
    required this.card,
    this.dreams = const [],
    this.sample = false,
  });

  RoomPalace copyWith({
    String? id,
    DateTime? createdAt,
    String? imageRef,
    List<String>? stations,
    List<List<double>>? boxes,
    List<String>? masks,
    List<String>? items,
    List<String>? links,
    bool? live,
    FsrsCard? card,
    List<String>? dreams,
    bool? sample,
  }) {
    return RoomPalace(
      id: id ?? this.id,
      createdAt: createdAt ?? this.createdAt,
      imageRef: imageRef ?? this.imageRef,
      stations: stations ?? this.stations,
      boxes: boxes ?? this.boxes,
      masks: masks ?? this.masks,
      items: items ?? this.items,
      links: links ?? this.links,
      live: live ?? this.live,
      card: card ?? this.card,
      dreams: dreams ?? this.dreams,
      sample: sample ?? this.sample,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'createdAt': createdAt.toIso8601String(),
    'imageRef': imageRef,
    'stations': stations,
    'boxes': boxes,
    'masks': masks,
    'items': items,
    'links': links,
    'live': live,
    'card': card.toJson(),
    'dreams': dreams,
    'sample': sample,
  };

  /// Never throws: missing lists become empty, a bad date becomes epoch,
  /// and a missing card becomes a fresh due card.
  factory RoomPalace.fromJson(Map<String, dynamic> json) {
    List<String> stringsOf(Object? raw) {
      if (raw is! List) return const [];
      final out = <String>[];
      for (final e in raw) {
        try {
          out.add(e.toString());
        } catch (_) {
          // Skip entries that cannot stringify.
        }
      }
      return out;
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

    final id = (json['id'] as String?) ?? '';
    final createdAt =
        DateTime.tryParse(json['createdAt'] as String? ?? '') ??
        DateTime.fromMillisecondsSinceEpoch(0);
    final cardRaw = json['card'];
    final card = cardRaw is Map<String, dynamic>
        ? (() {
            try {
              return FsrsCard.fromJson(cardRaw);
            } catch (_) {
              return FsrsCard(
                cardId: id,
                taskId: 'room_palace',
                due: DateTime.now(),
              );
            }
          })()
        : FsrsCard(cardId: id, taskId: 'room_palace', due: DateTime.now());
    return RoomPalace(
      id: id,
      createdAt: createdAt,
      imageRef: (json['imageRef'] as String?) ?? '',
      stations: stringsOf(json['stations']),
      boxes: boxesOf(json['boxes']),
      masks: stringsOf(json['masks']),
      items: stringsOf(json['items']),
      links: stringsOf(json['links']),
      live: (json['live'] as bool?) ?? false,
      card: card,
      dreams:
          (json['dreams'] as List?)?.whereType<String>().toList() ?? const [],
      sample: (json['sample'] as bool?) ?? false,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is RoomPalace &&
          id == other.id &&
          createdAt == other.createdAt &&
          imageRef == other.imageRef &&
          _strListEq(stations, other.stations) &&
          _boxesEq(boxes, other.boxes) &&
          _strListEq(masks, other.masks) &&
          _strListEq(items, other.items) &&
          _strListEq(links, other.links) &&
          live == other.live &&
          card == other.card &&
          _strListEq(dreams, other.dreams);

  @override
  int get hashCode => Object.hash(
    id,
    createdAt,
    imageRef,
    Object.hashAll(stations),
    Object.hashAll([for (final b in boxes) Object.hashAll(b)]),
    Object.hashAll(masks),
    Object.hashAll(items),
    Object.hashAll(links),
    live,
    card,
    Object.hashAll(dreams),
  );
}

bool _strListEq(List<String> a, List<String> b) {
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}

bool _boxesEq(List<List<double>> a, List<List<double>> b) {
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (!_numListEq(a[i], b[i])) return false;
  }
  return true;
}

bool _numListEq(List<double> a, List<double> b) {
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if ((a[i] - b[i]).abs() > 1e-9) return false;
  }
  return true;
}

/// FSRS grade from a recall run: 4 easy (all), 3 good (>=80%),
/// 2 hard (>=50%), 1 again (<50%). "Show me" counts as a miss.
int roomGrade(int correct, int total) {
  if (total <= 0) return 1;
  if (correct >= total) return 4;
  final ratio = correct / total;
  if (ratio >= 0.8) return 3;
  if (ratio >= 0.5) return 2;
  return 1;
}

/// Short numeric date for palace titles, e.g. 2026-11-03.
String palaceShortDate(DateTime at) {
  final y = at.year.toString().padLeft(4, '0');
  final m = at.month.toString().padLeft(2, '0');
  final d = at.day.toString().padLeft(2, '0');
  return '$y-$m-$d';
}

/// Display name: the same titles the lesson picker shows — a dated room
/// title for built palaces, 'Sample room' for the sample. Palaces too
/// small to walk keep the old station fallback.
String roomPalaceName(RoomPalace p, [String locale = 'en']) {
  if (p.sample) return trFor(locale, 'palace_sample_title');
  if (p.stations.length >= 3) {
    return trFor(locale, 'palace_own_title', {
      'date': palaceShortDate(p.createdAt),
    });
  }
  if (p.stations.isEmpty) return p.id;
  return p.stations.take(2).join(' · ');
}

enum RecallMatch { exact, typo, none }

/// exact: same after normalizing (case, accents, hyphens, punctuation).
/// typo: within the fuzzy edit distance (1 for 5-8 chars, 2 for 9+).
RecallMatch localRecallAnswer(String expected, String answer) {
  final exp = normalizeAnswer(expected);
  final got = normalizeAnswer(answer);
  if (exp.isEmpty || got.isEmpty) return RecallMatch.none;
  if (exp == got) return RecallMatch.exact;
  return fuzzyWordMatch(exp, got) ? RecallMatch.typo : RecallMatch.none;
}

/// Reorders stations into a left-to-right walk (method of loci needs a
/// fixed, natural route). Returns the same lists when boxes are missing.
({List<String> stations, List<List<double>> boxes, List<String> masks})
walkOrder(List<String> stations, List<List<double>> boxes, List<String> masks) {
  if (boxes.length != stations.length || stations.length < 2) {
    return (stations: stations, boxes: boxes, masks: masks);
  }
  double cx(List<double> b) =>
      b.length >= 4 ? b[0] + b[2] / 2 : (b.isNotEmpty ? b[0] : 0.0);
  double cy(List<double> b) =>
      b.length >= 4 ? b[1] + b[3] / 2 : (b.length >= 2 ? b[1] : 0.0);
  final idx = List<int>.generate(stations.length, (i) => i);
  idx.sort((a, b) {
    final dx = cx(boxes[a]).compareTo(cx(boxes[b]));
    if (dx != 0) return dx;
    return cy(boxes[a]).compareTo(cy(boxes[b]));
  });
  return (
    stations: [for (final i in idx) stations[i]],
    boxes: [for (final i in idx) boxes[i]],
    masks: masks.length == stations.length
        ? [for (final i in idx) masks[i]]
        : masks,
  );
}
