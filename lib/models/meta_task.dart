/// Meta AI feladat-kérés és -válasz modellje.
///
/// A `memory_profile.dart` szintmérője és a `benchmark.dart` játékai
/// ugyanerre az alakra képeződnek le: a szerver (Muse Spark) adhat
/// friss ingert, hiba vagy offline állapot esetén pedig a mai helyi
/// generátorok maradnak a tartalék (`fallback: true`).
class MetaTaskRequest {
  /// Feladattípus: sensory, working, spatial, visual, episodic, semantic,
  /// sequence, number, verbal, chimp, duel.
  final String kind;

  /// Nehézség 1..5 skálán.
  final int difficulty;

  /// Véletlen-mag a reprodukálhatósághoz.
  final String seed;

  /// Nyelv, pl. "hu" vagy "en".
  final String locale;

  const MetaTaskRequest({
    required this.kind,
    this.difficulty = 1,
    this.seed = '',
    this.locale = 'hu',
  });

  MetaTaskRequest copyWith({
    String? kind,
    int? difficulty,
    String? seed,
    String? locale,
  }) {
    return MetaTaskRequest(
      kind: kind ?? this.kind,
      difficulty: difficulty ?? this.difficulty,
      seed: seed ?? this.seed,
      locale: locale ?? this.locale,
    );
  }

  Map<String, dynamic> toJson() => {
    'kind': kind,
    'difficulty': difficulty,
    'seed': seed,
    'locale': locale,
  };

  factory MetaTaskRequest.fromJson(Map<String, dynamic> json) {
    return MetaTaskRequest(
      kind: (json['kind'] as String?) ?? 'sensory',
      difficulty: (json['difficulty'] as num?)?.toInt() ?? 1,
      seed: (json['seed'] as String?) ?? '',
      locale: (json['locale'] as String?) ?? 'hu',
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MetaTaskRequest &&
          kind == other.kind &&
          difficulty == other.difficulty &&
          seed == other.seed &&
          locale == other.locale;

  @override
  int get hashCode => Object.hash(kind, difficulty, seed, locale);
}

/// Egy kész, képernyőn megjeleníthető memóriafeladat.
class MetaTask {
  /// Rövid inger-cím, pl. "Jegyezd meg ezt a számsort!".
  final String prompt;

  /// Megjelenítendő elemek (számok, szavak, csempék).
  final List<String> items;

  /// Kérdés a feladathoz.
  final String question;

  /// Válaszlehetőségek.
  final List<String> options;

  /// A helyes válasz indexe az [options] listában.
  final int correct;

  /// Magyarázat a tanulási útvonalhoz (mnemotechnika-tipp).
  final String explanation;

  /// Melyik modell adta ("local" offline tartaléknál).
  final String model;

  /// Létrehozás időbélyege.
  final DateTime createdAt;

  /// Igaz, ha helyi generátor adta (nincs háló / nincs kulcs / hiba).
  final bool fallback;

  const MetaTask({
    required this.prompt,
    required this.items,
    required this.question,
    required this.options,
    required this.correct,
    this.explanation = '',
    this.model = 'local',
    required this.createdAt,
    this.fallback = true,
  });

  MetaTask copyWith({
    String? prompt,
    List<String>? items,
    String? question,
    List<String>? options,
    int? correct,
    String? explanation,
    String? model,
    DateTime? createdAt,
    bool? fallback,
  }) {
    return MetaTask(
      prompt: prompt ?? this.prompt,
      items: items ?? List<String>.of(this.items),
      question: question ?? this.question,
      options: options ?? List<String>.of(this.options),
      correct: correct ?? this.correct,
      explanation: explanation ?? this.explanation,
      model: model ?? this.model,
      createdAt: createdAt ?? this.createdAt,
      fallback: fallback ?? this.fallback,
    );
  }

  Map<String, dynamic> toJson() => {
    'prompt': prompt,
    'items': items,
    'question': question,
    'options': options,
    'correct': correct,
    'explanation': explanation,
    'model': model,
    'createdAt': createdAt.toIso8601String(),
    'fallback': fallback,
  };

  factory MetaTask.fromJson(Map<String, dynamic> json) {
    final created = DateTime.tryParse(json['createdAt'] as String? ?? '');
    return MetaTask(
      prompt: (json['prompt'] as String?) ?? '',
      items: [
        for (final e in (json['items'] as List? ?? const [])) e.toString(),
      ],
      question: (json['question'] as String?) ?? '',
      options: [
        for (final e in (json['options'] as List? ?? const [])) e.toString(),
      ],
      correct: (json['correct'] as num?)?.toInt() ?? 0,
      explanation: (json['explanation'] as String?) ?? '',
      model: (json['model'] as String?) ?? 'local',
      createdAt: created ?? DateTime.fromMillisecondsSinceEpoch(0),
      fallback: (json['fallback'] as bool?) ?? true,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MetaTask &&
          prompt == other.prompt &&
          _listEq(items, other.items) &&
          question == other.question &&
          _listEq(options, other.options) &&
          correct == other.correct &&
          explanation == other.explanation &&
          model == other.model &&
          createdAt == other.createdAt &&
          fallback == other.fallback;

  @override
  int get hashCode => Object.hash(
    prompt,
    Object.hashAll(items),
    question,
    Object.hashAll(options),
    correct,
    explanation,
    model,
    createdAt,
    fallback,
  );
}

bool _listEq(List<String> a, List<String> b) {
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}
