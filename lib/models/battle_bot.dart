import 'dart:math';

import '../l10n/app_localizations.dart';
import 'battle_rating.dart';

/// Difficulty tiers for arena bots.
///
/// Bots behave like regular players: each tier has its own rating band,
/// answer accuracy range and answer-latency distribution. Tiers are derived
/// from rating so a bot that drifts up in rating plays better over time.
enum BotTier { rookie, contender, sharp, master, quantum }

/// Static tuning table for one bot tier.
///
/// Accuracy is the probability of picking the correct option. Latency is a
/// gaussian sample in milliseconds, clamped to [latencyMinMs, latencyMaxMs].
class BotTierSpec {
  final BotTier tier;
  final String labelKey;
  final int minRating;
  final int maxRating;
  final double accMin;
  final double accMax;
  final int latencyMeanMs;
  final int latencySigmaMs;
  final int latencyMinMs;
  final int latencyMaxMs;
  final int weeklyXpMean;
  final int weeklyXpSigma;
  final int streakMedian;
  final double onlineP;

  const BotTierSpec({
    required this.tier,
    required this.labelKey,
    required this.minRating,
    required this.maxRating,
    required this.accMin,
    required this.accMax,
    required this.latencyMeanMs,
    required this.latencySigmaMs,
    required this.latencyMinMs,
    required this.latencyMaxMs,
    required this.weeklyXpMean,
    required this.weeklyXpSigma,
    required this.streakMedian,
    required this.onlineP,
  });
}

/// Canonical tier table. Bands overlap slightly so matchmaking across a
/// boundary still feels fair.
const botTierSpecs = <BotTier, BotTierSpec>{
  BotTier.rookie: BotTierSpec(
    tier: BotTier.rookie,
    labelKey: 'tier_rookie',
    minRating: 600,
    maxRating: 900,
    accMin: 0.35,
    accMax: 0.50,
    latencyMeanMs: 9000,
    latencySigmaMs: 3000,
    latencyMinMs: 3000,
    latencyMaxMs: 20000,
    weeklyXpMean: 200,
    weeklyXpSigma: 120,
    streakMedian: 3,
    onlineP: 0.15,
  ),
  BotTier.contender: BotTierSpec(
    tier: BotTier.contender,
    labelKey: 'tier_contender',
    minRating: 850,
    maxRating: 1100,
    accMin: 0.50,
    accMax: 0.65,
    latencyMeanMs: 7000,
    latencySigmaMs: 2500,
    latencyMinMs: 2500,
    latencyMaxMs: 18000,
    weeklyXpMean: 500,
    weeklyXpSigma: 200,
    streakMedian: 6,
    onlineP: 0.25,
  ),
  BotTier.sharp: BotTierSpec(
    tier: BotTier.sharp,
    labelKey: 'tier_sharp',
    minRating: 1050,
    maxRating: 1300,
    accMin: 0.62,
    accMax: 0.78,
    latencyMeanMs: 5500,
    latencySigmaMs: 2000,
    latencyMinMs: 2000,
    latencyMaxMs: 15000,
    weeklyXpMean: 900,
    weeklyXpSigma: 280,
    streakMedian: 12,
    onlineP: 0.35,
  ),
  BotTier.master: BotTierSpec(
    tier: BotTier.master,
    labelKey: 'tier_master',
    minRating: 1250,
    maxRating: 1500,
    accMin: 0.75,
    accMax: 0.88,
    latencyMeanMs: 4200,
    latencySigmaMs: 1500,
    latencyMinMs: 1500,
    latencyMaxMs: 12000,
    weeklyXpMean: 1300,
    weeklyXpSigma: 320,
    streakMedian: 21,
    onlineP: 0.30,
  ),
  BotTier.quantum: BotTierSpec(
    tier: BotTier.quantum,
    labelKey: 'tier_quantum',
    minRating: 1450,
    maxRating: 1800,
    accMin: 0.85,
    accMax: 0.96,
    latencyMeanMs: 3200,
    latencySigmaMs: 1200,
    latencyMinMs: 1000,
    latencyMaxMs: 9000,
    weeklyXpMean: 1700,
    weeklyXpSigma: 350,
    streakMedian: 34,
    onlineP: 0.20,
  ),
};

/// Tier for a rating. Reads top-down so overlaps resolve to the higher tier.
BotTier tierForRating(int rating) {
  if (rating >= botTierSpecs[BotTier.quantum]!.minRating) {
    return BotTier.quantum;
  }
  if (rating >= botTierSpecs[BotTier.master]!.minRating) {
    return BotTier.master;
  }
  if (rating >= botTierSpecs[BotTier.sharp]!.minRating) return BotTier.sharp;
  if (rating >= botTierSpecs[BotTier.contender]!.minRating) {
    return BotTier.contender;
  }
  return BotTier.rookie;
}

