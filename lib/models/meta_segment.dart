class MetaSegmentRequest {
  final String imageRef;

  /// Short noun-phrase concept SAM 3.1 segments ("chair", "red bicycle").
  /// One concept per request — the API has no multi-concept syntax, and
  /// commands ("segment the bus") or JSON instructions return zero
  /// matches (https://dev.meta.ai/docs/sam/segmenting). Callers pass the
  /// lead station/object noun when it is known; unknown pictures go
  /// through Spark label spotting first and segment the top label.
  final String concept;

  final List<List<double>> points;

  final List<List<double>> boxes;

  const MetaSegmentRequest({
    required this.imageRef,
    this.concept = 'object',
    this.points = const [],
    this.boxes = const [],
  });

  MetaSegmentRequest copyWith({
    String? imageRef,
    String? concept,
    List<List<double>>? points,
    List<List<double>>? boxes,
  }) {
    return MetaSegmentRequest(
      imageRef: imageRef ?? this.imageRef,
      concept: concept ?? this.concept,
      points: points ?? this.points,
      boxes: boxes ?? this.boxes,
    );
  }

  Map<String, dynamic> toJson() => {
    'imageRef': imageRef,
    'concept': concept,
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
      concept: (json['concept'] as String?) ?? 'object',
      points: readPairs(json['points']),
      boxes: readPairs(json['boxes']),
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MetaSegmentRequest &&
          imageRef == other.imageRef &&
          concept == other.concept &&
          _pairsEq(points, other.points) &&
          _pairsEq(boxes, other.boxes);

  @override
  int get hashCode => Object.hash(
    imageRef,
    concept,
    Object.hashAll(points),
    Object.hashAll(boxes),
  );
}

class MetaSegment {
  final List<String> masks;

  final List<String> labels;

  /// Normalized mask boxes, one per label when the segmenter returns
  /// geometry: [x, y, w, h] in 0..1 fractions of the image. Empty when
  /// the backend returns labels only — callers fall back to grid tiles.
  final List<List<double>> boxes;
  final String model;
  final DateTime createdAt;
  final bool fallback;

  const MetaSegment({
    this.masks = const [],
    this.labels = const [],
    this.boxes = const [],
    this.model = 'local',
    required this.createdAt,
    this.fallback = true,
  });

  MetaSegment copyWith({
    List<String>? masks,
    List<String>? labels,
    List<List<double>>? boxes,
    String? model,
    DateTime? createdAt,
    bool? fallback,
  }) {
    return MetaSegment(
      masks: masks ?? List<String>.of(this.masks),
      labels: labels ?? List<String>.of(this.labels),
      boxes: boxes ?? [for (final b in this.boxes) List<double>.of(b)],
      model: model ?? this.model,
      createdAt: createdAt ?? this.createdAt,
      fallback: fallback ?? this.fallback,
    );
  }

  Map<String, dynamic> toJson() => {
    'masks': masks,
    'labels': labels,
    'boxes': boxes,
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
      boxes: readBoxes(json['boxes']),
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
          _pairsEq(boxes, other.boxes) &&
          model == other.model &&
          createdAt == other.createdAt &&
          fallback == other.fallback;

  @override
  int get hashCode => Object.hash(
    Object.hashAll(masks),
    Object.hashAll(labels),
    Object.hashAll(boxes),
    model,
    createdAt,
    fallback,
  );
}

/// Reads normalized [x, y, w, h] boxes, dropping malformed rows.
List<List<double>> readBoxes(Object? v) {
  if (v is! List) return const [];
  final out = <List<double>>[];
  for (final row in v) {
    if (row is! List || row.length != 4) continue;
    final nums = <double>[];
    var ok = true;
    for (final e in row) {
      final d = (e as num?)?.toDouble();
      if (d == null || d.isNaN) {
        ok = false;
        break;
      }
      nums.add(d.clamp(0.0, 1.0));
    }
    if (!ok) continue;
    if (nums[2] <= 0 || nums[3] <= 0) continue;
    out.add(nums);
  }
  return out;
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
