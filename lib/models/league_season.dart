import 'dart:math';

import 'battle_bot.dart';
import 'battle_rating.dart';

/// One row on the weekly league board: a bot or the player.
class LeagueEntry {
  final String id;
  final String name;
  final int xp;
  final int streak;
  final int rating;
  final bool isBot;
  final bool isMe;

  const LeagueEntry({
    required this.id,
    required this.name,
    required this.xp,
    required this.streak,
    required this.rating,
    required this.isBot,
    this.isMe = false,
  });

  LeagueEntry copyWith({
    String? id,
    String? name,
    int? xp,
    int? streak,
    int? rating,
    bool? isBot,
    bool? isMe,
  }) {
    return LeagueEntry(
      id: id ?? this.id,
      name: name ?? this.name,
      xp: xp ?? this.xp,
      streak: streak ?? this.streak,
      rating: rating ?? this.rating,
      isBot: isBot ?? this.isBot,
      isMe: isMe ?? this.isMe,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'xp': xp,
    'streak': streak,
    'rating': rating,
    'isBot': isBot,
    'isMe': isMe,
  };

  factory LeagueEntry.fromJson(Map<String, dynamic> json) {
    return LeagueEntry(
      id: (json['id'] as String?) ?? '',
      name: (json['name'] as String?) ?? 'Player',
      xp: (json['xp'] as num?)?.toInt() ?? 0,
      streak: (json['streak'] as num?)?.toInt() ?? 0,
      rating: (json['rating'] as num?)?.toInt() ?? BattleRating.startingRating,
      isBot: (json['isBot'] as bool?) ?? true,
      isMe: (json['isMe'] as bool?) ?? false,
    );
  }
}

/// One weekly league season: 30 bots plus the player.
class LeagueSeason {
  static const int botCount = 30;
  static const int promoteCount = 10;
  static const int relegateFrom = 21;

  final String seasonId;
  final DateTime weekStart;
  final int tierIndex;
  final List<LeagueEntry> entries;
  final DateTime updatedAt;
  final String lastTickDay;
  final int playerBattleXp;

  const LeagueSeason({
    required this.seasonId,
    required this.weekStart,
    required this.tierIndex,
    required this.entries,
    required this.updatedAt,
    required this.lastTickDay,
    required this.playerBattleXp,
  });

  LeagueEntry? get playerEntry {
    for (final e in entries) {
      if (e.isMe) return e;
    }
    return null;
  }

  List<LeagueEntry> get sorted {
    final list = List<LeagueEntry>.of(entries);
    list.sort((a, b) {
      final xp = b.xp.compareTo(a.xp);
      if (xp != 0) return xp;
      return b.rating.compareTo(a.rating);
    });
    return list;
  }

  /// 1-based rank of the player, 0 when the player is missing.
  int get playerRank {
    final list = sorted;
    for (var i = 0; i < list.length; i++) {
      if (list[i].isMe) return i + 1;
    }
    return 0;
  }

  Map<String, dynamic> toJson() => {
    'seasonId': seasonId,
    'weekStart': weekStart.toIso8601String(),
    'tierIndex': tierIndex,
    'entries': [for (final e in entries) e.toJson()],
    'updatedAt': updatedAt.toIso8601String(),
    'lastTickDay': lastTickDay,
    'playerBattleXp': playerBattleXp,
  };

  factory LeagueSeason.fromJson(Map<String, dynamic> json) {
    final weekStart =
        DateTime.tryParse(json['weekStart'] as String? ?? '') ??
        weekStartFor(DateTime.now());
    final updatedAt =
        DateTime.tryParse(json['updatedAt'] as String? ?? '') ?? weekStart;
    return LeagueSeason(
      seasonId: (json['seasonId'] as String?) ?? seasonIdFor(weekStart),
      weekStart: weekStart,
      tierIndex: (json['tierIndex'] as num?)?.toInt() ?? 0,
      entries: [
        for (final e in (json['entries'] as List? ?? const []))
          if (e is Map<String, dynamic>) LeagueEntry.fromJson(e),
      ],
      updatedAt: updatedAt,
      lastTickDay: (json['lastTickDay'] as String?) ?? '',
      playerBattleXp: (json['playerBattleXp'] as num?)?.toInt() ?? 0,
    );
  }
}

/// Archived season result, kept for the profile lifetime total.
class LeagueSummary {
  final String seasonId;
  final int tierIndex;
  final int playerRank;
  final int playerXp;
  final String champion;

  const LeagueSummary({
    required this.seasonId,
    required this.tierIndex,
    required this.playerRank,
    required this.playerXp,
    required this.champion,
  });

  Map<String, dynamic> toJson() => {
    'seasonId': seasonId,
    'tierIndex': tierIndex,
    'playerRank': playerRank,
    'playerXp': playerXp,
    'champion': champion,
  };

