import 'dart:convert';

class MetaImageRequest {
  final String prompt;
  final String style;
  final String size;

  const MetaImageRequest({
    required this.prompt,
    this.style = 'memory-palace',
    this.size = '512x512',
  });

  MetaImageRequest copyWith({String? prompt, String? style, String? size}) {
    return MetaImageRequest(
      prompt: prompt ?? this.prompt,
      style: style ?? this.style,
      size: size ?? this.size,
    );
  }

  String get cacheKey {
    final parts = <String, String>{
      'prompt': prompt,
      'size': size,
      'style': style,
    };
    final keys = parts.keys.toList()..sort();
    return keys.map((k) => '$k=${parts[k]}').join('&');
  }

  String get promptHash {
    final bytes = utf8.encode(prompt);
    var h = 0x811c9dc5;
    for (final b in bytes) {
      h ^= b;
      h = (h * 0x01000193) & 0xffffffff;
    }
    return h.toRadixString(16).padLeft(8, '0');
  }

  Map<String, dynamic> toJson() => {
    'prompt': prompt,
    'style': style,
    'size': size,
  };

  factory MetaImageRequest.fromJson(Map<String, dynamic> json) {
    return MetaImageRequest(
      prompt: (json['prompt'] as String?) ?? '',
      style: (json['style'] as String?) ?? 'memory-palace',
      size: (json['size'] as String?) ?? '512x512',
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MetaImageRequest &&
          prompt == other.prompt &&
          style == other.style &&
          size == other.size;

  @override
  int get hashCode => Object.hash(prompt, style, size);
}

class MetaImage {
  final String url;

  final String promptHash;

  final String cacheKey;

  final String model;

  final DateTime createdAt;
  final bool fallback;

  const MetaImage({
    this.url = '',
    this.promptHash = '',
    this.cacheKey = '',
    this.model = 'local',
    required this.createdAt,
    this.fallback = true,
  });

  MetaImage copyWith({
    String? url,
    String? promptHash,
    String? cacheKey,
    String? model,
    DateTime? createdAt,
    bool? fallback,
  }) {
    return MetaImage(
      url: url ?? this.url,
      promptHash: promptHash ?? this.promptHash,
      cacheKey: cacheKey ?? this.cacheKey,
      model: model ?? this.model,
      createdAt: createdAt ?? this.createdAt,
      fallback: fallback ?? this.fallback,
    );
  }

  Map<String, dynamic> toJson() => {
    'url': url,
    'promptHash': promptHash,
    'cacheKey': cacheKey,
    'model': model,
    'createdAt': createdAt.toIso8601String(),
    'fallback': fallback,
  };

  factory MetaImage.fromJson(Map<String, dynamic> json) {
    final created = DateTime.tryParse(json['createdAt'] as String? ?? '');
    return MetaImage(
      url: (json['url'] as String?) ?? '',
      promptHash: (json['promptHash'] as String?) ?? '',
      cacheKey: (json['cacheKey'] as String?) ?? '',
      model: (json['model'] as String?) ?? 'local',
      createdAt: created ?? DateTime.fromMillisecondsSinceEpoch(0),
      fallback: (json['fallback'] as bool?) ?? true,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MetaImage &&
          url == other.url &&
          promptHash == other.promptHash &&
          cacheKey == other.cacheKey &&
          model == other.model &&
          createdAt == other.createdAt &&
          fallback == other.fallback;

  @override
  int get hashCode =>
      Object.hash(url, promptHash, cacheKey, model, createdAt, fallback);
}
