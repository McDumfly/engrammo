import 'dart:math' as math;

class FsrsCard {
  final String cardId;
  final String taskId;

  final double stability;

  final double difficulty;

  final DateTime due;

  final int reps;

  final int lapses;

  const FsrsCard({
    required this.cardId,
    required this.taskId,
    this.stability = 1.0,
    this.difficulty = 5.0,
    required this.due,
    this.reps = 0,
    this.lapses = 0,
  });

  bool isDue([DateTime? now]) {
    final n = now ?? DateTime.now();
    return !due.isAfter(n);
  }

  FsrsCard copyWith({
    String? cardId,
    String? taskId,
    double? stability,
    double? difficulty,
    DateTime? due,
    int? reps,
    int? lapses,
  }) {
    return FsrsCard(
      cardId: cardId ?? this.cardId,
      taskId: taskId ?? this.taskId,
      stability: stability ?? this.stability,
      difficulty: difficulty ?? this.difficulty,
      due: due ?? this.due,
      reps: reps ?? this.reps,
      lapses: lapses ?? this.lapses,
    );
  }

  Map<String, dynamic> toJson() => {
    'cardId': cardId,
    'taskId': taskId,
    'stability': stability,
    'difficulty': difficulty,
    'due': due.toIso8601String(),
    'reps': reps,
    'lapses': lapses,
  };

  factory FsrsCard.fromJson(Map<String, dynamic> json) {
    final due = DateTime.tryParse(json['due'] as String? ?? '');
    return FsrsCard(
      cardId: (json['cardId'] as String?) ?? '',
      taskId: (json['taskId'] as String?) ?? '',
      stability: (json['stability'] as num?)?.toDouble() ?? 1.0,
      difficulty: (json['difficulty'] as num?)?.toDouble() ?? 5.0,
      due: due ?? DateTime.fromMillisecondsSinceEpoch(0),
      reps: (json['reps'] as num?)?.toInt() ?? 0,
      lapses: (json['lapses'] as num?)?.toInt() ?? 0,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is FsrsCard &&
          cardId == other.cardId &&
          taskId == other.taskId &&
          (stability - other.stability).abs() < 1e-9 &&
          (difficulty - other.difficulty).abs() < 1e-9 &&
          due == other.due &&
          reps == other.reps &&
          lapses == other.lapses;

  @override
  int get hashCode =>
      Object.hash(cardId, taskId, stability, difficulty, due, reps, lapses);
}

class FsrsScheduler {
  static FsrsCard next(FsrsCard card, int grade, [DateTime? now]) {
    final n = now ?? DateTime.now();
    final g = grade.clamp(1, 4);
    var stability = card.stability;
    var difficulty = card.difficulty;
    var lapses = card.lapses;

    if (g == 1) {
      lapses += 1;
      difficulty = math.min(10.0, difficulty + 1.0);
      stability = math.max(0.2, card.stability * 0.3);
    } else {
      final gain = switch (g) {
        2 => 1.15,
        4 => 2.2,
        _ => 1.6,
      };
      final adjust = switch (g) {
        2 => 0.3,
        4 => -0.6,
        _ => -0.2,
      };
      difficulty = (difficulty + adjust).clamp(1.0, 10.0);
      stability = math.max(0.3, card.stability * gain);
    }

    final intervalDays = stability.clamp(0.2, 365.0);
    final due = n.add(Duration(hours: (intervalDays * 24).round()));
    return card.copyWith(
      stability: stability,
      difficulty: difficulty,
      due: due,
      reps: card.reps + 1,
      lapses: lapses,
    );
  }

  static List<FsrsCard> dueCards(Iterable<FsrsCard> cards, [DateTime? now]) {
    final n = now ?? DateTime.now();
    final due = [
      for (final c in cards)
        if (!c.due.isAfter(n)) c,
    ];
    due.sort((a, b) => a.due.compareTo(b.due));
    return due;
  }
}