  factory LeagueSummary.fromJson(Map<String, dynamic> json) {
    return LeagueSummary(
      seasonId: (json['seasonId'] as String?) ?? '',
      tierIndex: (json['tierIndex'] as num?)?.toInt() ?? 0,
      playerRank: (json['playerRank'] as num?)?.toInt() ?? 0,
      playerXp: (json['playerXp'] as num?)?.toInt() ?? 0,
      champion: (json['champion'] as String?) ?? '',
    );
  }
}

/// Monday 00:00 local of the week containing [now].
DateTime weekStartFor(DateTime now) {
  final day = DateTime(now.year, now.month, now.day);
  return day.subtract(Duration(days: now.weekday - DateTime.monday));
}

/// Stable season id from the Monday anchor: 'yyyy-MM-dd'.
String seasonIdFor(DateTime now) {
  final start = weekStartFor(now);
  final m = start.month.toString().padLeft(2, '0');
  final d = start.day.toString().padLeft(2, '0');
  return '${start.year}-$m-$d';
}

/// Day key 'yyyy-MM-dd' for tick bookkeeping.
String seasonDayKey(DateTime now) {
  final m = now.month.toString().padLeft(2, '0');
  final d = now.day.toString().padLeft(2, '0');
  return '${now.year}-$m-$d';
}

/// Days left this week, same formula the league header already used.
int daysLeftFor(DateTime now) => 8 - now.weekday;

/// Seeds a fresh season: 30 deterministic bots plus the player row.
/// Bots near the player's tier dominate the field so the board feels fair.
LeagueSeason seedSeason({
  required DateTime now,
  required String playerName,
  required int playerRating,
  required int playerStreak,
  required int playerActivityXp,
  required int tierIndex,
  required List<BotPersona> roster,
  List<String>? keepBotIds,
}) {
  final seasonId = seasonIdFor(now);
  final weekStart = weekStartFor(now);
  final rng = Random(botSeedHash('league:$seasonId'));
  final pool = List<BotPersona>.of(roster);
  pool.sort((a, b) {
    final da = (a.rating - playerRating).abs();
    final db = (b.rating - playerRating).abs();
    return da.compareTo(db);
  });
  final picked = <BotPersona>[];
  if (keepBotIds != null && keepBotIds.isNotEmpty) {
    final keep = keepBotIds.toSet();
    for (final bot in pool) {
      if (keep.contains(bot.id) && picked.length < LeagueSeason.botCount ~/ 2) {
        picked.add(bot);
      }
    }
  }
  final have = picked.map((b) => b.id).toSet();
  final near = [for (final b in pool) if (!have.contains(b.id)) b];
  final far = <BotPersona>[];
  while (picked.length < LeagueSeason.botCount && (near.isNotEmpty)) {
    final i = rng.nextInt(near.length);
    picked.add(near.removeAt(i));
  }
  while (picked.length < LeagueSeason.botCount && far.isNotEmpty) {
    picked.add(far.removeAt(rng.nextInt(far.length)));
  }
  final dayIndex = now.difference(weekStart).inDays.clamp(0, 6);
  final entries = <LeagueEntry>[
    for (final bot in picked)
      LeagueEntry(
        id: bot.id,
        name: bot.name,
        xp: _botWeeklyXp(bot: bot, rng: rng, dayIndex: dayIndex),
        streak: bot.streak,
        rating: bot.rating,
        isBot: true,
      ),
    LeagueEntry(
      id: 'player',
      name: playerName,
      xp: playerActivityXp,
      streak: playerStreak,
      rating: playerRating,
      isBot: false,
      isMe: true,
    ),
  ];
  return LeagueSeason(
    seasonId: seasonId,
    weekStart: weekStart,
    tierIndex: tierIndex.clamp(0, 13),
    entries: entries,
    updatedAt: now,
    lastTickDay: seasonDayKey(now),
    playerBattleXp: 0,
  );
}

int _botWeeklyXp({
  required BotPersona bot,
  required Random rng,
  required int dayIndex,
}) {
  final spec = specForTier(bot.tier);
  final daily = spec.weeklyXpMean / 7.0;
  final sigma = spec.weeklyXpSigma / 7.0;
  var total = 0.0;
  for (var d = 0; d <= dayIndex; d++) {
    total += daily + nextGaussian(rng) * sigma;
  }
  return max(0, total.round());
}

/// Daily bot tick. Each bot gains one seeded day of XP and neighbouring
/// bots trade a small Elo drift, so the board moves every day but the
/// player's own results still decide the week.
LeagueSeason tickSeason({
  required LeagueSeason season,
  required DateTime now,
  required int playerRating,
  required int playerStreak,
  required int playerActivityXp,
}) {
  final dayKey = seasonDayKey(now);
  if (season.lastTickDay == dayKey) {
    return _withPlayer(
      season,
      now: now,
      playerRating: playerRating,
      playerStreak: playerStreak,
      playerActivityXp: playerActivityXp,
    );
  }
  final rng = Random(botSeedHash('league:${season.seasonId}:$dayKey'));
  final bots = [
    for (final e in season.entries)
      if (e.isBot) e,
  ];
  final next = <LeagueEntry>[];
  for (var i = 0; i < bots.length; i++) {
    final bot = bots[i];
    final spec = specForTier(tierForRating(bot.rating));
    final daily = spec.weeklyXpMean / 7.0;
    final sigma = spec.weeklyXpSigma / 7.0;
    final gain = max(0, (daily + nextGaussian(rng) * sigma).round());
    var rating = bot.rating;
    if (i + 1 < bots.length) {
      final foe = bots[i + 1];
      final expected = BattleRating.expectedScore(
        player: rating,
        opponent: foe.rating,
      );
      final score = rng.nextDouble() < expected ? 1.0 : 0.0;
      rating = BattleRating.nextRating(
        player: rating,
        opponent: foe.rating,
        score: score,
      );
    }
    next.add(bot.copyWith(xp: bot.xp + gain, rating: rating));
  }
  final player = season.playerEntry;
  if (player != null) {
    next.add(
      player.copyWith(
        xp: season.playerBattleXp + playerActivityXp,
        streak: playerStreak,
        rating: playerRating,
      ),
    );
  }
  return LeagueSeason(
    seasonId: season.seasonId,
    weekStart: season.weekStart,
    tierIndex: season.tierIndex,
    entries: next,
    updatedAt: now,
    lastTickDay: dayKey,
    playerBattleXp: season.playerBattleXp,
  );
}

LeagueSeason _withPlayer(
  LeagueSeason season, {
  required DateTime now,
  required int playerRating,
  required int playerStreak,
  required int playerActivityXp,
}) {
  final entries = [
    for (final e in season.entries)
      e.isMe
          ? e.copyWith(
              xp: season.playerBattleXp + playerActivityXp,
              streak: playerStreak,
              rating: playerRating,
            )
          : e,
  ];
  return LeagueSeason(
    seasonId: season.seasonId,
    weekStart: season.weekStart,
    tierIndex: season.tierIndex,
    entries: entries,
    updatedAt: now,
    lastTickDay: season.lastTickDay,
    playerBattleXp: season.playerBattleXp,
  );
}

/// Adds battle XP to the player's season row.
LeagueSeason addPlayerBattleXp(LeagueSeason season, int xp) {
  final battle = season.playerBattleXp + xp;
  final entries = [
    for (final e in season.entries)
      if (e.isMe) e.copyWith(xp: e.xp + xp) else e,
  ];
  return LeagueSeason(
    seasonId: season.seasonId,
    weekStart: season.weekStart,
    tierIndex: season.tierIndex,
    entries: entries,
    updatedAt: season.updatedAt,
    lastTickDay: season.lastTickDay,
    playerBattleXp: battle,
  );
}

/// Finalizes an expired season: archives a summary, moves the player tier
/// by rank (top 10 up, bottom 10 down), keeps half the field for continuity
/// and reseeds the rest.
({LeagueSeason season, LeagueSummary summary})? rolloverIfNeeded({
  required LeagueSeason season,
  required DateTime now,
  required String playerName,
  required int playerRating,
  required int playerStreak,
  required int playerActivityXp,
  required List<BotPersona> roster,
}) {
  if (now.isBefore(season.weekStart.add(const Duration(days: 7)))) {
    return null;
  }
  final sorted = season.sorted;
  final rank = season.playerRank;
  final playerXp = season.playerEntry?.xp ?? 0;
  final summary = LeagueSummary(
    seasonId: season.seasonId,
    tierIndex: season.tierIndex,
    playerRank: rank,
    playerXp: playerXp,
    champion: sorted.isEmpty ? '' : sorted.first.name,
  );
  var tier = season.tierIndex;
  if (rank > 0 && rank <= LeagueSeason.promoteCount) {
    tier += 1;
  } else if (rank >= LeagueSeason.relegateFrom) {
    tier -= 1;
  }
  final keepRng = Random(botSeedHash('league:${season.seasonId}:keep'));
  final botIds = [
    for (final e in sorted)
      if (e.isBot) e.id,
  ]..shuffle(keepRng);
  final keep = botIds.take(LeagueSeason.botCount ~/ 2).toList();
  final fresh = seedSeason(
    now: now,
    playerName: playerName,
    playerRating: playerRating,
    playerStreak: playerStreak,
    playerActivityXp: playerActivityXp,
    tierIndex: tier,
    roster: roster,
    keepBotIds: keep,
  );
  return (season: fresh, summary: summary);
}
