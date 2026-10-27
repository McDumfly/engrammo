/// SAM 3.1 szegmentálási kérés és -válasz a térbeli "Palace" útvonalhoz.
///
/// Csak a "Palace builder" (spatial) útvonal használja: egy palota-kép
/// adott pontjára / dobozára kér maszkot és címkéket. Offline módban
/// a válasz üres maszklista tartalékkal tér vissza.
class MetaSegmentRequest {
  /// Kép-hivatkozás (URL vagy cache-kulcs).
  final String imageRef;

  /// Érdekes pontok (relatív 0..1 koordináták, [x, y] párok).
  final List<List<double>> points;

  /// Érdekes dobozok (relatív [x1, y1, x2, y2]).
  final List<List<double>> boxes;

  const MetaSegmentRequest({
    required this.imageRef,
    this.points = const [],
    this.boxes = const [],
  });

  MetaSegmentRequest copyWith({
    String? imageRef,
    List<List<double>>? points,
    List<List<double>>? boxes,
  }) {
    return MetaSegmentRequest(
      imageRef: imageRef ?? this.imageRef,
      points: points ?? this.points,
      boxes: boxes ?? this.boxes,
    );
  }

  Map<String, dynamic> toJson() => {
    'imageRef': imageRef,
    'points': points,
    'boxes': boxes,
  };

  factory MetaSegmentRequest.fromJson(Map<String, dynamic> json) {
    List<List<double>> readPairs(Object? v) {
      if (v is! List) return const [];
      return [
        for (final row in v)
          if (row is List)
            [for (final e in row) (e as num?)?.toDouble() ?? 0.0],
      ];
    }

    return MetaSegmentRequest(
      imageRef: (json['imageRef'] as String?) ?? '',
      points: readPairs(json['points']),
      boxes: readPairs(json['boxes']),
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MetaSegmentRequest &&
          imageRef == other.imageRef &&
          _pairsEq(points, other.points) &&
          _pairsEq(boxes, other.boxes);

  @override
  int get hashCode =>
      Object.hash(imageRef, Object.hashAll(points), Object.hashAll(boxes));
}

/// Egy szegmentálási válasz.
class MetaSegment {
  /// Maszk-azonosítók vagy futáshossz-kódolt maszkok (szerverfüggő).
  final List<String> masks;

  /// Emberi címkék a maszkokhoz (pl. "kapu", "lépcső", "szökőkút").
  final List<String> labels;
  final String model;
  final DateTime createdAt;
  final bool fallback;

  const MetaSegment({
    this.masks = const [],
    this.labels = const [],
    this.model = 'local',
    required this.createdAt,
    this.fallback = true,
  });

  MetaSegment copyWith({
    List<String>? masks,
    List<String>? labels,
    String? model,
    DateTime? createdAt,
    bool? fallback,
  }) {
    return MetaSegment(
      masks: masks ?? List<String>.of(this.masks),
      labels: labels ?? List<String>.of(this.labels),
      model: model ?? this.model,
      createdAt: createdAt ?? this.createdAt,
      fallback: fallback ?? this.fallback,
    );
  }

  Map<String, dynamic> toJson() => {
    'masks': masks,
    'labels': labels,
    'model': model,
    'createdAt': createdAt.toIso8601String(),
    'fallback': fallback,
  };

  factory MetaSegment.fromJson(Map<String, dynamic> json) {
    final created = DateTime.tryParse(json['createdAt'] as String? ?? '');
    return MetaSegment(
      masks: [
        for (final e in (json['masks'] as List? ?? const [])) e.toString(),
      ],
      labels: [
        for (final e in (json['labels'] as List? ?? const [])) e.toString(),
      ],
      model: (json['model'] as String?) ?? 'local',
      createdAt: created ?? DateTime.fromMillisecondsSinceEpoch(0),
      fallback: (json['fallback'] as bool?) ?? true,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MetaSegment &&
          _strEq(masks, other.masks) &&
          _strEq(labels, other.labels) &&
          model == other.model &&
          createdAt == other.createdAt &&
          fallback == other.fallback;

  @override
  int get hashCode => Object.hash(
    Object.hashAll(masks),
    Object.hashAll(labels),
    model,
    createdAt,
    fallback,
  );
}

bool _strEq(List<String> a, List<String> b) {
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}

bool _pairsEq(List<List<double>> a, List<List<double>> b) {
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i].length != b[i].length) return false;
    for (var j = 0; j < a[i].length; j++) {
      if ((a[i][j] - b[i][j]).abs() > 1e-9) return false;
    }
  }
  return true;
}