BotTierSpec specForTier(BotTier tier) => botTierSpecs[tier]!;

/// FNV-1a 32-bit hash, copied from the validated-task generator so bot
/// behaviour stays deterministic per domain without importing privates.
int botSeedHash(String seed) {
  var h = 0x811c9dc5;
  for (final c in seed.codeUnits) {
    h ^= c;
    h = (h * 0x01000193) & 0xffffffff;
  }
  return h;
}

/// Standard normal sample via Box-Muller. Consumes exactly two [rng] draws.
double nextGaussian(Random rng) {
  var u = 0.0;
  while (u <= 0.0) {
    u = rng.nextDouble();
  }
  final v = rng.nextDouble();
  return sqrt(-2.0 * log(u)) * cos(2.0 * pi * v);
}

/// One simulated arena player.
///
/// Bots are local-only, seeded and persisted like any other account data, so
/// the arena, league and friends list work fully offline.
class BotPersona {
  final String id;
  final String name;
  final int rating;
  final int xp;
  final int streak;
  final int avatarSeed;

  const BotPersona({
    required this.id,
    required this.name,
    required this.rating,
    required this.xp,
    required this.streak,
    required this.avatarSeed,
  });

  BotTier get tier => tierForRating(rating);

  String get tierLabel => tr(specForTier(tier).labelKey);

  BotPersona copyWith({
    String? id,
    String? name,
    int? rating,
    int? xp,
    int? streak,
    int? avatarSeed,
  }) {
    return BotPersona(
      id: id ?? this.id,
      name: name ?? this.name,
      rating: rating ?? this.rating,
      xp: xp ?? this.xp,
      streak: streak ?? this.streak,
      avatarSeed: avatarSeed ?? this.avatarSeed,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'rating': rating,
    'xp': xp,
    'streak': streak,
    'avatarSeed': avatarSeed,
  };

  factory BotPersona.fromJson(Map<String, dynamic> json) {
    return BotPersona(
      id: (json['id'] as String?) ?? '',
      name: (json['name'] as String?) ?? 'Player',
      rating: (json['rating'] as num?)?.toInt() ?? BattleRating.startingRating,
      xp: (json['xp'] as num?)?.toInt() ?? 0,
      streak: (json['streak'] as num?)?.toInt() ?? 0,
      avatarSeed: (json['avatarSeed'] as num?)?.toInt() ?? 0,
    );
  }
}

/// Fixed 48-name roster pool (Hungarian + international). The first entries
/// overlap the old sample names so returning players meet familiar faces.
const botNames = <String>[
  'Nora',
  'Marci',
  'Lena',
  'Bence',
  'Zsofi',
  'Adam',
  'Eszter',
  'Daniel',
  'Petra',
  'Levi',
  'Reka',
  'Mate',
  'Zsuzsa',
  'Gabor',
  'Emese',
  'Tamas',
  'Aniko',
  'Balazs',
  'Kata',
  'Dora',
  'Pista',
  'Fanni',
  'Gergo',
  'Orsi',
  'Peter',
  'Virag',
  'Andris',
  'Judit',
  'Sophie',
  'Mark',
  'Greg',
  'David',
  'Mia',
  'Lucas',
  'Emma',
  'Olli',
  'Ava',
  'Liam',
  'Sofia',
  'Noah',
  'Elena',
  'Viktor',
  'Iris',
  'Felix',
  'Clara',
  'Hugo',
  'Maya',
  'Leo',
];

/// Builds the full deterministic roster. Ratings spread over every tier so
/// matchmaking always finds a fair opponent near the player's rating.
List<BotPersona> buildBotRoster() {
  final roster = <BotPersona>[];
  for (var i = 0; i < botNames.length; i++) {
    final rating = 720 + ((i * 211) % 96) * 10;
    final tier = tierForRating(rating);
    final spec = specForTier(tier);
    final xp = 300 + ((i * 733) % 40) * 120;
    final streak = (spec.streakMedian + (i % 7) - 3).clamp(0, 120);
    roster.add(
      BotPersona(
        id: 'bot_$i',
        name: botNames[i],
        rating: rating,
        xp: xp,
        streak: streak,
        avatarSeed: i,
      ),
    );
  }
  return roster;
}

/// Picks a fair bot opponent near [playerRating].
///
/// Prefers the standard match window, then widens honestly to x2 and x3, and
/// only then falls back to the closest bot. [excludeIds] holds the LRU of
/// recent opponents so rematches feel fresh. Deterministic per [seed].
BotPersona? pickBotOpponent({
  required int playerRating,
  required List<BotPersona> roster,
  Set<String> excludeIds = const {},
  int seed = 0,
}) {
  if (roster.isEmpty) return null;
  final windows = <int>[
    BattleRating.matchWindow,
    BattleRating.matchWindow * 2,
    BattleRating.matchWindow * 3,
  ];
  for (final window in windows) {
    final pool = [
      for (final bot in roster)
        if ((bot.rating - playerRating).abs() <= window &&
            !excludeIds.contains(bot.id))
          bot,
    ];
    if (pool.isNotEmpty) {
      return pool[Random(seed).nextInt(pool.length)];
    }
  }
  final rest = [
    for (final bot in roster)
      if (!excludeIds.contains(bot.id)) bot,
  ];
  final pool = rest.isEmpty ? roster : rest;
  BotPersona best = pool.first;
  var bestGap = (best.rating - playerRating).abs();
  for (final bot in pool.skip(1)) {
    final gap = (bot.rating - playerRating).abs();
    if (gap < bestGap) {
      best = bot;
      bestGap = gap;
    }
  }
  return best;
}

/// Base accuracy for [bot], interpolated across its tier band plus a small
/// deterministic per-memory-kind bias in [-0.08, +0.08].
double botAccuracy({required BotPersona bot, int? kind}) {
  final spec = specForTier(bot.tier);
  final span = (spec.maxRating - spec.minRating).clamp(1, 10000);
  final pos = ((bot.rating - spec.minRating) / span).clamp(0.0, 1.0);
  var acc = spec.accMin + (spec.accMax - spec.accMin) * pos;
  if (kind != null) {
    final bias = ((botSeedHash('${bot.id}:$kind') % 17) - 8) / 100.0;
    acc += bias;
  }
  return acc.clamp(0.05, 0.98);
}

/// Samples a human-like answer latency for [bot].
///
/// Slower paradigms (backward span, pattern span, brown-peterson) take
/// longer, quick recognition paradigms take less. Result is in milliseconds.
int botLatencyMs({
  required BotPersona bot,
  required String paradigm,
  required Random rng,
}) {
  final spec = specForTier(bot.tier);
  final mult = _paradigmLatencyMult(paradigm);
  final mean = spec.latencyMeanMs * mult;
  final sigma = spec.latencySigmaMs * mult;
  final sample = (mean + nextGaussian(rng) * sigma).round();
  return sample.clamp(spec.latencyMinMs, spec.latencyMaxMs);
}

double _paradigmLatencyMult(String paradigm) {
  switch (paradigm) {
    case 'backward-span':
    case 'pattern-span':
    case 'brown-peterson':
      return 1.3;
    case 'story-recall':
    case 'category-exemplar':
      return 0.9;
    default:
      return 1.0;
  }
}

/// Matchmaking search time: uniform 2-6 seconds so every new search spins.
Duration matchmakingDelay(Random rng) {
  final ms = 2000 + rng.nextInt(4001);
  return Duration(milliseconds: ms);
}

/// Whether [bot] shows as online at [now].
///
/// Deterministic per hour bucket, weighted by tier activity and an evening
/// peak (18-22 local), so presence feels alive but stays restart-stable.
bool isBotOnline(BotPersona bot, DateTime now) {
  final spec = specForTier(bot.tier);
  final hourBucket = DateTime(now.year, now.month, now.day, now.hour);
  final roll = (botSeedHash('${bot.id}:${hourBucket.millisecondsSinceEpoch}') %
          1000) /
      1000.0;
  var p = spec.onlineP;
  if (now.hour >= 18 && now.hour < 22) p = (p * 1.8).clamp(0.0, 0.95);
  return roll < p;
}

/// Recall difficulty per paradigm: production (typed recall) is harder than
/// recognition (4-option pick), which the tier accuracy bands were tuned
/// for. Multiplicative, so tier ordering is preserved.
double botRecallDifficulty(String paradigm) {
  switch (paradigm) {
    case 'iconic-probe':
    case 'echoic-probe':
      return 0.95;
    case 'paired-associate':
    case 'keyword-pair':
    case 'face-name':
    case 'category-exemplar':
    case 'picture-recall':
    case 'loci-drill':
      return 0.80;
    case 'chunk-span':
    case 'pattern-span':
    case 'brown-peterson':
      return 0.65;
    case 'backward-span':
    case 'prospective-cue':
      return 0.55;
    default:
      return 0.75;
  }
}

/// Exact-recall probability for [bot] on [paradigm]: tier accuracy times
/// recall difficulty. Partial credit (near-miss) is sampled separately in
/// [botRecallOutcome].
double botRecallExactProb({
  required BotPersona bot,
  int? kind,
  required String paradigm,
}) {
  return (botAccuracy(bot: bot, kind: kind) * botRecallDifficulty(paradigm))
      .clamp(0.05, 0.98);
}

/// Probability of a near-miss given the answer is not exact. Strong bots
/// near-miss, weak bots clean-miss.
double botPartialGivenMiss(BotTier tier) {
  switch (tier) {
    case BotTier.rookie:
      return 0.25;
    case BotTier.contender:
      return 0.35;
    case BotTier.sharp:
      return 0.45;
    case BotTier.master:
      return 0.55;
    case BotTier.quantum:
      return 0.65;
  }
}

/// Partial-credit base (75/60/40 tier) from a uniform draw. 10% of partials
/// are full-content-with-typo (75); the 60/40 split favors strong tiers.
int botPartialBase(BotTier tier, double u) {
  if (u < 0.10) return 75;
  final p60 = switch (tier) {
    BotTier.rookie => 0.20,
    BotTier.contender => 0.30,
    BotTier.sharp => 0.45,
    BotTier.master => 0.60,
    BotTier.quantum => 0.75,
  };
  return u < 0.10 + p60 ? 60 : 40;
}

/// Representative proportion mapping back to [base] through the tiered
/// battle formula (exact 100 needs exact=true; 75 needs p>=1.0; 60 needs
/// p>=0.75; 40 needs p>=0.5).
double botPartialProportion(int base) {
  if (base >= 75) return 1.0;
  if (base >= 60) return 0.8;
  if (base >= 40) return 0.6;
  return 0.0;
}

/// One simulated human-memory answer: exact / partial / miss plus latency.
///
/// Draw order per question is fixed (exact, partial, quality, tail, then the
/// two latency draws inside [botLatencyMs]) so seeded duels stay
/// reproducible. [accuracyDelta] carries the rubber-band adjustment to the
/// exact probability only; [latencyFactor] scales the sampled latency.
/// Rookies blank on backward span 5% of the time (timeout tail).
({int base, bool exact, double proportion, int latencyMs}) botRecallOutcome({
  required BotPersona bot,
  int? kind,
  required String paradigm,
  required Random rng,
  int clockMs = 20000,
  double accuracyDelta = 0,
  double latencyFactor = 1.0,
}) {
  final uExact = rng.nextDouble();
  final uPartial = rng.nextDouble();
  final uQuality = rng.nextDouble();
  final uTail = rng.nextDouble();
  final baseMs = botLatencyMs(bot: bot, paradigm: paradigm, rng: rng);
  final recallMult = switch (paradigm) {
    'pattern-span' => 1.0,
    'backward-span' || 'brown-peterson' || 'chunk-span' => 1.25,
    _ => 1.15,
  };
  final pExact =
      (botRecallExactProb(bot: bot, kind: kind, paradigm: paradigm) +
              accuracyDelta)
          .clamp(0.05, 0.98);

  var base = 0;
  var exact = false;
  var proportion = 0.0;
  var outcomeMult = 1.10;
  if (uExact < pExact) {
    base = 100;
    exact = true;
    proportion = 1.0;
    outcomeMult = 1.0;
  } else if (uPartial < botPartialGivenMiss(bot.tier)) {
    base = botPartialBase(bot.tier, uQuality);
    proportion = botPartialProportion(base);
    outcomeMult = 1.05;
  }
  if (bot.tier == BotTier.rookie &&
      paradigm == 'backward-span' &&
      uTail < 0.05) {
    return (base: 0, exact: false, proportion: 0.0, latencyMs: clockMs);
  }
  final ms = (baseMs * recallMult * outcomeMult * latencyFactor)
      .round()
      .clamp(800, clockMs);
  return (base: base, exact: exact, proportion: proportion, latencyMs: ms);
}

/// Rubber-banding that keeps duels close without ever flipping a locked
/// answer. Only affects future questions; adjustments are capped at +-0.08
/// absolute accuracy and a 0.90/1.10 latency factor.
({double accuracy, int latencyMs}) applyRubberBand({
  required double baseAccuracy,
  required int baseLatencyMs,
  required int playerTotal,
  required int foeTotal,
  required int questionIndex,
  required int questionCount,
  required int playerRating,
  required int matchesPlayed,
}) {
  var acc = baseAccuracy;
  var latency = baseLatencyMs;
  final isFinal = questionIndex >= questionCount - 1;
  final gap = (playerTotal - foeTotal).abs();
  if (!isFinal || gap >= 60) {
    if (playerTotal - foeTotal >= 150) {
      acc += 0.08;
      latency = (latency * 0.90).round();
    } else if (foeTotal - playerTotal >= 150) {
      acc -= 0.08;
      latency = (latency * 1.10).round();
    }
  }
  if (playerRating < 1050 && matchesPlayed < 5) {
    acc -= 0.05;
  }
  return (
    accuracy: acc.clamp(0.05, 0.98),
    latencyMs: latency.clamp(800, 20000),
  );
}
