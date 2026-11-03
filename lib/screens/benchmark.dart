import '../theme/app_theme.dart';
import '../theme/app_tokens.dart';

import 'dart:async';
import 'dart:math';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../widgets/ai_help_button.dart';
import '../widgets/ai_image.dart';
import '../widgets/app_buttons.dart';
import '../widgets/app_kit.dart';
import '../widgets/room_palace_home_card.dart';
import '../widgets/session_coach_card.dart';
import '../l10n/app_localizations.dart';
import '../models/meta_task.dart';
import '../models/sam_mask.dart'
    show
        SamMaskRun,
        decodeSamMaskToken,
        parseSamMaskToken,
        samMaskCentroid,
        samMaskRuns;
import '../models/palace_drill.dart'
    show
        allConcreteNounsFor,
        localPalaceTask,
        localPictureTask,
        matchRecallAnswer,
        palaceRoutesFor;
import '../services/app_feedback.dart';
import '../services/memory_store.dart';
import '../services/meta_ai_service.dart';
import '../utils/test_mode.dart';
import 'benchmark_stats.dart' show BenchmarkDetailPage;
import 'room_palace_page.dart' show RoomPalacePage;
import '../theme/app_colors.dart' show blue, blueDark, teal, orange, coral, sky;

final _rnd = Random();

class BenchmarkStore {
  static final Map<String, int> best = {};
  static final Map<String, List<int>> attempts = {};
  static int xp = 0;
  static int plays = 0;
  static bool bonusClaimed = false;
  static bool loaded = false;
  static Future<void>? _loading;
  static Future<void> _persistQueue = Future.value();

  /// Loads persisted totals once. Never throws.
  static Future<void> ensureLoaded() {
    final pending = _loading;
    if (pending != null) return pending;
    final future = _load();
    _loading = future;
    return future;
  }

  static Future<void> _load() async {
    try {
      final saved = await MemoryStore.loadBenchmark();
      best
        ..clear()
        ..addAll(saved.best);
      attempts
        ..clear()
        ..addAll(saved.attempts);
      xp = saved.xp;
      plays = saved.plays;
      bonusClaimed = saved.bonusClaimed;
    } catch (_) {
    } finally {
      loaded = true;
    }
  }

  static void submit(
    String id,
    int score, {
    required bool higherIsBetter,
    int xpGain = 10,
  }) {
    plays++;
    xp += xpGain;
    final list = attempts.putIfAbsent(id, () => <int>[]);
    list.add(score);
    if (list.length > MemoryStore.benchmarkAttemptsCap) {
      list.removeRange(0, list.length - MemoryStore.benchmarkAttemptsCap);
    }
    final prev = best[id];
    if (prev == null) {
      best[id] = score;
    } else if (higherIsBetter) {
      if (score > prev) best[id] = score;
    } else {
      if (score > 0 && score < prev) best[id] = score;
    }
    _persist();
  }

  static void _persist() {
    _persistQueue = _persistQueue.then((_) => _saveNow());
  }

  static Future<void> _saveNow() async {
    try {
      await MemoryStore.saveBenchmark(
        BenchmarkState(
          best: Map.of(best),
          attempts: {for (final e in attempts.entries) e.key: List.of(e.value)},
          xp: xp,
          plays: plays,
          bonusClaimed: bonusClaimed,
        ),
      );
    } catch (_) {}
  }

  static int get level => xp ~/ 120 + 1;
  static double get levelProgress => (xp % 120) / 120;

  @visibleForTesting
  static void resetForTest() {
    best.clear();
    attempts.clear();
    xp = 0;
    plays = 0;
    bonusClaimed = false;
    loaded = false;
    _loading = null;
    _persistQueue = Future.value();
  }
}

/// Practice-game stimulus deals. Every method returns the stimulus PLUS
/// whether it came from a live model (`live: false` = local deal). The
/// game pages feed that flag into the AI strip, so the strip always names
/// the models that actually dealt the current round — never more.
class BenchmarkMeta {
  static Future<({String text, bool live})> numberStimulus(int digits) async {
    try {
      final task = await MetaAIService.generateTask(
        MetaTaskRequest(kind: 'number', difficulty: digits.clamp(1, 9)),
      );
      if (!task.fallback && task.items.isNotEmpty) {
        return (text: task.items.first, live: true);
      }
    } catch (_) {}
    return (text: NumberGamePage.make(digits), live: false);
  }

  /// Fresh nouns for the verbal game, batched from Muse Spark. Never
  /// throws: offline this is local nouns the player has not seen yet.
  static Future<({List<String> words, bool live})> wordBatch({
    int count = 12,
    List<String> avoid = const [],
    String locale = 'en',
  }) async {
    try {
      final answer = await MetaAIService.fetchWordBatch(
        count: count,
        avoid: avoid,
        locale: locale,
      );
      return (words: answer.words, live: !answer.fallback);
    } catch (_) {
      return (words: const <String>[], live: false);
    }
  }

  /// Ordered Wonder viewpoints for a palace walk. Never throws:
  /// offline this is one local caption per station.
  static Future<({List<String> views, bool live})> wonderPreview({
    required String route,
    required List<String> stations,
    String locale = 'en',
  }) async {
    try {
      final answer = await MetaAIService.wonderRoutePreview(
        route: route,
        stations: stations,
        locale: locale,
      );
      return (views: answer.viewpoints, live: !answer.fallback);
    } catch (_) {
      return (views: const <String>[], live: false);
    }
  }

  /// Folds AI digits into a shuffling seed so the text model can deal
  /// layouts (number-order game) without inventing a new format.
  static int seedFromDigits(List<int> digits) {
    var h = 0;
    for (final d in digits) {
      h = (h * 31 + d) & 0x7fffffff;
    }
    return h ^ digits.length;
  }

  static Future<({List<int> digits, bool live})> sequenceStimulus(
    int length,
  ) async {
    try {
      final task = await MetaAIService.generateTask(
        MetaTaskRequest(kind: 'sequence', difficulty: length.clamp(1, 5)),
      );
      if (!task.fallback && task.items.isNotEmpty) {
        return (
          digits: [for (final e in task.items) int.tryParse(e) ?? 0],
          live: true,
        );
      }
    } catch (_) {}
    return (digits: SequenceGamePage.make(length), live: false);
  }

  /// Pattern-span layout with the EXACT cell count the grid needs, dealt
  /// by Muse Spark when online. Offline this is a local deal (no image).
  static Future<({Set<int> cells, bool live})> visualPattern(
    int size,
    int count,
  ) async {
    try {
      return await MetaAIService.generatePatternCells(size: size, count: count);
    } catch (_) {
      return (
        cells: MetaAIService.localPatternCells(size: size, count: count),
        live: false,
      );
    }
  }

  /// Picture-recall round: Muse Spark fills the scene stimulus, Muse Image
  /// paints it, SAM spots the details. Offline this is just the local
  /// picture task (no image). Mirrors the lesson path (Spark then enrich).
  static Future<MetaTask> pictureRound({
    required String seed,
    int difficulty = 2,
    String locale = 'en',
  }) async {
    bool live = false;
    try {
      live = await MetaAIService.hasAnyKey();
    } catch (_) {}
    if (!live) {
      return localPictureTask(
        difficulty: difficulty,
        seed: seed,
        locale: locale,
      );
    }
    MetaTask base;
    try {
      base = await MetaAIService.generateTask(
        MetaTaskRequest(
          kind: 'visual',
          difficulty: difficulty.clamp(1, 5),
          seed: seed,
          locale: locale,
        ),
      );
      if (base.fallback) {
        base = localPictureTask(
          difficulty: difficulty,
          seed: seed,
          locale: locale,
        );
      }
    } catch (_) {
      base = localPictureTask(
        difficulty: difficulty,
        seed: seed,
        locale: locale,
      );
    }
    try {
      return await MetaAIService.enrichVisualTask(base, seed: seed);
    } catch (_) {
      return base;
    }
  }

  /// Spatial practice round: Muse Spark fills the station-word stimulus
  /// when live, otherwise the local palace task. Deliberately NO image
  /// enrichment on the practice path: the player rehearses in their OWN
  /// palace (typed on the setup screen), so a generic AI palace painting
  /// would only confuse and slow the round — ordered stations plus words
  /// are the whole loci probe.
  static Future<MetaTask> spatialRound({
    required String seed,
    required int stations,
    String locale = 'en',
  }) async {
    final difficulty = (stations - 3).clamp(1, 5);
    bool live = false;
    try {
      live = await MetaAIService.hasAnyKey();
    } catch (_) {}
    if (!live) {
      return localPalaceTask(
        difficulty: difficulty,
        seed: seed,
        locale: locale,
        count: stations,
      );
    }
    MetaTask base;
    try {
      base = await MetaAIService.generateTask(
        MetaTaskRequest(
          kind: 'spatial',
          difficulty: difficulty,
          seed: seed,
          locale: locale,
        ),
      );
      if (base.fallback || base.items.length != stations) {
        base = localPalaceTask(
          difficulty: difficulty,
          seed: seed,
          locale: locale,
          count: stations,
        );
      }
    } catch (_) {
      base = localPalaceTask(
        difficulty: difficulty,
        seed: seed,
        locale: locale,
        count: stations,
      );
    }
    return base;
  }
}

class _AiTip extends StatefulWidget {
  final String gameId;
  final int level;
  const _AiTip({required this.gameId, required this.level});

  @override
  State<_AiTip> createState() => _AiTipState();
}

class _AiTipState extends State<_AiTip> {
  late final Future<CoachAnswer> _future = MetaAIService.openPracticeTip(
    gameId: widget.gameId,
    level: widget.level.clamp(1, 99),
    locale: AppLocalizations.localeCode,
  );

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<CoachAnswer>(
      future: _future,
      builder: (context, snap) {
        final text = snap.data?.text ?? '';
        if (text.isEmpty) return const SizedBox.shrink();
        return Container(
          width: double.infinity,
          margin: const EdgeInsets.only(top: 10),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: context.cardBg,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: context.hairline, width: 2),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      tr('ai_tip_title'),
                      style: TextStyle(
                        color: context.mutedText,
                        fontWeight: FontWeight.w800,
                        fontSize: 12,
                        letterSpacing: 1.2,
                      ),
                    ),
                  ),
                  Text(
                    snap.data?.fallback == false ? 'SPARK OPEN' : 'LOCAL',
                    style: TextStyle(
                      color: context.mutedText,
                      fontWeight: FontWeight.w700,
                      fontSize: 12,
                      letterSpacing: 1.0,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                text,
                style: TextStyle(
                  color: context.inkText,
                  fontSize: 13,
                  height: 1.45,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// One-line strip naming the Meta models behind the current round, with
/// an honest live/local badge: [live] is true only when the CURRENT
/// round's stimulus actually came from a live model (the game pages feed
/// it from each deal's fallback flag). Local rounds say so instead of
/// borrowing the models' names. While the round is still loading
/// ([loading]), the strip says connecting instead of claiming local —
/// the outcome is not decided yet.
class _AiModelsStrip extends StatelessWidget {
  final String models;
  final bool live;
  final bool loading;
  const _AiModelsStrip(this.models, {this.live = false, this.loading = false});

  @override
  Widget build(BuildContext context) {
    final dot = loading ? blue : (live ? teal : context.mutedText);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          HugeIcon(
            icon: HugeIcons.strokeRoundedSparkles,
            color: context.mutedText,
            size: 14,
            strokeWidth: 2.0,
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              loading
                  ? tr('bench_ai_models_connecting', {'models': models})
                  : live
                  ? tr('bench_ai_models', {'models': models})
                  : tr('bench_ai_models_local', {'models': models}),
              style: TextStyle(color: context.mutedText, fontSize: 12),
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: dot.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: dot.withValues(alpha: 0.4)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 6,
                  height: 6,
                  decoration: BoxDecoration(color: dot, shape: BoxShape.circle),
                ),
                const SizedBox(width: 4),
                Text(
                  loading
                      ? tr('bench_ai_connecting')
                      : live
                      ? tr('bench_ai_live')
                      : tr('bench_ai_local'),
                  style: TextStyle(
                    color: dot,
                    fontWeight: FontWeight.w800,
                    fontSize: 12,
                    letterSpacing: 1.0,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// End-of-run verdict from the text model (Muse Spark) plus a button
/// that opens the AI coach, pre-briefed on this run, for questions.
class _AiVerdict extends StatefulWidget {
  final String gameId;
  final int score;
  const _AiVerdict({required this.gameId, required this.score});

  @override
  State<_AiVerdict> createState() => _AiVerdictState();
}

class _AiVerdictState extends State<_AiVerdict> {
  late final Future<CoachAnswer> _future = MetaAIService.gameRecap(
    gameId: widget.gameId,
    score: widget.score,
    best: BenchmarkStore.best[widget.gameId] ?? widget.score,
    locale: AppLocalizations.localeCode,
  );
  late final Future<CoachAnswer> _glimmer = MetaAIService.glimmerTake(
    gameId: widget.gameId,
    score: widget.score,
    best: BenchmarkStore.best[widget.gameId] ?? widget.score,
    locale: AppLocalizations.localeCode,
  );
  @override
  Widget build(BuildContext context) {
    return FutureBuilder<CoachAnswer>(
      future: _future,
      builder: (context, snap) {
        final text = snap.data?.text ?? '';
        if (text.isEmpty) return const SizedBox.shrink();
        return FutureBuilder<CoachAnswer>(
          future: _glimmer,
          builder: (context, gsnap) {
            final line = gsnap.data?.text ?? '';
            final sparkLive = snap.data?.fallback == false;
            final glimmerLive = gsnap.data?.fallback == false;
            final source = sparkLive && glimmerLive
                ? 'SPARK • GLIMMER'
                : sparkLive
                ? 'SPARK'
                : glimmerLive
                ? 'GLIMMER'
                : 'LOCAL';
            return Container(
              width: double.infinity,
              margin: const EdgeInsets.only(top: 10),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: context.cardBg,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: context.hairline, width: 2),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          tr('ai_verdict_title'),
                          style: TextStyle(
                            color: context.mutedText,
                            fontWeight: FontWeight.w800,
                            fontSize: 12,
                            letterSpacing: 1.2,
                          ),
                        ),
                      ),
                      Text(
                        source,
                        style: TextStyle(
                          color: context.mutedText,
                          fontWeight: FontWeight.w700,
                          fontSize: 12,
                          letterSpacing: 1.0,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  if (line.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Text(
                        line,
                        style: TextStyle(
                          color: context.mutedText,
                          fontStyle: FontStyle.italic,
                          fontSize: 12,
                          height: 1.45,
                        ),
                      ),
                    ),
                  Text(
                    text,
                    style: TextStyle(
                      color: context.inkText,
                      fontSize: 13,
                      height: 1.45,
                    ),
                  ),
                  const SizedBox(height: 10),
                  _bigButton(
                    context,
                    label: tr('bench_ask_ai'),
                    color: context.accentText(blue),
                    onTap: () => openAiHelpSheet(
                      context,
                      topic: AiHelpTopics.benchmark,
                      helpContext:
                          '${widget.gameId} practice, just scored ${widget.score}',
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}

class _GameDef {
  final String id;
  final List<List<dynamic>> icon;
  final Color tint;
  final Widget Function() build;
  const _GameDef({
    required this.id,
    required this.icon,
    required this.tint,
    required this.build,
  });

  String titleIn([String locale = 'en']) =>
      trFor(locale, 'bench_game_${id}_title');

  String subtitleIn([String locale = 'en']) =>
      trFor(locale, 'bench_game_${id}_sub');

  String bestLabelIn([String locale = 'en']) =>
      trFor(locale, 'bench_game_${id}_best');
}

final _games = <_GameDef>[
  _GameDef(
    id: 'sequence',
    icon: HugeIcons.strokeRoundedLayers01,
    tint: blue,
    build: () => const SequenceGamePage(),
  ),
  _GameDef(
    id: 'number',
    icon: HugeIcons.strokeRoundedHash,
    tint: sky,
    build: () => const NumberGamePage(),
  ),
  _GameDef(
    id: 'verbal',
    icon: HugeIcons.strokeRoundedNotebook01,
    tint: teal,
    build: () => const VerbalGamePage(),
  ),
  _GameDef(
    id: 'visual',
    icon: HugeIcons.strokeRoundedEye,
    tint: blueDark,
    // The hub opens the SAM picture-masking game first (the demo path);
    // the pattern grid stays one toggle tap away, and a saved mode
    // choice always wins over this entry default.
    build: () => const VisualGamePage(initialMode: 'mask'),
  ),
  _GameDef(
    id: 'order',
    icon: HugeIcons.strokeRoundedBrain01,
    tint: orange,
    build: () => const NumberOrderGamePage(),
  ),
  _GameDef(
    id: 'spatial',
    icon: HugeIcons.strokeRoundedCastle01,
    tint: coral,
    build: () => const SpatialGamePage(),
  ),
];

/// Icon of the practice game with [id], for rows outside the hub
/// (the Session Coach plan rows use the same tile icon as the cards).
/// Falls back to the generic controller when the id is unknown.
dynamic benchGameIcon(String id) {
  for (final g in _games) {
    if (g.id == id) return g.icon;
  }
  return HugeIcons.strokeRoundedGameController01;
}

/// Opens one practice game exactly as the hub card does.
Future<void> openPracticeGame(BuildContext context, String gameId) async {
  final g = _games.firstWhere(
    (d) => d.id == gameId,
    orElse: () => _games.first,
  );
  AppFeedback.light();
  await Navigator.of(context).push(
    MaterialPageRoute(
      builder: (_) => BenchmarkDetailPage(
        gameId: g.id,
        title: g.titleIn(AppLocalizations.localeCode),
        subtitle: g.subtitleIn(AppLocalizations.localeCode),
        tint: g.tint,
        bestLabel: g.bestLabelIn(AppLocalizations.localeCode),
        higherIsBetter: true,
        best: BenchmarkStore.best[g.id],
        attempts: List.of(BenchmarkStore.attempts[g.id] ?? const <int>[]),
        buildGame: g.build,
        loadBest: () => BenchmarkStore.best[g.id],
        loadAttempts: () =>
            List.of(BenchmarkStore.attempts[g.id] ?? const <int>[]),
      ),
    ),
  );
}

class BenchmarkHubPage extends StatefulWidget {
  final VoidCallback? onGoHome;
  const BenchmarkHubPage({super.key, this.onGoHome});

  @override
  State<BenchmarkHubPage> createState() => _BenchmarkHubPageState();
}

class _BenchmarkHubPageState extends State<BenchmarkHubPage> {
  Future<void> _openRoomPalace() async {
    AppFeedback.light();
    await Navigator.of(context)
        .push(MaterialPageRoute(builder: (_) => const RoomPalacePage()));
    if (mounted) setState(() {});
  }

  @override
  void initState() {
    super.initState();
    BenchmarkStore.ensureLoaded().then((_) {
      if (mounted) setState(() {});
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      // Content scrolls to the screen edge under the floating nav bar; the
      // list's own bottom padding keeps the last card clear of it.
      body: SafeArea(
        top: false,
        bottom: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 120),
          children: [
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: Text(
                    tr('bench_hub_title'),
                    style: AppText.display.copyWith(
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                ),
                const AiHelpButton(topic: AiHelpTopics.benchmark),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              tr('bench_hub_sub'),
              style: AppText.caption.copyWith(color: context.mutedText),
            ),
            const SizedBox(height: 16),
            RoomPalaceHomeCard(
              key: const ValueKey('room-palace-hero'),
              onTap: _openRoomPalace,
            ),
            const SizedBox(height: 12),
            SessionCoachCard(onGoHome: widget.onGoHome),
            const SizedBox(height: 12),
            if (!BenchmarkStore.loaded) const AppSkeletonList(),
            for (final g in _games) ...[
              _BenchmarkCard(
                def: g,
                onTap: () async {
                  await openPracticeGame(context, g.id);
                  if (mounted) setState(() {});
                },
              ),
              const SizedBox(height: 10),
            ],
            Text(
              tr('bench_hub_tip'),
              textAlign: TextAlign.center,
              style: AppText.caption.copyWith(color: context.mutedText),
            ),
          ],
        ),
      ),
    );
  }
}

class _BenchmarkCard extends StatelessWidget {
  final _GameDef def;
  final VoidCallback onTap;
  const _BenchmarkCard({required this.def, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final b = BenchmarkStore.best[def.id];
    return Tappable(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: context.cardBg,
          borderRadius: BorderRadius.circular(AppRadius.l),
          border: Border.all(color: context.hairline, width: 2),
        ),
        child: Row(
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: def.tint.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(AppRadius.m),
              ),
              alignment: Alignment.center,
              child: HugeIcon(
                icon: def.icon,
                color: def.tint,
                size: 26,
                strokeWidth: 2.0,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    def.titleIn(AppLocalizations.localeCode),
                    style: AppText.heading.copyWith(color: context.inkText),
                  ),
                  Text(
                    def.subtitleIn(AppLocalizations.localeCode),
                    style: AppText.caption.copyWith(color: context.mutedText),
                  ),
                ],
              ),
            ),
            if (b == null)
              HugeIcon(
                icon: HugeIcons.strokeRoundedArrowRight01,
                color: context.mutedText,
                size: 20,
                strokeWidth: 2.2,
              )
            else
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '$b ${def.bestLabelIn(AppLocalizations.localeCode)}',
                    style: AppText.body.copyWith(color: context.inkText),
                  ),
                  HugeIcon(
                    icon: HugeIcons.strokeRoundedArrowRight01,
                    color: context.mutedText,
                    size: 20,
                    strokeWidth: 2.2,
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}

/// Formats a practice duration as m:ss (0:07, 2:31).
String _formatElapsed(Duration d) {
  final total = d.inSeconds.clamp(0, 5999);
  return '${total ~/ 60}:${(total % 60).toString().padLeft(2, '0')}';
}

/// Ticking practice clock. The memorize phases never auto-hide anymore —
/// the player sets the pace with the got-it button, and this chip makes
/// the measured time visible instead of a hidden countdown.
class _LiveTimerChip extends StatefulWidget {
  final DateTime since;
  const _LiveTimerChip({required this.since});

  @override
  State<_LiveTimerChip> createState() => _LiveTimerChipState();
}

class _LiveTimerChipState extends State<_LiveTimerChip> {
  Timer? _tick;

  @override
  void initState() {
    super.initState();
    _tick = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _tick?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Text(
      tr('bench_time_live', {
        't': _formatElapsed(DateTime.now().difference(widget.since)),
      }),
      style: TextStyle(
        color: context.mutedText,
        fontWeight: FontWeight.bold,
        fontSize: 12,
      ),
    );
  }
}

Widget _gameScaffold({
  required BuildContext context,
  required String title,
  required String counter,
  required Widget body,
  String aiModels = '',
  bool aiLive = false,
  bool aiLoading = false,
  DateTime? timerSince,
}) {
  return Scaffold(
    backgroundColor: Theme.of(context).scaffoldBackgroundColor,
    appBar: AppTopBar(
      title: title,
      leading: const EngramBackButton(),
      // 360px-es keskeny kijelzőn is be kell férnie: a metaadatok
      // 12-esek, a jobb szélső térközt a sáv saját 16-os margója adja.
      actions: [
        if (timerSince != null)
          Padding(
            padding: const EdgeInsets.only(right: 4),
            child: Center(child: _LiveTimerChip(since: timerSince)),
          ),
        Padding(
          padding: const EdgeInsets.only(right: 4),
          child: Center(
            child: Text(
              counter,
              style: TextStyle(
                color: context.mutedText,
                fontWeight: FontWeight.bold,
                fontSize: 12,
              ),
            ),
          ),
        ),
        const Center(child: AiHelpButton(topic: AiHelpTopics.benchmark)),
      ],
    ),
    body: aiModels.isEmpty
        ? body
        : Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                child: _AiModelsStrip(
                  aiModels,
                  live: aiLive,
                  loading: aiLoading,
                ),
              ),
              Expanded(child: body),
            ],
          ),
  );
}

/// Brain-game-trap guard for practice games. Drills alone improve mostly
/// the drilled screen (Simons et al. 2016; Owen et al. 2010) — durable
/// daily-life skill comes from the SAME procedure on the user's OWN
/// material (Dresler et al. 2017; Dunlosky et al. 2013). This card names
/// the strategy the game rehearses (with its source procedure), one
/// real-life destination, and one own-material micro-mission. Static
/// copy (claims-safe), shown on every result screen.
class _TransferCard extends StatelessWidget {
  final String gameId;
  const _TransferCard(this.gameId);

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(top: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: context.cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: teal, width: 2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            tr('bench_transfer_title'),
            style: TextStyle(
              color: context.mutedText,
              fontWeight: FontWeight.w800,
              fontSize: 12,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            tr('bench_transfer_${gameId}_tech'),
            style: TextStyle(
              color: context.inkText,
              fontSize: 13,
              height: 1.45,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            tr('bench_transfer_${gameId}_life'),
            style: TextStyle(
              color: context.mutedText,
              fontStyle: FontStyle.italic,
              fontSize: 12,
              height: 1.45,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              HugeIcon(
                icon: HugeIcons.strokeRoundedTarget02,
                color: teal,
                size: 16,
                strokeWidth: 2.2,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  tr('bench_transfer_${gameId}_mission'),
                  style: TextStyle(
                    color: context.inkText,
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                    height: 1.45,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

Widget _bigButton(
  BuildContext context, {
  required String label,
  required VoidCallback? onTap,
  Color color = blue,
}) {
  final disabled = onTap == null;
  final top = disabled ? context.hairline : color;
  return GestureDetector(
    onTap: disabled
        ? null
        : () {
            AppFeedback.light();
            onTap.call();
          },
    child: Container(
      height: 56,
      width: double.infinity,
      decoration: BoxDecoration(
        color: top,
        borderRadius: BorderRadius.circular(999),
      ),
      alignment: Alignment.center,
      child: Text(
        label,
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w800,
          fontSize: 17,
          letterSpacing: 0.5,
        ),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
    ),
  );
}

/// Fix magasságú instrukciósáv a rácsos játékok fölött: a fázisváltáskor
/// cserélődő szöveg (rövid „jegyezd meg" → hosszú „koppints vissza")
/// nem tolhatja lejjebb a rácsot és az ELLENŐRZÉS gombot.
class _FixedInstruction extends StatelessWidget {
  final String text;
  const _FixedInstruction(this.text);

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 46),
      child: Text(
        text,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          color: Theme.of(context).colorScheme.onSurface,
          fontWeight: FontWeight.bold,
          fontSize: 16,
          height: 1.35,
        ),
      ),
    );
  }
}

Widget _resultBox(
  BuildContext context, {
  required String title,
  required String detail,
  required VoidCallback onRetry,
  required String retryLabel,
  String? footer,
}) {
  return Column(
    children: [
      Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: context.cardBg,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: orange, width: 2),
        ),
        child: Column(
          children: [
            HugeIcon(
              icon: HugeIcons.strokeRoundedTrophy,
              color: orange,
              size: 40,
              strokeWidth: 1.8,
            ),
            const SizedBox(height: 8),
            Text(
              title,
              style: TextStyle(
                color: context.inkText,
                fontWeight: FontWeight.bold,
                fontSize: 22,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              detail,
              textAlign: TextAlign.center,
              style: TextStyle(color: context.mutedText, fontSize: 14),
            ),
            if (footer != null) ...[
              const SizedBox(height: 6),
              Text(
                footer,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: context.mutedText,
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                ),
              ),
            ],
          ],
        ),
      ),
      const SizedBox(height: 12),
      _bigButton(context, label: retryLabel, onTap: onRetry),
    ],
  );
}

class SequenceGamePage extends StatefulWidget {
  const SequenceGamePage({super.key});

  static List<int> make(int length) {
    final n = length.clamp(1, 12);
    return [for (var i = 0; i < n; i++) _rnd.nextInt(9)];
  }

  @override
  State<SequenceGamePage> createState() => _SequenceGamePageState();
}

class _SequenceGamePageState extends State<SequenceGamePage> {
  int _level = 1;
  final List<int> _seq = [];
  int _showing = -1;
  int _input = 0;
  bool _busy = false;
  bool _over = false;
  int? _aiNext;
  bool _aiNextLive = false;
  bool _roundLive = false;
  DateTime _startedAt = DateTime.now();
  DateTime? _endedAt;

  @override
  void initState() {
    super.initState();
    _nextRound();
  }

  void _nextRound() {
    final ai = _aiNext;
    final live = ai != null && _aiNextLive;
    _aiNext = null;
    _aiNextLive = false;
    setState(() {
      _busy = true;
      _over = false;
      _seq.add(ai ?? _rnd.nextInt(9));
      _input = 0;
      _level = _seq.length;
      _roundLive = live;
    });
    _play();
    unawaited(_prefetchNext());
  }

  Future<void> _prefetchNext() async {
    try {
      final res = await BenchmarkMeta.sequenceStimulus(1);
      if (res.digits.isNotEmpty && mounted && !_over) {
        _aiNext = res.digits.first % 9;
        _aiNextLive = res.live;
      }
    } catch (_) {}
  }

  Future<void> _play() async {
    await Future.delayed(const Duration(milliseconds: 600));
    for (final v in _seq) {
      if (!mounted || _over) return;
      setState(() => _showing = v);
      await Future.delayed(const Duration(milliseconds: 550));
      if (!mounted || _over) return;
      setState(() => _showing = -1);
      await Future.delayed(const Duration(milliseconds: 250));
    }
    if (mounted) setState(() => _busy = false);
  }

  void _tap(int i) {
    if (_busy || _over) return;
    if (i == _seq[_input]) {
      _input++;
      if (_input >= _seq.length) {
        BenchmarkStore.submit(
          'sequence',
          _level,
          higherIsBetter: true,
          xpGain: 8 + _level * 2,
        );
        _nextRound();
      } else {
        setState(() {});
      }
    } else {
      final score = _seq.length - 1;
      BenchmarkStore.submit('sequence', score, higherIsBetter: true, xpGain: 5);
      setState(() {
        _over = true;
        _endedAt = DateTime.now();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return _gameScaffold(
      context: context,
      title: tr('bench_game_sequence_title'),
      counter: tr('bench_level_n', {'n': _level}),
      aiModels: 'Muse Spark',
      aiLive: _roundLive,
      timerSince: _startedAt,
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
        children: [
          if (_over) ...[
            _resultBox(
              context,
              title: tr('bench_seq_done_title'),
              detail: tr('bench_seq_done_detail', {'n': _seq.length - 1}),
              onRetry: () => setState(() {
                _seq.clear();
                _startedAt = DateTime.now();
                _endedAt = null;
                _nextRound();
              }),
              retryLabel: tr('bench_retry_xp'),
              footer: tr('bench_time_total', {
                't': _formatElapsed(
                  (_endedAt ?? DateTime.now()).difference(_startedAt),
                ),
              }),
            ),
            _TransferCard('sequence'),
            _AiTip(gameId: 'sequence', level: _seq.length - 1),
            _AiVerdict(gameId: 'sequence', score: _seq.length - 1),
          ] else ...[
            _FixedInstruction(
              _busy
                  ? tr('bench_seq_watch', {'n': _level})
                  : tr('bench_seq_turn'),
            ),
            const SizedBox(height: 12),
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                mainAxisSpacing: 10,
                crossAxisSpacing: 10,
              ),
              itemCount: 9,
              itemBuilder: (_, i) {
                final lit = _showing == i;
                return GestureDetector(
                  onTap: () {
                    _tap(i);
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    decoration: BoxDecoration(
                      color: lit ? orange : context.cardBg,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: lit ? orange : context.hairline,
                        width: 2,
                      ),
                      boxShadow: lit
                          ? [
                              BoxShadow(
                                color: orange.withValues(alpha: 0.5),
                                blurRadius: 16,
                              ),
                            ]
                          : null,
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: 12),
            AppProgressBar(value: _busy ? 0 : _input / _seq.length, height: 8),
          ],
        ],
      ),
    );
  }
}

class NumberGamePage extends StatefulWidget {
  const NumberGamePage({super.key});

  static String make(int digits) {
    final n = digits.clamp(1, 12);
    final sb = StringBuffer('${1 + _rnd.nextInt(9)}');
    for (var i = 1; i < n; i++) {
      sb.write(_rnd.nextInt(10));
    }
    return sb.toString();
  }

  @override
  State<NumberGamePage> createState() => _NumberGamePageState();
}

class _NumberGamePageState extends State<NumberGamePage> {
  int _digits = 3;
  late String _number = _make(_digits);
  bool _show = true;
  List<String> _options = [];
  bool _over = false;
  String? _aiNext;
  bool _aiNextLive = false;
  bool _roundLive = false;
  DateTime _startedAt = DateTime.now();
  DateTime? _endedAt;
  DateTime? _shownAt;
  int? _memorizeSecs;

  static String _make(int digits) {
    final sb = StringBuffer();
    sb.write(1 + _rnd.nextInt(9));
    for (var i = 1; i < digits; i++) {
      sb.write(_rnd.nextInt(10));
    }
    return sb.toString();
  }

  @override
  void initState() {
    super.initState();
    _deal();
  }

  void _deal() {
    final ai = _aiNext;
    final aiLive = _aiNextLive;
    _aiNext = null;
    _aiNextLive = false;
    final cleaned = (ai ?? '').replaceAll(RegExp('[^0-9]'), '');
    if (cleaned.length >= _digits) {
      _number = cleaned.substring(0, _digits);
      _roundLive = aiLive;
    } else {
      _number = _make(_digits);
      _roundLive = false;
    }
    final set = <String>{_number};
    while (set.length < 4) {
      final d = _make(_digits);
      set.add(d);
    }
    _options = set.toList()..shuffle();
    _show = true;
    _shownAt = DateTime.now();
    _memorizeSecs = null;
    unawaited(_prefetchNext());
  }

  /// The memorize screen only ever hides through this button: no timer
  /// steals the number. The self-paced memorize time is the measured
  /// challenge instead.
  void _ask() {
    final shown = _shownAt;
    setState(() {
      _memorizeSecs = shown == null
          ? 0
          : DateTime.now().difference(shown).inSeconds.clamp(0, 5999);
      _show = false;
    });
  }

  Future<void> _prefetchNext() async {
    try {
      final res = await BenchmarkMeta.numberStimulus(_digits + 1);
      if (mounted && !_over) {
        _aiNext = res.text;
        _aiNextLive = res.live;
      }
    } catch (_) {}
  }

  void _pick(String v) {
    if (_show || _over) return;
    if (v == _number) {
      BenchmarkStore.submit(
        'number',
        _digits,
        higherIsBetter: true,
        xpGain: 8 + _digits * 3,
      );
      setState(() {
        _digits++;
        _deal();
      });
    } else {
      BenchmarkStore.submit(
        'number',
        _digits - 1,
        higherIsBetter: true,
        xpGain: 5,
      );
      setState(() {
        _over = true;
        _endedAt = DateTime.now();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return _gameScaffold(
      context: context,
      title: tr('bench_game_number_title'),
      counter: tr('bench_digits_n', {'n': _digits}),
      aiModels: 'Muse Spark',
      aiLive: _roundLive,
      timerSince: _startedAt,
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
        children: [
          if (_over) ...[
            _resultBox(
              context,
              title: tr('bench_num_done_title', {'n': _digits - 1}),
              detail: tr('bench_num_done_detail'),
              onRetry: () => setState(() {
                _digits = 3;
                _over = false;
                _startedAt = DateTime.now();
                _endedAt = null;
                _deal();
              }),
              retryLabel: tr('bench_restart'),
              footer: tr('bench_time_total', {
                't': _formatElapsed(
                  (_endedAt ?? DateTime.now()).difference(_startedAt),
                ),
              }),
            ),
            _TransferCard('number'),
            _AiTip(gameId: 'number', level: _digits - 1),
            _AiVerdict(gameId: 'number', score: _digits - 1),
          ] else if (_show) ...[
            Text(
              tr('bench_num_memorize'),
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurface,
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 36),
              decoration: BoxDecoration(
                color: context.cardBg,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: context.hairline, width: 2),
              ),
              alignment: Alignment.center,
              child: Text(
                _number.split('').join('  '),
                style: TextStyle(
                  fontSize: 40,
                  fontWeight: FontWeight.bold,
                  color: context.inkText,
                  letterSpacing: 2,
                ),
              ),
            ),
            const SizedBox(height: 12),
            _bigButton(context, label: tr('bench_num_gotit'), onTap: _ask),
          ] else ...[
            Text(
              tr('bench_num_q'),
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurface,
                fontWeight: FontWeight.bold,
                fontSize: 18,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              tr('bench_time_memorized', {'n': _memorizeSecs ?? 0}),
              style: TextStyle(color: context.mutedText, fontSize: 13),
            ),
            const SizedBox(height: 12),
            for (final o in _options)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: GestureDetector(
                  onTap: () {
                    _pick(o);
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 14,
                    ),
                    decoration: BoxDecoration(
                      color: context.cardBg,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: context.hairline, width: 2),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      o.split('').join('  '),
                      style: TextStyle(
                        color: context.inkText,
                        fontWeight: FontWeight.bold,
                        fontSize: 22,
                        letterSpacing: 2,
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ],
      ),
    );
  }
}

const _wordPool = [
  'apple',
  'bridge',
  'cloud',
  'dog',
  'lamp',
  'forest',
  'mirror',
  'train',
  'book',
  'window',
  'mountain',
  'river',
  'shoe',
  'bird',
  'garden',
  'key',
  'moon',
  'journal',
  'chair',
  'sea',
  'clock',
  'paper',
  'leaf',
  'phone',
  'star',
  'door',
  'flower',
  'coffee',
  'bike',
  'island',
  'bed',
  'glass',
  'fire',
  'ice',
  'hill',
  'wind',
  'hat',
  'cake',
  'guitar',
  'ball',
  'owl',
  'castle',
  'honey',
  'tent',
  'sword',
  'shield',
  'moss',
  'rock',
];

const _wordPoolHu = [
  'alma',
  'híd',
  'felhő',
  'kutya',
  'lámpa',
  'erdő',
  'tükör',
  'vonat',
  'könyv',
  'ablak',
  'hegy',
  'folyó',
  'cipő',
  'madár',
  'kert',
  'kulcs',
  'hold',
  'napló',
  'szék',
  'tenger',
  'óra',
  'papír',
  'levél',
  'telefon',
  'csillag',
  'ajtó',
  'virág',
  'kávé',
  'bicikli',
  'sziget',
  'ágy',
  'pohár',
  'tűz',
  'jég',
  'domb',
  'szél',
  'kalap',
  'torta',
  'gitár',
  'labda',
  'bagoly',
  'vár',
  'méz',
  'sátor',
  'kard',
  'pajzs',
  'moha',
  'szikla',
];

class VerbalGamePage extends StatefulWidget {
  const VerbalGamePage({super.key});

  /// Fresh-word pool for [locale]: the built-in game words plus the shared
  /// concrete-noun bank, de-duplicated to single words.
  static List<String> wordPool([String locale = 'en']) {
    final base = locale == 'hu' ? _wordPoolHu : _wordPool;
    final extra = allConcreteNounsFor(locale);
    final seen = <String>{};
    final out = <String>[];
    for (final w in [...base, ...extra]) {
      final t = w.trim();
      if (t.length < 2 || t.length > 24 || t.contains(' ')) continue;
      if (seen.add(t)) out.add(t);
    }
    return out;
  }

  /// Endless local fallback for the verbal game: when the fresh pool runs
  /// out, deal a novel compound of two pool words that is guaranteed not
  /// to be in [seen], so "SEEN" can never become always-correct.
  static String freshFallback(
    List<String> pool,
    Set<String> seen, [
    Random? random,
  ]) {
    final rnd = random ?? _rnd;
    if (pool.length >= 2) {
      for (var i = 0; i < 64; i++) {
        final a = pool[rnd.nextInt(pool.length)];
        final b = pool[rnd.nextInt(pool.length)];
        if (a == b) continue;
        final w = '$a-$b';
        if (!seen.contains(w)) return w;
      }
    }
    var n = seen.length + 1;
    var w = '${pool.first}-$n';
    while (seen.contains(w)) {
      n++;
      w = '${pool.first}-$n';
    }
    return w;
  }

  static String pickFresh([String locale = 'en']) {
    final pool = wordPool(locale);
    return pool[_rnd.nextInt(pool.length)];
  }

  /// Pops the first queued AI word the player has not seen yet
  /// (case-insensitive). Returns null when the queue holds nothing new.
  static String? takeAiWord(List<String> queue, Set<String> seen) {
    final banned = {for (final s in seen) s.toLowerCase()};
    while (queue.isNotEmpty) {
      final w = queue.removeAt(0).trim();
      if (w.length < 2 || w.length > 24 || w.contains(' ')) continue;
      if (banned.contains(w.toLowerCase())) continue;
      return w;
    }
    return null;
  }

  @override
  State<VerbalGamePage> createState() => _VerbalGamePageState();
}

class _VerbalGamePageState extends State<VerbalGamePage> {
  final Set<String> _seen = {};
  late final List<String> _fresh;
  late final List<String> _pool;
  final List<String> _aiQueue = [];
  final Set<String> _liveWords = {};
  bool _fetchingAi = false;
  bool _wordLive = false;
  String _word = '';
  int _score = 0;
  int _lives = 3;
  bool _over = false;
  DateTime _startedAt = DateTime.now();
  DateTime? _endedAt;

  @override
  void initState() {
    super.initState();
    _pool = VerbalGamePage.wordPool(AppLocalizations.localeCode);
    _fresh = List.of(_pool)..shuffle();
    _next();
  }

  void _next() {
    String w;
    var live = false;
    if (_seen.isNotEmpty && _rnd.nextDouble() < 0.35) {
      w = _seen.elementAt(_rnd.nextInt(_seen.length));
      live = _liveWords.contains(w);
    } else {
      final ai = VerbalGamePage.takeAiWord(_aiQueue, _seen);
      if (ai != null) {
        _fresh.remove(ai);
        w = ai;
        live = _liveWords.remove(ai);
      } else if (_fresh.isNotEmpty) {
        w = _fresh.removeLast();
      } else {
        // The pool is exhausted: deal a guaranteed-novel compound instead
        // of recycling a seen word (which would make "SEEN" always right).
        w = VerbalGamePage.freshFallback(_pool, _seen);
      }
    }
    setState(() {
      _word = w;
      _wordLive = live;
    });
    unawaited(_prefetchWords());
  }

  /// Keeps a buffer of Spark-generated words coming so the game never
  /// runs out, even hundreds of rounds in. Offline the queue simply
  /// stays empty and the local pool plus compounds take over.
  Future<void> _prefetchWords() async {
    if (_fetchingAi || _over || _aiQueue.length >= 6) return;
    _fetchingAi = true;
    try {
      final res = await BenchmarkMeta.wordBatch(
        count: 12,
        avoid: [..._seen, ..._fresh, ..._aiQueue],
        locale: AppLocalizations.localeCode,
      );
      if (!mounted || _over) return;
      final known = {
        for (final s in [..._seen, ..._fresh, ..._aiQueue]) s.toLowerCase(),
      };
      for (final w in res.words) {
        final t = w.trim();
        if (t.length < 2 || t.length > 24 || t.contains(' ')) continue;
        if (known.add(t.toLowerCase())) {
          _aiQueue.add(t);
          if (res.live) _liveWords.add(t);
        }
      }
    } catch (_) {
    } finally {
      _fetchingAi = false;
    }
  }

  void _guess(bool saysSeen) {
    if (_over) return;
    final actuallySeen = _seen.contains(_word);
    final good = saysSeen == actuallySeen;
    if (good) {
      _score++;
      BenchmarkStore.submit('verbal', _score, higherIsBetter: true, xpGain: 6);
      _seen.add(_word);
      _next();
    } else {
      _lives--;
      if (_lives <= 0) {
        BenchmarkStore.submit(
          'verbal',
          _score,
          higherIsBetter: true,
          xpGain: 5,
        );
        setState(() {
          _over = true;
          _endedAt = DateTime.now();
        });
      } else {
        _seen.add(_word);
        _next();
      }
    }
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return _gameScaffold(
      context: context,
      title: tr('bench_game_verbal_title'),
      counter: tr('bench_verbal_counter', {'score': _score, 'lives': _lives}),
      aiModels: 'Muse Spark',
      aiLive: _wordLive,
      timerSince: _startedAt,
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
        children: [
          if (_over) ...[
            _resultBox(
              context,
              title: tr('bench_verbal_done_title', {'n': _score}),
              detail: _score >= 20
                  ? tr('bench_verbal_hi')
                  : _score >= 10
                  ? tr('bench_verbal_mid')
                  : tr('bench_verbal_lo'),
              onRetry: () => setState(() {
                _seen.clear();
                _fresh
                  ..clear()
                  ..addAll(List.of(_pool)..shuffle());
                _aiQueue.clear();
                _score = 0;
                _lives = 3;
                _over = false;
                _startedAt = DateTime.now();
                _endedAt = null;
                _next();
              }),
              retryLabel: tr('bench_verbal_retry'),
              footer: tr('bench_time_total', {
                't': _formatElapsed(
                  (_endedAt ?? DateTime.now()).difference(_startedAt),
                ),
              }),
            ),
            _TransferCard('verbal'),
            _AiTip(gameId: 'verbal', level: _score),
            _AiVerdict(gameId: 'verbal', score: _score),
          ] else ...[
            Row(
              children: [
                for (var i = 0; i < 3; i++)
                  Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: LifeHeart(filled: i < _lives),
                  ),
                const Spacer(),
                Text(
                  tr('bench_score_n', {'n': _score}),
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurface,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 48),
              decoration: BoxDecoration(
                color: context.cardBg,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: context.hairline, width: 2),
              ),
              alignment: Alignment.center,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    _word,
                    maxLines: 1,
                    style: TextStyle(
                      fontSize: 40,
                      fontWeight: FontWeight.bold,
                      color: context.inkText,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _bigButton(
                    context,
                    label: tr('bench_seen'),
                    color: teal,
                    onTap: () => _guess(true),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _bigButton(
                    context,
                    label: tr('bench_new_word'),
                    onTap: () => _guess(false),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              tr('bench_verbal_hint'),
              textAlign: TextAlign.center,
              style: TextStyle(color: context.mutedText, fontSize: 13),
            ),
          ],
        ],
      ),
    );
  }
}

/// Remaining lives as filled hearts; lost lives stay empty outlines.
/// The free HugeIcons set ships stroke icons only, so a painted fill sits
/// under the stroke icon — the outline on top guarantees the heart is
/// always visible, even if the custom paint ever fails.
class LifeHeart extends StatelessWidget {
  final bool filled;
  const LifeHeart({super.key, required this.filled});

  @override
  Widget build(BuildContext context) {
    if (!filled) {
      return HugeIcon(
        icon: HugeIcons.strokeRoundedFavourite,
        color: context.hairline,
        size: 24,
        strokeWidth: 2.2,
      );
    }
    return Stack(
      alignment: Alignment.center,
      children: [
        CustomPaint(
          painter: const _HeartFillPainter(color: coral),
          child: const SizedBox(width: 24, height: 24),
        ),
        const HugeIcon(
          icon: HugeIcons.strokeRoundedFavourite,
          color: Color(0xFFE14D4D),
          size: 24,
          strokeWidth: 2.2,
        ),
      ],
    );
  }
}

class _HeartFillPainter extends CustomPainter {
  final Color color;
  const _HeartFillPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final path = Path()
      ..moveTo(w * 0.50, h * 0.86)
      ..cubicTo(w * 0.22, h * 0.66, w * 0.12, h * 0.54, w * 0.12, h * 0.38)
      ..cubicTo(w * 0.12, h * 0.26, w * 0.22, h * 0.18, w * 0.32, h * 0.18)
      ..cubicTo(w * 0.40, h * 0.18, w * 0.47, h * 0.23, w * 0.50, h * 0.30)
      ..cubicTo(w * 0.53, h * 0.23, w * 0.60, h * 0.18, w * 0.68, h * 0.18)
      ..cubicTo(w * 0.78, h * 0.18, w * 0.88, h * 0.26, w * 0.88, h * 0.38)
      ..cubicTo(w * 0.88, h * 0.54, w * 0.78, h * 0.66, w * 0.50, h * 0.86)
      ..close();
    canvas.drawPath(path, Paint()..color = color);
  }

  @override
  bool shouldRepaint(_HeartFillPainter oldDelegate) =>
      oldDelegate.color != color;
}

class VisualGamePage extends StatefulWidget {
  /// Which procedure shows first when no saved mode exists: 'pattern'
  /// (grid) or 'mask' (SAM picture masking). A persisted choice always
  /// wins; this only picks the entry for fresh installs.
  final String initialMode;

  const VisualGamePage({super.key, this.initialMode = 'pattern'});

  static const String modePrefsKey = 'visual_mode_v1';

  static Set<int> makePattern(int size, int count) {
    final s = size.clamp(2, 25);
    final c = count.clamp(1, s - 1);
    final out = <int>{};
    while (out.length < c) {
      out.add(_rnd.nextInt(s));
    }
    return out;
  }

  @override
  State<VisualGamePage> createState() => _VisualGamePageState();
}

class _VisualGamePageState extends State<VisualGamePage> {
  int _level = 1;
  Set<int> _pattern = {};
  Set<int> _picked = {};
  bool _show = true;
  bool _over = false;
  ({Set<int> cells, int size, bool live})? _aiPattern;
  MetaTask? _aiRound;
  bool _aiLoading = false;
  int _aiDealId = 0;
  bool _roundLive = false;
  DateTime _startedAt = DateTime.now();
  DateTime? _endedAt;
  DateTime? _shownAt;
  int? _memorizeSecs;
  // Two visual procedures share this page: the pattern grid (pattern-span)
  // and SAM picture masking (picture recall with occlusion). Both are
  // visual memory, both score 'visual'.
  late String _mode;
  // Whether the pattern grid was ever dealt: mask-first entries skip the
  // (possibly live) pattern deal until the player picks the grid, so the
  // SAM demo path pays no background pattern cost.
  bool _patternDealt = false;
  // null = a maszkos kör még töltődik (ilyenkor a jelvény
  // kapcsolódást mutat, nem helyi módot).
  bool? _maskLive;

  int get _size => _level >= 4 ? 16 : 9;
  int get _cols => _level >= 4 ? 4 : 3;

  @override
  void initState() {
    super.initState();
    _mode = widget.initialMode == 'mask' ? 'mask' : 'pattern';
    if (_mode == 'pattern') {
      _patternDealt = true;
      _dealFirst();
    }
    unawaited(_restoreMode());
  }

  Future<void> _restoreMode() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final mode =
          prefs.getString(VisualGamePage.modePrefsKey) ?? widget.initialMode;
      if (!mounted) return;
      final restored = mode == 'mask' ? 'mask' : 'pattern';
      final needDeal = restored == 'pattern' && !_patternDealt;
      setState(() => _mode = restored);
      if (needDeal) {
        _patternDealt = true;
        _dealFirst();
      }
    } catch (_) {}
  }

  Future<void> _persistMode() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(VisualGamePage.modePrefsKey, _mode);
    } catch (_) {}
  }

  void _switchMode(String mode) {
    if (_mode == mode) return;
    setState(() {
      _mode = mode;
      _maskLive = null;
    });
    if (mode == 'pattern' && !_patternDealt) {
      _patternDealt = true;
      _dealFirst();
    }
    unawaited(_persistMode());
  }

  Widget _modeToggle(BuildContext context) {
    Widget chip(String mode, String label) {
      final selected = _mode == mode;
      return GestureDetector(
        onTap: () => _switchMode(mode),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: selected ? blue : Colors.transparent,
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
              color: selected ? blue : context.hairline,
              width: 2,
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              color: selected ? Colors.white : context.mutedText,
              fontWeight: FontWeight.w800,
              fontSize: 12,
            ),
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          chip('pattern', tr('bench_visual_mode_pattern')),
          chip('mask', tr('bench_visual_mode_mask')),
        ],
      ),
    );
  }

  /// First deal tries the live model for the CURRENT level, so level 1
  /// shows AI ÉLŐ when a key + cloud consent are on. Later grid deals
  /// stay instant: they consume the prefetched [_aiPattern] for speed.
  Future<void> _dealFirst() async {
    if (_level % 3 == 0) {
      _deal();
      return;
    }
    setState(() => _aiLoading = true);
    final size = _size;
    final count = (_level + 2).clamp(3, size - 1);
    try {
      final res = await BenchmarkMeta.visualPattern(size, count);
      if (!mounted || _over) return;
      if (res.cells.length == count) {
        _aiPattern = (cells: res.cells, size: size, live: res.live);
      }
    } catch (_) {}
    if (!mounted || _over) return;
    _dealGrid();
  }

  void _deal() {
    if (_level % 3 == 0) {
      _dealAiRound();
    } else {
      _dealGrid();
    }
  }

  void _dealGrid() {
    final count = (_level + 2).clamp(3, _size - 1);
    final ai = _aiPattern;
    if (ai != null && ai.size == _size && ai.cells.length == count) {
      _pattern = Set.of(ai.cells);
      _roundLive = ai.live;
    } else {
      _pattern = {};
      while (_pattern.length < count) {
        _pattern.add(_rnd.nextInt(_size));
      }
      _roundLive = false;
    }
    _aiPattern = null;
    _aiRound = null;
    _aiLoading = false;
    _picked = {};
    _show = true;
    _shownAt = DateTime.now();
    _memorizeSecs = null;
    setState(() {});
    unawaited(_prefetchPattern());
  }

  /// The grid and the picture only ever hide through the got-it button.
  /// No timer flips the phase; the self-paced memorize time is measured.
  void _ask() {
    final shown = _shownAt;
    setState(() {
      _memorizeSecs = shown == null
          ? 0
          : DateTime.now().difference(shown).inSeconds.clamp(0, 5999);
      _show = false;
    });
  }

  Future<void> _dealAiRound() async {
    final id = ++_aiDealId;
    setState(() {
      _aiLoading = true;
      _aiRound = null;
      _picked = {};
      _show = true;
    });
    final locale = AppLocalizations.localeCode;
    MetaTask task;
    try {
      task = await BenchmarkMeta.pictureRound(
        seed: 'bench:visual:$_level:${DateTime.now().millisecondsSinceEpoch}',
        difficulty: (_level ~/ 3).clamp(1, 5),
        locale: locale,
      );
    } catch (_) {
      task = localPictureTask(
        difficulty: 1,
        seed: 'bench:visual:$_level',
        locale: locale,
      );
    }
    if (!mounted || id != _aiDealId || _over) return;
    if (task.imageUrl.isEmpty) {
      _dealGrid();
      return;
    }
    setState(() {
      _aiRound = task;
      _aiLoading = false;
      _show = true;
      _shownAt = DateTime.now();
      _memorizeSecs = null;
      // A picture round is live when any model contributed: Spark filled
      // the scene (!fallback) or Image painted it (only live calls yield
      // a URL — offline rounds never carry one).
      _roundLive = !task.fallback || task.imageUrl.isNotEmpty;
    });
  }

  Future<void> _prefetchPattern() async {
    var next = _level + 1;
    if (next % 3 == 0) next++;
    final size = next >= 4 ? 16 : 9;
    final count = (next + 2).clamp(3, size - 1);
    try {
      final res = await BenchmarkMeta.visualPattern(size, count);
      if (mounted && !_over && res.cells.length == count) {
        _aiPattern = (cells: res.cells, size: size, live: res.live);
      }
    } catch (_) {}
  }

  void _check() {
    if (_show || _over) return;
    if (_picked.length == _pattern.length && _picked.every(_pattern.contains)) {
      BenchmarkStore.submit(
        'visual',
        _level,
        higherIsBetter: true,
        xpGain: 8 + _level * 3,
      );
      setState(() {
        _level++;
        _deal();
      });
    } else {
      BenchmarkStore.submit(
        'visual',
        _level - 1,
        higherIsBetter: true,
        xpGain: 5,
      );
      setState(() {
        _over = true;
        _endedAt = DateTime.now();
      });
    }
  }

  void _checkAi(String v) {
    final task = _aiRound;
    if (_show || _over || task == null) return;
    final answer = task.correct >= 0 && task.correct < task.options.length
        ? task.options[task.correct]
        : '';
    if (v == answer) {
      BenchmarkStore.submit(
        'visual',
        _level,
        higherIsBetter: true,
        xpGain: 8 + _level * 3,
      );
      setState(() {
        _level++;
        _deal();
      });
    } else {
      BenchmarkStore.submit(
        'visual',
        _level - 1,
        higherIsBetter: true,
        xpGain: 5,
      );
      setState(() {
        _over = true;
        _endedAt = DateTime.now();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final ai = _aiRound;
    final mask = _mode == 'mask';
    return _gameScaffold(
      context: context,
      title: tr('bench_game_visual_title'),
      counter: mask ? '' : tr('bench_level_n', {'n': _level}),
      timerSince: _startedAt,
      aiModels: mask
          ? 'Muse Image • SAM 3.1 • Muse Spark'
          : 'Muse Spark • Muse Image • SAM 3.1',
      aiLive: mask ? (_maskLive ?? false) : _roundLive,
      aiLoading: mask && _maskLive == null,
      body: mask
          ? SamMaskGameBody(
              toggle: _modeToggle(context),
              onLive: (live) => setState(() => _maskLive = live),
            )
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
              children: [
                _modeToggle(context),
                if (_over) ...[
                  _resultBox(
                    context,
                    title: tr('bench_visual_done_title', {'n': _level - 1}),
                    detail: tr('bench_visual_done_detail'),
                    onRetry: () => setState(() {
                      _level = 1;
                      _over = false;
                      _aiRound = null;
                      _aiLoading = false;
                      _aiDealId++;
                      _startedAt = DateTime.now();
                      _endedAt = null;
                      _deal();
                    }),
                    retryLabel: tr('bench_restart'),
                    footer: tr('bench_time_total', {
                      't': _formatElapsed(
                        (_endedAt ?? DateTime.now()).difference(_startedAt),
                      ),
                    }),
                  ),
                  _TransferCard('visual'),
                  _AiTip(gameId: 'visual', level: _level - 1),
                  _AiVerdict(gameId: 'visual', score: _level - 1),
                ] else if (_aiLoading) ...[
                  const SizedBox(height: 40),
                  AppLoader(
                    caption: _level % 3 == 0
                        ? tr('ai_picture_loading')
                        : tr('common_loading'),
                  ),
                ] else if (ai != null) ...[
                  if (_show) ...[
                    Text(
                      ai.prompt,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurface,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 12),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: AiImage(
                        imageRef: ai.imageUrl,
                        height: 200,
                        width: double.infinity,
                        cacheWidth: 800,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      alignment: WrapAlignment.center,
                      children: [
                        for (final item in ai.items)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: context.washBg,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: context.washBorder),
                            ),
                            child: Text(
                              item,
                              style: TextStyle(
                                color: context.inkText,
                                fontWeight: FontWeight.w600,
                                fontSize: 14,
                              ),
                            ),
                          ),
                      ],
                    ),
                    if (ai.stations.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Text(
                        tr('ai_picture_sam', {'n': ai.stations.length}),
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: context.mutedText,
                          fontSize: 12,
                        ),
                      ),
                    ],
                    if (ai.explanation.trim().isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Text(
                        '${ai.explanation.trim()}\n${ai.paradigm} (${ai.source})',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: context.mutedText,
                          fontSize: 12,
                          height: 1.5,
                        ),
                      ),
                    ],
                    const SizedBox(height: 12),
                    _bigButton(
                      context,
                      label: tr('bench_spatial_gotit'),
                      color: coral,
                      onTap: _ask,
                    ),
                  ] else ...[
                    Text(
                      ai.question,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurface,
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      tr('bench_time_memorized', {'n': _memorizeSecs ?? 0}),
                      style: TextStyle(color: context.mutedText, fontSize: 13),
                    ),
                    const SizedBox(height: 12),
                    for (final o in ai.options)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: GestureDetector(
                          onTap: () => _checkAi(o),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 14,
                            ),
                            decoration: BoxDecoration(
                              color: context.cardBg,
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color: context.hairline,
                                width: 2,
                              ),
                            ),
                            alignment: Alignment.center,
                            child: Text(
                              o,
                              style: TextStyle(
                                color: context.inkText,
                                fontWeight: FontWeight.bold,
                                fontSize: 18,
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                ] else ...[
                  _FixedInstruction(
                    _show
                        ? tr('bench_visual_memorize')
                        : tr('bench_visual_tap'),
                  ),
                  const SizedBox(height: 12),
                  GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: _cols,
                      mainAxisSpacing: 10,
                      crossAxisSpacing: 10,
                    ),
                    itemCount: _size,
                    itemBuilder: (_, i) {
                      final on = _show
                          ? _pattern.contains(i)
                          : _picked.contains(i);
                      return GestureDetector(
                        onTap: _show
                            ? null
                            : () {
                                setState(() {
                                  if (_picked.contains(i)) {
                                    _picked.remove(i);
                                  } else {
                                    _picked.add(i);
                                  }
                                });
                              },
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 150),
                          decoration: BoxDecoration(
                            color: on ? blue : context.cardBg,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: on ? blue : context.hairline,
                              width: 2,
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 12),
                  if (!_show) ...[
                    Text(
                      tr('bench_time_memorized', {'n': _memorizeSecs ?? 0}),
                      textAlign: TextAlign.center,
                      style: TextStyle(color: context.mutedText, fontSize: 13),
                    ),
                    const SizedBox(height: 8),
                  ],
                  _bigButton(
                    context,
                    label: _show
                        ? tr('bench_spatial_gotit')
                        : tr('bench_check'),
                    color: _show ? coral : blue,
                    onTap: _show ? _ask : _check,
                  ),
                ],
              ],
            ),
    );
  }
}

class NumberOrderGamePage extends StatefulWidget {
  const NumberOrderGamePage({super.key});

  @override
  State<NumberOrderGamePage> createState() => _NumberOrderGamePageState();
}

class _NumberOrderGamePageState extends State<NumberOrderGamePage> {
  int _count = 3;
  List<int> _cells = [];
  int _next = 1;
  bool _hidden = false;
  bool _over = false;
  int? _aiSeed;
  bool _aiSeedLive = false;
  bool _roundLive = false;
  DateTime _startedAt = DateTime.now();
  DateTime? _endedAt;

  @override
  void initState() {
    super.initState();
    _deal();
  }

  void _deal() {
    final seed = _aiSeedLive ? _aiSeed : null;
    _aiSeed = null;
    _aiSeedLive = false;
    _roundLive = seed != null;
    final rnd = seed == null ? _rnd : Random(seed);
    final all = List.generate(12, (i) => i)..shuffle(rnd);
    _cells = all.take(_count).toList();
    _next = 1;
    _hidden = false;
    _over = false;
    setState(() {});
    unawaited(_prefetchLayout());
  }

  /// Lets Muse Spark deal the next layout: its digits fold into the
  /// shuffle seed. Offline the seed stays null and the local shuffle
  /// takes over.
  Future<void> _prefetchLayout() async {
    try {
      final res = await BenchmarkMeta.sequenceStimulus(4);
      if (mounted && !_over && res.digits.isNotEmpty) {
        _aiSeed = BenchmarkMeta.seedFromDigits(res.digits);
        _aiSeedLive = res.live;
      }
    } catch (_) {}
  }

  void _tapCell(int cellIndex) {
    if (_over) return;
    final value = _cells.indexOf(cellIndex) + 1;
    if (value <= 0) return;
    if (value == _next) {
      if (_next == 1) setState(() => _hidden = true);
      _next++;
      if (_next > _count) {
        BenchmarkStore.submit(
          'order',
          _count,
          higherIsBetter: true,
          xpGain: 8 + _count * 3,
        );
        setState(() {
          _count++;
          _deal();
        });
      } else {
        setState(() {});
      }
    } else {
      BenchmarkStore.submit(
        'order',
        _count - 1,
        higherIsBetter: true,
        xpGain: 5,
      );
      setState(() {
        _over = true;
        _endedAt = DateTime.now();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return _gameScaffold(
      context: context,
      title: tr('bench_game_order_title'),
      counter: tr('bench_order_counter', {'n': _count, 'next': _next}),
      aiModels: 'Muse Spark',
      aiLive: _roundLive,
      timerSince: _startedAt,
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
        children: [
          if (_over) ...[
            _resultBox(
              context,
              title: tr('bench_order_done_title', {'n': _count - 1}),
              detail: _count >= 7 ? tr('bench_order_hi') : tr('bench_order_lo'),
              onRetry: () => setState(() {
                _count = 3;
                _startedAt = DateTime.now();
                _endedAt = null;
                _deal();
              }),
              retryLabel: tr('bench_order_retry'),
              footer: tr('bench_time_total', {
                't': _formatElapsed(
                  (_endedAt ?? DateTime.now()).difference(_startedAt),
                ),
              }),
            ),
            _TransferCard('order'),
            _AiTip(gameId: 'order', level: _count - 1),
            _AiVerdict(gameId: 'order', score: _count - 1),
          ] else ...[
            Text(
              tr('bench_order_how'),
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurface,
                fontWeight: FontWeight.bold,
                fontSize: 15,
              ),
            ),
            const SizedBox(height: 12),
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                mainAxisSpacing: 10,
                crossAxisSpacing: 10,
              ),
              itemCount: 12,
              itemBuilder: (_, i) {
                final value = _cells.indexOf(i) + 1;
                final filled = value > 0;
                final done = value > 0 && value < _next;
                return GestureDetector(
                  onTap: () {
                    _tapCell(i);
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    decoration: BoxDecoration(
                      color: !filled
                          ? context.cardBg
                          : done
                          ? context.hairline
                          : blue,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: filled ? blue : context.hairline,
                        width: 2,
                      ),
                    ),
                    alignment: Alignment.center,
                    child: !filled || done
                        ? const SizedBox.shrink()
                        : _hidden
                        ? Container(
                            width: 18,
                            height: 18,
                            decoration: BoxDecoration(
                              color: context.cardBg,
                              shape: BoxShape.circle,
                            ),
                          )
                        : Text(
                            '$value',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 26,
                            ),
                          ),
                  ),
                );
              },
            ),
            const SizedBox(height: 8),
            Text(
              tr('bench_order_tip'),
              textAlign: TextAlign.center,
              style: TextStyle(color: context.mutedText, fontSize: 13),
            ),
          ],
        ],
      ),
    );
  }
}

class SpatialGamePage extends StatefulWidget {
  const SpatialGamePage({super.key});

  static const int minStations = 3;
  static const int maxStations = 10;

  /// SharedPreferences key for the player's own palace name.
  static const String palacePrefsKey = 'spatial_palace_name_v1';

  /// SharedPreferences key for the player's own ordered stations.
  static const String stationsPrefsKey = 'spatial_stations_v1';

  /// Sample route prefilling the setup editor: the player edits these
  /// into their own stations, so the app never has to guess anyone's
  /// home layout.
  static List<String> defaultStations([String locale = 'en']) =>
      List<String>.of(palaceRoutesFor(locale).values.first.take(maxStations));

  /// Cleans the player-typed stations into exactly [maxStations] stops:
  /// trims, fills blanks from the sample route at the same slot, and
  /// de-duplicates so every station name stays addressable.
  static List<String> sanitizeStations(
    List<String> raw, [
    String locale = 'en',
  ]) {
    final sample = defaultStations(locale);
    final out = <String>[];
    for (var i = 0; i < maxStations; i++) {
      var name = i < raw.length ? raw[i].trim() : '';
      if (name.isEmpty) name = sample[i % sample.length];
      var unique = name;
      var n = 2;
      while (out.contains(unique)) {
        unique = '$name $n';
        n++;
      }
      out.add(unique);
    }
    return out;
  }

  static List<String> routeNames([String locale = 'en']) =>
      palaceRoutesFor(locale).keys.toList();

  static List<String> pickStations(
    int count, {
    int? routeIndex,
    String locale = 'en',
  }) {
    final routes = palaceRoutesFor(locale).values.toList();
    final route =
        routes[(routeIndex ?? _rnd.nextInt(routes.length)) % routes.length];
    return route.take(count.clamp(minStations, maxStations)).toList();
  }

  /// Offline Wonder preview: one local caption per station, in walking
  /// order. The live Wonder viewpoints replace these when available.
  static List<String> localWonderPreview(
    List<String> stations, [
    String locale = 'en',
  ]) => [
    for (final s in stations)
      trFor(locale, 'wonder_fallback_view', {'station': s}),
  ];

  static List<String> pickWords(
    int count, [
    Random? random,
    String locale = 'en',
  ]) {
    final rnd = random ?? _rnd;
    final pool = List<String>.of(allConcreteNounsFor(locale))..shuffle(rnd);
    return pool.take(count.clamp(minStations, maxStations)).toList();
  }

  static List<String> makeOptions(
    String correct,
    List<String> exclude, [
    Random? random,
    String locale = 'en',
  ]) {
    final rnd = random ?? _rnd;
    final pool = List<String>.of(allConcreteNounsFor(locale))..shuffle(rnd);
    final options = <String>[correct];
    for (final w in pool) {
      if (options.length >= 4) break;
      if (w == correct || exclude.contains(w)) continue;
      options.add(w);
    }
    options.shuffle(rnd);
    return options;
  }

  @override
  State<SpatialGamePage> createState() => _SpatialGamePageState();
}

class _SpatialGamePageState extends State<SpatialGamePage> {
  String? _palace;
  List<String>? _stations;
  // null = a sétakör még töltődik (ilyenkor a jelvény
  // kapcsolódást mutat, nem helyi módot).
  bool? _walkLive;
  int _level = SpatialGamePage.minStations;
  final _palaceCtrl = TextEditingController();
  final List<TextEditingController> _stationCtrls = [];

  @override
  void initState() {
    super.initState();
    for (final s in SpatialGamePage.defaultStations(
      AppLocalizations.localeCode,
    )) {
      _stationCtrls.add(TextEditingController(text: s));
    }
    unawaited(_restore());
  }

  @override
  void dispose() {
    _palaceCtrl.dispose();
    for (final c in _stationCtrls) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _restore() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved =
          prefs.getString(SpatialGamePage.palacePrefsKey)?.trim() ?? '';
      final stations =
          prefs.getStringList(SpatialGamePage.stationsPrefsKey) ??
          const <String>[];
      if (!mounted) return;
      setState(() {
        // A saved palace without its own stations (old installs) goes
        // through setup once, so the walk never runs on guessed stops.
        if (saved.isNotEmpty &&
            stations.length >= SpatialGamePage.minStations) {
          _palace = saved;
          _stations = List<String>.of(stations);
          _palaceCtrl.text = saved;
          for (
            var i = 0;
            i < _stationCtrls.length && i < stations.length;
            i++
          ) {
            _stationCtrls[i].text = stations[i];
          }
        }
      });
    } catch (_) {}
  }

  Future<void> _start() async {
    final name = _palaceCtrl.text.trim();
    if (name.isEmpty) return;
    final stations = SpatialGamePage.sanitizeStations([
      for (final c in _stationCtrls) c.text,
    ], AppLocalizations.localeCode);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(SpatialGamePage.palacePrefsKey, name);
      await prefs.setStringList(SpatialGamePage.stationsPrefsKey, stations);
    } catch (_) {}
    if (!mounted) return;
    setState(() {
      _palace = name;
      _stations = stations;
    });
  }

  void _changePalace() {
    // Back to setup with the current values kept in the fields, so the
    // player edits their route instead of retyping it.
    setState(() {
      _palace = null;
      _stations = null;
    });
  }

  Widget _setupBody(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
      children: [
        Text(
          tr('bench_spatial_setup_title'),
          style: TextStyle(
            color: Theme.of(context).colorScheme.onSurface,
            fontWeight: FontWeight.bold,
            fontSize: 20,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          tr('bench_spatial_setup_body'),
          style: TextStyle(color: context.mutedText, fontSize: 14, height: 1.5),
        ),
        const SizedBox(height: 12),
        AppTextField(
          controller: _palaceCtrl,
          textCapitalization: TextCapitalization.sentences,
          onSubmitted: (_) => _start(),
          hint: tr('bench_spatial_setup_hint'),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          children: [
            for (final key in const [
              'bench_spatial_chip_home',
              'bench_spatial_chip_work',
              'bench_spatial_chip_school',
            ])
              AppChip(
                label: tr(key),
                onTap: () => setState(() => _palaceCtrl.text = tr(key)),
              ),
          ],
        ),
        const SizedBox(height: 16),
        Text(
          tr('bench_spatial_stations_title'),
          style: TextStyle(
            color: Theme.of(context).colorScheme.onSurface,
            fontWeight: FontWeight.bold,
            fontSize: 15,
          ),
        ),
        const SizedBox(height: 8),
        for (var i = 0; i < _stationCtrls.length; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: AppTextField(
              controller: _stationCtrls[i],
              textCapitalization: TextCapitalization.sentences,
              hint: tr('bench_spatial_station_hint', {'n': i + 1}),
              prefix: Text(
                '${i + 1}. ',
                style: TextStyle(color: context.inkText, fontSize: 16),
              ),
            ),
          ),
        const SizedBox(height: 8),
        _bigButton(
          context,
          label: tr('bench_spatial_setup_start'),
          color: context.accentText(coral),
          onTap: _start,
        ),
      ],
    );
  }

  Widget _palaceLink(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Align(
        alignment: Alignment.centerLeft,
        child: GestureDetector(
          onTap: _changePalace,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Text(
              tr('bench_spatial_change'),
              style: TextStyle(
                color: context.mutedText,
                fontSize: 12,
                decoration: TextDecoration.underline,
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final setup = _palace == null || _stations == null;
    return _gameScaffold(
      context: context,
      title: tr('bench_game_spatial_title'),
      counter: setup ? '' : tr('bench_stations_n', {'n': _level}),
      aiModels: setup ? '' : 'Muse Spark',
      aiLive: !setup && (_walkLive ?? false),
      aiLoading: !setup && _walkLive == null,
      body: setup
          ? _setupBody(context)
          : _PalaceWalkGame(
              palace: _palace!,
              stations: _stations!,
              topLink: _palaceLink(context),
              onLevel: (level) => setState(() => _level = level),
              onLive: (live) => setState(() => _walkLive = live),
            ),
    );
  }
}

/// The measured spatial game: a true method-of-loci walk. Ordered
/// stations, one concrete word per station, cued recall ("what did you
/// place here?") — the loci-drill paradigm (Maguire et al. 2003;
/// Dresler et al. 2017). Scores 'spatial'.
class _PalaceWalkGame extends StatefulWidget {
  final String palace;
  final List<String> stations;
  final Widget topLink;
  final ValueChanged<int> onLevel;
  final ValueChanged<bool?>? onLive;
  const _PalaceWalkGame({
    required this.palace,
    required this.stations,
    required this.topLink,
    required this.onLevel,
    this.onLive,
  });

  @override
  State<_PalaceWalkGame> createState() => _PalaceWalkGameState();
}

class _PalaceWalkGameState extends State<_PalaceWalkGame> {
  int _count = SpatialGamePage.minStations;
  MetaTask? _task;
  bool _show = true;
  bool _over = false;
  bool _loading = true;
  int _dealId = 0;
  DateTime _startedAt = DateTime.now();
  DateTime? _endedAt;
  DateTime? _shownAt;
  int? _memorizeSecs;

  @override
  void initState() {
    super.initState();
    unawaited(_deal());
  }

  Future<void> _deal() async {
    final id = ++_dealId;
    if (_task != null) widget.onLive?.call(null);
    setState(() {
      _loading = true;
      _show = true;
    });
    final locale = AppLocalizations.localeCode;
    MetaTask task;
    try {
      task = await BenchmarkMeta.spatialRound(
        seed: 'bench:spatial:$_count:${DateTime.now().millisecondsSinceEpoch}',
        stations: _count,
        locale: locale,
      );
    } catch (_) {
      task = localPalaceTask(
        difficulty: 1,
        seed: 'bench:spatial:$_count',
        locale: locale,
        count: _count,
      );
    }
    // The walk runs on the player's OWN stations: whatever the round
    // source dealt (AI or the local sample route), the station names and
    // the question are re-pointed at the saved route, so the app never
    // pretends to know the player's home layout.
    final own = widget.stations.take(_count).toList();
    var target = 0;
    for (var i = 0; i < task.stations.length; i++) {
      if (task.question.contains(task.stations[i])) {
        target = i;
        break;
      }
    }
    target = target.clamp(0, own.length - 1);
    task = task.copyWith(
      stations: own,
      question: tr('bench_spatial_q', {'station': own[target]}),
    );
    if (!mounted || id != _dealId) return;
    setState(() {
      _task = task;
      _loading = false;
      _show = true;
      _shownAt = DateTime.now();
      _memorizeSecs = null;
    });
    widget.onLive?.call(!task.fallback);
  }

  /// The walk only ever hides through the got-it button — the player
  /// studies their own palace at their own pace, and the memorize time
  /// is measured instead of forced.
  void _ask() {
    final shown = _shownAt;
    setState(() {
      _memorizeSecs = shown == null
          ? 0
          : DateTime.now().difference(shown).inSeconds.clamp(0, 5999);
      _show = false;
    });
  }

  void _pick(String v) {
    final task = _task;
    if (_show || _over || task == null) return;
    final answer = task.correct >= 0 && task.correct < task.options.length
        ? task.options[task.correct]
        : '';
    if (v == answer) {
      BenchmarkStore.submit(
        'spatial',
        _count,
        higherIsBetter: true,
        xpGain: 8 + _count * 3,
      );
      if (_count < SpatialGamePage.maxStations) _count++;
      widget.onLevel(_count);
      unawaited(_deal());
    } else {
      BenchmarkStore.submit(
        'spatial',
        _count - 1,
        higherIsBetter: true,
        xpGain: 5,
      );
      setState(() {
        _over = true;
        _endedAt = DateTime.now();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final task = _task;
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
      children: [
        widget.topLink,
        if (_over) ...[
          _resultBox(
            context,
            title: tr('bench_spatial_done_title', {'n': _count - 1}),
            detail: tr('bench_spatial_done_detail'),
            onRetry: () {
              _count = SpatialGamePage.minStations;
              widget.onLevel(_count);
              setState(() {
                _over = false;
                _startedAt = DateTime.now();
                _endedAt = null;
              });
              unawaited(_deal());
            },
            retryLabel: tr('bench_restart'),
            footer: tr('bench_time_total', {
              't': _formatElapsed(
                (_endedAt ?? DateTime.now()).difference(_startedAt),
              ),
            }),
          ),
          _TransferCard('spatial'),
          _AiTip(gameId: 'spatial', level: _count - 1),
          _AiVerdict(gameId: 'spatial', score: _count - 1),
        ] else if (_loading || task == null) ...[
          const SizedBox(height: 40),
          AppLoader(caption: tr('common_loading')),
        ] else if (_show) ...[
          Text(
            tr('bench_spatial_palace_line', {'palace': widget.palace}),
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurface,
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            tr('bench_spatial_walk_how'),
            style: TextStyle(color: context.mutedText, fontSize: 13),
          ),
          const SizedBox(height: 8),
          Center(child: _LiveTimerChip(since: _startedAt)),
          const SizedBox(height: 12),
          for (var i = 0; i < task.stations.length; i++)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: context.cardBg,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: context.hairline, width: 2),
                ),
                child: Text(
                  i < task.items.length
                      ? '${i + 1}. ${task.stations[i]} → ${task.items[i]}'
                      : '${i + 1}. ${task.stations[i]}',
                  style: TextStyle(
                    color: context.inkText,
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                  ),
                ),
              ),
            ),
          if (task.explanation.trim().isNotEmpty) ...[
            Text(
              task.explanation.trim(),
              textAlign: TextAlign.center,
              style: TextStyle(
                color: context.mutedText,
                fontSize: 12,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 8),
          ],
          _bigButton(
            context,
            label: tr('bench_spatial_gotit'),
            color: coral,
            onTap: _ask,
          ),
        ] else ...[
          Text(
            task.question,
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurface,
              fontWeight: FontWeight.bold,
              fontSize: 18,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            tr('bench_time_memorized', {'n': _memorizeSecs ?? 0}),
            style: TextStyle(color: context.mutedText, fontSize: 13),
          ),
          const SizedBox(height: 4),
          Align(
            alignment: Alignment.centerLeft,
            child: _LiveTimerChip(since: _startedAt),
          ),
          const SizedBox(height: 12),
          for (final o in task.options)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: GestureDetector(
                onTap: () => _pick(o),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 14,
                  ),
                  decoration: BoxDecoration(
                    color: context.cardBg,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: context.hairline, width: 2),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    o,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: context.inkText,
                      fontWeight: FontWeight.bold,
                      fontSize: 20,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ],
    );
  }
}

/// Standalone SAM mask game page: SAM 3.1 + Muse Spark read the objects
/// off a picture together, SAM covers each in its own shape, and the
/// player names the object under each cover in walk order — every
/// correct answer reveals its object.
class SamMaskGamePage extends StatefulWidget {
  final int count;
  final String seed;
  const SamMaskGamePage({super.key, this.count = 3, this.seed = 'mask'});

  @override
  State<SamMaskGamePage> createState() => _SamMaskGamePageState();
}

class _SamMaskGamePageState extends State<SamMaskGamePage> {
  bool? _live;

  @override
  Widget build(BuildContext context) {
    return _gameScaffold(
      context: context,
      title: tr('bench_game_visual_title'),
      counter: '',
      aiModels: 'Muse Image • SAM 3.1 • Muse Spark',
      aiLive: _live ?? false,
      aiLoading: _live == null,
      body: SamMaskGameBody(
        initialCount: widget.count,
        seedPrefix: widget.seed,
        onLive: (live) => setState(() => _live = live),
      ),
    );
  }
}

/// The mask-game content, shared by the standalone page and the visual
/// hub. Never errors: offline (or on any AI failure) it plays a local
/// scene with built-in items and says so on one quiet line.
class SamMaskGameBody extends StatefulWidget {
  final int initialCount;
  final String seedPrefix;
  final Widget? toggle;
  // null = új kör töltődik (a jelvény ilyenkor kapcsolódást mutat).
  final ValueChanged<bool?>? onLive;
  const SamMaskGameBody({
    super.key,
    this.initialCount = 3,
    this.seedPrefix = 'mask',
    this.toggle,
    this.onLive,
  });

  @override
  State<SamMaskGameBody> createState() => SamMaskGameBodyState();
}

class SamMaskGameBodyState extends State<SamMaskGameBody> {
  late int _count;
  PictureRecallRound? _round;
  bool _masked = false;
  final _revealed = <int>{};
  final _guessCtrl = TextEditingController();
  String _feedback = '';
  bool _feedbackGood = false;
  bool _loading = true;
  bool _imageFailed = false;
  double _progress = 0;
  String _stage = 'image';
  int _token = 0;
  // Bumps on every freshly loaded round so the cover painter repaints
  // even when the new round has the same object count as the last one.
  int _coverVersion = 0;

  /// True only when the player actually sees a picture. Without one
  /// (offline, or a failed download/decode) the round falls back to
  /// word recall: the words are shown for memorizing, and no black
  /// tiles ever cover the placeholder.
  bool get _hasPicture {
    final round = _round;
    return round != null && round.imageUrl.isNotEmpty && !_imageFailed;
  }

  @override
  void initState() {
    super.initState();
    _count = widget.initialCount.clamp(2, 8);
    unawaited(_load());
  }

  @override
  void dispose() {
    _guessCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final token = ++_token;
    // Újratöltéskor (volt már kör) a szülő jelvénye is kapcsolódásra
    // vált; az első töltéskor a szülő amúgy is töltést mutat.
    if (_round != null) widget.onLive?.call(null);
    setState(() {
      _loading = true;
      _masked = false;
      _revealed.clear();
      _feedback = '';
      _imageFailed = false;
      _progress = 0;
      _stage = 'image';
    });
    final round = await MetaAIService.pictureRecallRound(
      seed:
          '${widget.seedPrefix}:$_count:${DateTime.now().millisecondsSinceEpoch}',
      count: _count,
      locale: AppLocalizations.localeCode,
      onProgress: (p, stage) {
        if (!mounted || token != _token) return;
        setState(() {
          _progress = p;
          _stage = stage;
        });
      },
    );
    if (!mounted || token != _token) return;
    setState(() {
      _round = round;
      _loading = false;
      _coverVersion++;
    });
    widget.onLive?.call(round.live);
  }

  /// The cover under question: the first still-hidden object in walk
  /// order, or -1 before masking / after everything is revealed.
  int get _cue {
    final round = _round;
    if (round == null || !_masked) return -1;
    for (var i = 0; i < round.objects.length; i++) {
      if (!_revealed.contains(i)) return i;
    }
    return -1;
  }

  void _reveal(int hit) {
    final round = _round;
    if (round == null) return;
    setState(() {
      _revealed.add(hit);
      _feedback = tr('bench_mask_correct', {'word': round.objects[hit]});
      _feedbackGood = true;
    });
    _guessCtrl.clear();
    if (_revealed.length >= round.objects.length) {
      // Picture masking is visual memory (picture recall with occlusion),
      // never spatial: it scores 'visual' alongside the pattern grid.
      BenchmarkStore.submit(
        'visual',
        round.objects.length,
        higherIsBetter: true,
        xpGain: 8 + round.objects.length * 3,
      );
    }
  }

  void _guess() {
    final round = _round;
    if (round == null || !_masked) return;
    // Word fallback (no picture): free recall in any order.
    if (!_hasPicture) {
      final hit = matchRecallAnswer(_guessCtrl.text, round.objects, _revealed);
      if (hit < 0) {
        setState(() {
          _feedback = tr('bench_mask_wrong_words');
          _feedbackGood = false;
        });
        return;
      }
      _reveal(hit);
      return;
    }
    // Picture mode: location-cued recall — each question asks the object
    // under ONE cover (the loci station cues its item), in walk order.
    final cue = _cue;
    if (cue < 0) return;
    final onlyCue = <int>{
      for (var i = 0; i < round.objects.length; i++)
        if (i != cue) i,
    };
    final hit = matchRecallAnswer(_guessCtrl.text, round.objects, onlyCue);
    if (hit == cue) {
      _reveal(hit);
      return;
    }
    final elsewhere = matchRecallAnswer(
      _guessCtrl.text,
      round.objects,
      _revealed,
    );
    setState(() {
      _feedback = elsewhere >= 0
          ? tr('bench_mask_wrong_cover', {'n': cue + 1})
          : tr('bench_mask_wrong');
      _feedbackGood = false;
    });
  }

  Widget _picture({required bool masked}) {
    final round = _round;
    if (round == null) return const SizedBox.shrink();
    final aligned = round.boxes.length == round.objects.length;
    return MaskedPicture(
      imageUrl: round.imageUrl,
      scene: round.scene,
      objects: round.objects,
      boxes: aligned ? round.boxes : const <List<double>>[],
      masks: round.masks.length == round.objects.length
          ? round.masks
          : const <String>[],
      revealed: _revealed,
      masked: masked && _hasPicture,
      cue: _cue,
      version: _coverVersion,
      showWalk: !masked && _hasPicture && aligned,
      onImageError: () {
        if (!_imageFailed && mounted) {
          setState(() => _imageFailed = true);
        }
      },
    );
  }

  /// Object-count stepper (2–8) on the memorize phase: the demo can
  /// start easy and crank up live. Hidden once masked so the count text
  /// never collides with the numbered covers.
  Widget _countStepper() {
    Widget stepBtn(String label, VoidCallback? onTap) {
      final enabled = onTap != null;
      return GestureDetector(
        onTap: enabled
            ? () {
                AppFeedback.light();
                onTap.call();
              }
            : null,
        child: Container(
          width: 40,
          height: 40,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: enabled ? context.cardBg : Colors.transparent,
            shape: BoxShape.circle,
            border: Border.all(
              color: enabled ? context.hairline : context.washBorder,
              width: 2,
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              color: enabled ? context.inkText : context.mutedText,
              fontWeight: FontWeight.w800,
              fontSize: 20,
            ),
          ),
        ),
      );
    }

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        stepBtn(
          '−',
          _count > 2
              ? () {
                  _count--;
                  unawaited(_load());
                }
              : null,
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14),
          child: Text(
            tr('bench_mask_count', {'n': _count}),
            style: TextStyle(
              color: context.inkText,
              fontWeight: FontWeight.w800,
              fontSize: 16,
            ),
          ),
        ),
        stepBtn(
          '+',
          _count < 8
              ? () {
                  _count++;
                  unawaited(_load());
                }
              : null,
        ),
      ],
    );
  }

  Widget _wordChips(List<String> words) {
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      alignment: WrapAlignment.center,
      children: [
        for (final w in words)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: context.washBg,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: context.washBorder),
            ),
            child: Text(
              w,
              style: TextStyle(
                color: context.inkText,
                fontWeight: FontWeight.w600,
                fontSize: 14,
              ),
            ),
          ),
      ],
    );
  }

  String _maskStageLabel(String stage) => switch (stage) {
    'image' => tr('bench_mask_stage_image'),
    'read' => tr('bench_mask_stage_read'),
    'sam' => tr('bench_mask_stage_sam'),
    _ => tr('bench_mask_stage_done'),
  };

  @override
  Widget build(BuildContext context) {
    final round = _round;
    final done =
        round != null && _revealed.length >= round.objects.length && _masked;
    // Plain scroll + column (no lazy list): the square picture is
    // tall, and the memorize button / guess row right below it must
    // always exist for taps and tests, even below the fold.
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (widget.toggle != null) widget.toggle!,
          Text(
            round != null && !_hasPicture
                ? tr('bench_mask_memorize_words')
                : tr('bench_mask_memorize'),
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurface,
              fontWeight: FontWeight.bold,
              fontSize: 15,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            round == null ? '' : tr('bench_mask_scene', {'scene': round.scene}),
            style: TextStyle(color: context.mutedText, fontSize: 13),
          ),
          const SizedBox(height: 12),
          if (_loading || round == null)
            SizedBox(
              height: 220,
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(
                      width: 220,
                      child: AppProgressBar(
                        value: _progress <= 0 ? null : _progress,
                        height: 10,
                        color: teal,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '${(_progress * 100).round()}%',
                      style: TextStyle(
                        color: context.inkText,
                        fontWeight: FontWeight.w800,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _maskStageLabel(_stage),
                      style: TextStyle(color: context.mutedText, fontSize: 12),
                    ),
                  ],
                ),
              ),
            )
          else ...[
            _picture(masked: _masked),
            const SizedBox(height: 6),
            Text(
              round.live
                  ? tr('bench_mask_live_note')
                  : tr('bench_mask_local_note'),
              textAlign: TextAlign.center,
              style: TextStyle(
                color: round.live ? teal : context.mutedText,
                fontWeight: FontWeight.w700,
                fontSize: 12,
                letterSpacing: 0.6,
              ),
            ),
            const SizedBox(height: 8),
            if (!_masked) ...[
              if (!_hasPicture) ...[
                _wordChips(round.objects),
                const SizedBox(height: 8),
              ],
              if (_hasPicture &&
                  round.boxes.length == round.objects.length) ...[
                Text(
                  tr('bench_mask_walk_note'),
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: context.accentText(teal),
                    fontWeight: FontWeight.w800,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 8),
              ],
              _countStepper(),
              const SizedBox(height: 10),
              _bigButton(
                context,
                label: tr('bench_mask_button'),
                color: coral,
                onTap: () => setState(() => _masked = true),
              ),
            ] else if (!done) ...[
              Text(
                tr('bench_mask_progress', {
                  'done': _revealed.length,
                  'total': round.objects.length,
                }),
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: context.inkText,
                  fontWeight: FontWeight.w800,
                  fontSize: 14,
                ),
              ),
              if (!_hasPicture && _revealed.isNotEmpty) ...[
                const SizedBox(height: 8),
                _wordChips([
                  for (var i = 0; i < round.objects.length; i++)
                    if (_revealed.contains(i)) round.objects[i],
                ]),
              ],
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: AppTextField(
                      controller: _guessCtrl,
                      autofocus: true,
                      textInputAction: TextInputAction.done,
                      textCapitalization: TextCapitalization.sentences,
                      onSubmitted: (_) => _guess(),
                      hint: !_hasPicture
                          ? tr('bench_mask_guess_hint_words')
                          : _cue >= 0
                          ? tr('bench_mask_cue_hint', {'n': _cue + 1})
                          : tr('bench_mask_guess_hint'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: _guess,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 18,
                        vertical: 15,
                      ),
                      decoration: BoxDecoration(
                        color: blue,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Text(
                        tr('bench_mask_guess_button'),
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                          fontSize: 15,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              if (_feedback.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  _feedback,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: _feedbackGood ? teal : coral,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
              ],
              // Escape hatch mid-round: a stuck or slow round never blocks
              // the demo — a fresh picture is one tap away.
              Center(
                child: GestureDetector(
                  onTap: () => unawaited(_load()),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      vertical: 10,
                      horizontal: 16,
                    ),
                    child: Text(
                      tr('bench_mask_new_picture'),
                      style: TextStyle(
                        color: context.mutedText,
                        fontWeight: FontWeight.w800,
                        fontSize: 13,
                        decoration: TextDecoration.underline,
                      ),
                    ),
                  ),
                ),
              ),
            ] else ...[
              Text(
                _hasPicture
                    ? tr('bench_mask_done')
                    : tr('bench_mask_done_words'),
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: context.inkText,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                  height: 1.45,
                ),
              ),
              const SizedBox(height: 8),
              _TransferCard('visual'),
              _AiTip(gameId: 'visual', level: round.objects.length),
              _AiVerdict(gameId: 'visual', score: round.objects.length),
              const SizedBox(height: 8),
              _bigButton(
                context,
                label: tr('bench_mask_next'),
                color: coral,
                onTap: () {
                  if (_count < 8) _count++;
                  unawaited(_load());
                },
              ),
            ],
          ],
        ],
      ),
    );
  }
}

/// Unions every mask-run rect of one cover into a SINGLE outline path
/// in display space, so the edge draws with one [canvas.drawPath] instead
/// of one stroke per row-run (which hatched the silhouette). Returns null
/// when there is nothing to outline or the union would be too slow
/// (> 300 runs): callers keep the per-run fill and skip the edge then.
/// Built when the cover is built, never in paint().
Path? buildSamOutline({
  required Rect rect,
  required List<SamMaskRun> runs,
  required int rasterW,
  required int rasterH,
}) {
  if (runs.isEmpty || runs.length > 300) return null;
  if (rasterW <= 0 || rasterH <= 0) return null;
  if (rect.width <= 0 || rect.height <= 0) return null;
  final cellW = rect.width / rasterW;
  final cellH = rect.height / rasterH;
  var acc = Path();
  for (final run in runs) {
    acc = Path.combine(
      PathOperation.union,
      acc,
      Path()..addRect(
        Rect.fromLTWH(
          rect.left + run.start * cellW,
          rect.top + run.row * cellH,
          (run.end - run.start + 1) * cellW,
          cellH,
        ),
      ),
    );
  }
  return acc;
}

/// Lays out the revealed item chips on a picture so none overlap: each
/// chip sits centred under its object ([anchors] are the object rects),
/// sized by [widths], and a chip that would cover an earlier one (walk
/// order) moves just below it, or above it when there is no room below.
/// Everything stays inside the [w] x [h] picture.
@visibleForTesting
List<Rect> layoutRecallChips(
  List<Rect> anchors,
  List<double> widths,
  double w,
  double h, {
  double height = 26,
  double gap = 4,
}) {
  final out = <Rect>[];
  final maxY = max(gap, h - height - gap);
  for (var i = 0; i < anchors.length; i++) {
    final cw = min(widths[i], w - 2 * gap);
    final left = (anchors[i].center.dx - cw / 2)
        .clamp(gap, max(gap, w - cw - gap))
        .toDouble();
    var top = (anchors[i].bottom - height - gap).clamp(gap, maxY).toDouble();
    for (var pass = 0; pass < 12; pass++) {
      final r = Rect.fromLTWH(left, top, cw, height);
      Rect? hit;
      for (final o in out) {
        if (o.inflate(gap / 2).overlaps(r)) {
          hit = o;
          break;
        }
      }
      if (hit == null) break;
      final below = hit.bottom + gap;
      top = below <= maxY ? below : max(gap, hit.top - height - gap);
      if (below > maxY && top == gap && pass > 0) break;
    }
    out.add(Rect.fromLTWH(left, top, cw, height));
  }
  return out;
}

/// One SAM cover's display geometry: the bounding [rect] in picture
/// pixels plus the decoded shape runs inside it (empty when the object
/// has box geometry only — then a soft rounded cover is drawn instead).
class _CoverGeom {
  final Rect rect;
  final List<SamMaskRun> runs;
  final int rasterW;
  final int rasterH;
  final Offset anchor;

  /// Unioned outline of all run rects (see [buildSamOutline]), drawn
  /// once per shape. Null means fill only.
  final Path? outline;

  const _CoverGeom({
    required this.rect,
    required this.runs,
    required this.rasterW,
    required this.rasterH,
    required this.anchor,
    this.outline,
  });
}

/// Station colour cycle, shared by covers, highlights and badges.
Color _stationColor(int i) {
  const cycle = [teal, blue, orange, coral];
  return cycle[i % cycle.length];
}

/// Paints every hidden cover: shape-faithful SAM silhouettes where a
/// mask decoded, soft rounded covers where only a box is known. The
/// cover under question gets a glow ring around its bounding box (the
/// ring itself leaks no shape).
class _SamCoverPainter extends CustomPainter {
  final List<_CoverGeom> covers;
  final Set<int> revealed;
  final int cue;
  // Round identity: without it a fresh round with the same object count
  // would keep the previous round's covers (same lengths, same cue).
  final int version;
  // Cue-ring pulse 0..1 (1200ms loop) and per-index reveal fade 0..1.
  final double cueT;
  final Map<int, double> revealT;

  const _SamCoverPainter({
    required this.covers,
    required this.revealed,
    required this.cue,
    this.version = 0,
    this.cueT = 0,
    this.revealT = const {},
  });

  static void paintShape(Canvas canvas, _CoverGeom cover, Paint paint) {
    final rect = cover.rect;
    final cellW = rect.width / cover.rasterW;
    final cellH = rect.height / cover.rasterH;
    final radius = Radius.circular(min(cellW, cellH) * 0.45);
    for (final run in cover.runs) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(
            rect.left + run.start * cellW,
            rect.top + run.row * cellH,
            (run.end - run.start + 1) * cellW,
            cellH,
          ),
          radius,
        ),
        paint,
      );
    }
  }

  @override
  void paint(Canvas canvas, Size size) {
    for (var i = 0; i < covers.length; i++) {
      final rt = revealT[i];
      if (revealed.contains(i) && rt == null) continue;
      final cover = covers[i];
      final rect = cover.rect;
      if (rect.width <= 0 || rect.height <= 0) continue;
      final station = _stationColor(i);
      // Newly revealed covers fade out and grow slightly instead of
      // vanishing instantly.
      final fade = rt == null ? 1.0 : (1 - rt);
      final grow = rt == null ? 1.0 : (1 + 0.08 * rt);
      final fill = Paint()
        ..color = Color.lerp(
          station,
          const Color(0xFF0F172A),
          0.55,
        )!.withValues(alpha: 0.92 * fade);
      final shade = Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.white.withValues(alpha: 0.10 * fade),
            Colors.black.withValues(alpha: 0.22 * fade),
          ],
        ).createShader(rect);
      final edge = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = station.withValues(alpha: fade);
      final center = rect.center;
      if (fade < 1) {
        canvas.saveLayer(
          rect,
          Paint()..color = const Color(0xFFFFFFFF).withValues(alpha: fade),
        );
      }
      canvas.save();
      canvas.translate(center.dx, center.dy);
      canvas.scale(grow);
      canvas.translate(-center.dx, -center.dy);
      if (cover.runs.isNotEmpty) {
        paintShape(canvas, cover, fill);
        paintShape(canvas, cover, shade);
        final outline = cover.outline;
        if (outline != null) canvas.drawPath(outline, edge);
      } else {
        // Box-only geometry: a soft oval reads as organic, not a box.
        canvas.drawOval(rect, fill);
        canvas.drawOval(rect, shade);
        canvas.drawOval(rect, edge);
      }
      canvas.restore();
      if (fade < 1) canvas.restore();
      if (i == cue) {
        final ring = RRect.fromRectAndRadius(rect, const Radius.circular(14));
        canvas.drawRRect(
          ring,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 7
            ..color = coral.withValues(alpha: 0.35),
        );
        canvas.drawRRect(
          ring,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2.5 + 1.5 * cueT
            ..color = coral,
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant _SamCoverPainter old) {
    return old.version != version ||
        old.cue != cue ||
        old.cueT != cueT ||
        old.covers.length != covers.length ||
        old.revealed.length != revealed.length ||
        !old.revealed.containsAll(revealed) ||
        !_doubleMapEq(old.revealT, revealT);
  }

  static bool _doubleMapEq(Map<int, double> a, Map<int, double> b) {
    if (a.length != b.length) return false;
    for (final e in a.entries) {
      if (b[e.key] != e.value) return false;
    }
    return true;
  }
}

/// Translucent station-colour silhouettes for highlight mode (items,
/// encode, result): the SAM shapes at 38% alpha with a 2px edge,
/// dimmed stations at 12%, the focused station pulsing 38% ↔ 60%.
class _SamHighlightPainter extends CustomPainter {
  final List<_CoverGeom> covers;
  final List<double> opacities;
  final int cue;
  final double cueT;
  final Set<int> dimmed;
  final int version;

  const _SamHighlightPainter({
    required this.covers,
    required this.opacities,
    required this.cue,
    required this.cueT,
    required this.dimmed,
    this.version = 0,
  });

  @override
  void paint(Canvas canvas, Size size) {
    for (var i = 0; i < covers.length; i++) {
      final cover = covers[i];
      final rect = cover.rect;
      if (rect.width <= 0 || rect.height <= 0) continue;
      final station = _stationColor(i);
      final shown = i < opacities.length ? opacities[i] : 1.0;
      final alpha = dimmed.contains(i)
          ? 0.12
          : (i == cue ? 0.38 + 0.22 * cueT : 0.38) * shown;
      final fill = Paint()..color = station.withValues(alpha: alpha);
      final edge = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = station.withValues(alpha: (alpha + 0.52).clamp(0.0, 0.9));
      if (cover.runs.isNotEmpty) {
        _SamCoverPainter.paintShape(canvas, cover, fill);
        final outline = cover.outline;
        if (outline != null) canvas.drawPath(outline, edge);
      } else {
        // Fallback boxes paint as rounded rects, like the real shapes.
        final r = RRect.fromRectAndRadius(rect, const Radius.circular(12));
        canvas.drawRRect(r, fill);
        canvas.drawRRect(r, edge);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _SamHighlightPainter old) {
    return old.version != version ||
        old.cue != cue ||
        old.cueT != cueT ||
        old.covers.length != covers.length ||
        old.dimmed.length != dimmed.length ||
        !old.dimmed.containsAll(dimmed) ||
        !_doubleListEq(old.opacities, opacities);
  }

  static bool _doubleListEq(List<double> a, List<double> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}

/// Numbered cover badge. The cover under question glows; study dots
/// (before masking) are teal.
class _CoverBadge extends StatelessWidget {
  final int number;
  final bool isCue;
  final bool isWalk;

  const _CoverBadge({
    required this.number,
    this.isCue = false,
    this.isWalk = false,
  });

  @override
  Widget build(BuildContext context) {
    final bg = isCue
        ? coral
        : isWalk
        ? teal
        : Colors.black.withValues(alpha: 0.88);
    return Container(
      width: 26,
      height: 26,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: bg,
        shape: BoxShape.circle,
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.9),
          width: 1.5,
        ),
        boxShadow: [
          if (isCue)
            BoxShadow(
              color: coral.withValues(alpha: 0.55),
              blurRadius: 10,
              spreadRadius: 1,
            ),
          BoxShadow(color: Colors.black.withValues(alpha: 0.35), blurRadius: 4),
        ],
      ),
      child: Text(
        '$number',
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w800,
          fontSize: 13,
        ),
      ),
    );
  }
}

/// One decoded SAM shape, cached per mask token: the range-coded
/// raster decode is far too heavy to repeat on every build.
class _DecodedShape {
  final List<SamMaskRun> runs;
  final int rasterW;
  final int rasterH;
  final double cx;
  final double cy;

  /// Outline in raster-cell units (0..rasterW, 0..rasterH), computed once
  /// per mask token in [_shapeFor] and cheaply transformed to display
  /// space at build time. Null means fill only.
  final Path? unitOutline;

  const _DecodedShape({
    required this.runs,
    required this.rasterW,
    required this.rasterH,
    required this.cx,
    required this.cy,
    this.unitOutline,
  });
}

/// A picture with SAM's shape-faithful covers on top. Generated art is
/// square (512x512), so the picture renders square too — then every
/// normalized SAM box maps 1:1 onto the display and each cover sits
/// exactly on its object. With a decoded shape mask the cover follows
/// the object's outline; with box geometry only it is a soft rounded
/// cover; without geometry the picture is covered by an even grid of
/// tiles. Revealed objects lose their cover and gain a label chip.
/// Before masking, [showWalk] draws the numbered study walk instead.
class MaskedPicture extends StatefulWidget {
  final String imageUrl;
  final String scene;
  final List<String> objects;
  final List<List<double>> boxes;
  final List<String> masks;
  final Set<int> revealed;
  final bool masked;
  final int cue;
  final int version;
  final bool showWalk;
  final VoidCallback? onImageError;
  // Highlight mode (Room Palace items/encode/result): translucent
  // station-colour silhouettes instead of dark covers. Indexes in
  // [dimmed] stay dim (result step misses).
  final bool highlight;
  final Set<int> dimmed;
  const MaskedPicture({
    super.key,
    required this.imageUrl,
    required this.scene,
    required this.objects,
    required this.boxes,
    required this.masks,
    required this.revealed,
    required this.masked,
    this.cue = -1,
    this.version = 0,
    this.showWalk = false,
    this.highlight = false,
    this.dimmed = const {},
    this.onImageError,
  });

  @override
  State<MaskedPicture> createState() => _MaskedPictureState();
}

class _MaskedPictureState extends State<MaskedPicture>
    with TickerProviderStateMixin {
  /// Decoded shapes by mask token (null = undecodable, box cover).
  /// Mask tokens are unique per round; the cap bounds long sessions.
  final _shapes = <String, _DecodedShape?>{};

  /// Highlight stagger (120ms per station, 300ms each) and the 1200ms
  /// cue pulse. Both are finite/repeating tickers: the pulse never
  /// starts under `flutter test` so pumpAndSettle keeps working.
  AnimationController? _stagger;
  late final AnimationController _pulse;

  /// Reveal fade-outs (260ms) for indexes newly added to [revealed].
  final _reveals = <int, AnimationController>{};

  bool get _wantPulse => widget.cue >= 0 && !isFlutterTest;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    if (widget.highlight && widget.objects.isNotEmpty) {
      _stagger = AnimationController(
        vsync: this,
        duration: Duration(
          milliseconds: 300 + 120 * (widget.objects.length - 1),
        ),
      )..forward();
      AppFeedback.select();
    }
    if (_wantPulse) _pulse.repeat(reverse: true);
  }

  @override
  void didUpdateWidget(covariant MaskedPicture oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.masked) {
      for (final i in widget.revealed) {
        if (!oldWidget.revealed.contains(i) && !_reveals.containsKey(i)) {
          final c = AnimationController(
            vsync: this,
            duration: const Duration(milliseconds: 260),
          );
          _reveals[i] = c;
          c.addStatusListener((s) {
            if (s == AnimationStatus.completed) {
              _reveals.remove(i)?.dispose();
            }
          });
          c.forward();
        }
      }
      for (final i in _reveals.keys.toList()) {
        if (!widget.revealed.contains(i)) _reveals.remove(i)?.dispose();
      }
    } else if (_reveals.isNotEmpty) {
      for (final c in _reveals.values) {
        c.dispose();
      }
      _reveals.clear();
    }
    if (widget.highlight && widget.objects.length != oldWidget.objects.length) {
      _stagger?.dispose();
      _stagger = widget.objects.isEmpty
          ? null
          : (AnimationController(
              vsync: this,
              duration: Duration(
                milliseconds: 300 + 120 * (widget.objects.length - 1),
              ),
            )..forward());
    }
    if (_wantPulse && !_pulse.isAnimating) {
      _pulse.repeat(reverse: true);
    } else if (!_wantPulse && _pulse.isAnimating) {
      _pulse.stop();
      _pulse.reset();
    }
  }

  @override
  void dispose() {
    _stagger?.dispose();
    _pulse.dispose();
    for (final c in _reveals.values) {
      c.dispose();
    }
    super.dispose();
  }

  /// Staggered highlight progress of station [i]: 0 → 1 starting at
  /// i * 120ms, 300ms each, easeOutCubic.
  double _staggerT(int i) {
    final c = _stagger;
    if (c == null) return 1.0;
    final elapsed = c.value * c.duration!.inMilliseconds;
    return Curves.easeOutCubic.transform(
      ((elapsed - i * 120) / 300).clamp(0.0, 1.0),
    );
  }

  _DecodedShape? _shapeFor(String token) {
    if (token.isEmpty) return null;
    if (_shapes.containsKey(token)) return _shapes[token];
    _DecodedShape? shape;
    final spec = parseSamMaskToken(token);
    final raster = decodeSamMaskToken(token);
    if (spec != null && raster != null) {
      final runs = samMaskRuns(raster, spec.width, spec.height);
      if (runs.isNotEmpty) {
        final c = samMaskCentroid(raster, spec.width, spec.height);
        shape = _DecodedShape(
          runs: runs,
          rasterW: spec.width,
          rasterH: spec.height,
          cx: c.x,
          cy: c.y,
          unitOutline: buildSamOutline(
            rect: Rect.fromLTWH(
              0,
              0,
              spec.width.toDouble(),
              spec.height.toDouble(),
            ),
            runs: runs,
            rasterW: spec.width,
            rasterH: spec.height,
          ),
        );
      }
    }
    if (_shapes.length > 48) _shapes.clear();
    _shapes[token] = shape;
    return shape;
  }

  Widget _base(BuildContext context, double w, double h) {
    // AiImage draws embedded data:image payloads too; on any failure it
    // shows the placeholder and reports, so the parent can drop the
    // masks instead of covering a picture the player never saw.
    return AiImage(
      imageRef: widget.imageUrl,
      height: h,
      width: w,
      cacheWidth: 800,
      fallback: _placeholder(context),
      onError: widget.onImageError,
    );
  }

  Widget _placeholder(BuildContext context) {
    return Container(
      width: double.infinity,
      height: double.infinity,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [sky.withValues(alpha: 0.5), teal.withValues(alpha: 0.35)],
        ),
      ),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            HugeIcon(
              icon: HugeIcons.strokeRoundedImage01,
              color: Colors.white.withValues(alpha: 0.9),
              size: 44,
              strokeWidth: 1.6,
            ),
            const SizedBox(height: 6),
            Text(
              widget.scene,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w800,
                fontSize: 15,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Separates stacked badge anchors so every number stays readable.
  /// Only the badges move — covers stay exactly on their objects.
  List<Offset> _spreadBadges(List<Offset> anchors, double w, double h) {
    final out = anchors.toList();
    for (var pass = 0; pass < 8; pass++) {
      var moved = false;
      for (var j = 1; j < out.length; j++) {
        for (var k = 0; k < j; k++) {
          final dx = out[j].dx - out[k].dx;
          final dy = out[j].dy - out[k].dy;
          final dist = sqrt(dx * dx + dy * dy);
          const minD = 30.0;
          if (dist < minD) {
            final nx = dist < 0.5 ? 1.0 : dx / dist;
            final ny = dist < 0.5 ? 0.0 : dy / dist;
            final push = minD - dist;
            out[j] = Offset(
              (out[j].dx + nx * push).clamp(14.0, w - 14.0),
              (out[j].dy + ny * push).clamp(14.0, h - 14.0),
            );
            moved = true;
          }
        }
      }
      if (!moved) break;
    }
    return out;
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        // Square for 1:1 SAM mapping, capped so the question row stays
        // near the picture (and in the lazy list window) on wide screens.
        final side = min(constraints.maxWidth, 380.0);
        final w = side;
        final h = side;
        // No stations (yet): the grid math below would divide by zero,
        // so show just the picture with no covers or badges.
        if (widget.objects.isEmpty) {
          return Center(
            child: SizedBox(
              width: side,
              height: side,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: _base(context, w, h),
              ),
            ),
          );
        }
        return Center(
          child: SizedBox(
            width: side,
            height: side,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Builder(
                builder: (context) {
                  final n = widget.objects.length;
                  final cols = n <= 2 ? n : (n <= 4 ? 2 : 3);
                  final rows = (n / cols).ceil();
                  Rect rectFor(int i) {
                    if (widget.boxes.length == n) {
                      final b = widget.boxes[i];
                      return Rect.fromLTWH(
                        b[0] * w,
                        b[1] * h,
                        b[2] * w,
                        b[3] * h,
                      );
                    }
                    final c = i % cols;
                    final r = i ~/ cols;
                    // Small gaps keep neighboring tiles readable.
                    return Rect.fromLTWH(
                      c * w / cols + 3,
                      r * h / rows + 3,
                      w / cols - 6,
                      h / rows - 6,
                    );
                  }

                  final covers = <_CoverGeom>[];
                  final anchors = <Offset>[];
                  for (var i = 0; i < n; i++) {
                    final rect = rectFor(i);
                    // Shapes decode once per mask token (cached above);
                    // rects stay cheap so resize/orientation stays exact.
                    final shape = i < widget.masks.length
                        ? _shapeFor(widget.masks[i])
                        : null;
                    final runs = shape?.runs ?? const <SamMaskRun>[];
                    var anchor = rect.center;
                    if (shape != null) {
                      anchor = Offset(
                        rect.left + shape.cx * rect.width,
                        rect.top + shape.cy * rect.height,
                      );
                    }
                    covers.add(
                      _CoverGeom(
                        rect: rect,
                        runs: runs,
                        rasterW: shape?.rasterW ?? 0,
                        rasterH: shape?.rasterH ?? 0,
                        anchor: anchor,
                        outline: shape?.unitOutline?.transform(
                          Float64List.fromList([
                            rect.width / shape.rasterW,
                            0,
                            0,
                            0,
                            0,
                            rect.height / shape.rasterH,
                            0,
                            0,
                            0,
                            0,
                            1,
                            0,
                            rect.left,
                            rect.top,
                            0,
                            1,
                          ]),
                        ),
                      ),
                    );
                    anchors.add(anchor);
                  }
                  final badges = _spreadBadges(anchors, w, h);
                  final chipSlots = <int, Rect>{};
                  if (widget.masked) {
                    final shown = [
                      for (var i = 0; i < n; i++)
                        if (widget.revealed.contains(i) &&
                            i < widget.objects.length)
                          i,
                    ];
                    // Measure with the inherited font (Lexend), exactly as
                    // the chip's Text will render.
                    final chipStyle = DefaultTextStyle.of(context).style
                        .merge(AppText.micro)
                        .copyWith(fontWeight: FontWeight.w700);
                    final scaler = MediaQuery.textScalerOf(context);
                    final widths = [
                      for (final i in shown)
                        min(
                          w * 0.42,
                          (TextPainter(
                                text: TextSpan(
                                  text: widget.objects[i],
                                  style: chipStyle,
                                ),
                                textDirection: TextDirection.ltr,
                                textScaler: scaler,
                                maxLines: 1,
                              )..layout()).width +
                              22,
                        ),
                    ];
                    final slots = layoutRecallChips(
                      [for (final i in shown) covers[i].rect],
                      widths,
                      w,
                      h,
                    );
                    for (var k = 0; k < shown.length; k++) {
                      chipSlots[shown[k]] = slots[k];
                    }
                  }
                  final anims = <Listenable>[
                    ?_stagger,
                    _pulse,
                    ..._reveals.values,
                  ];

                  final base = RepaintBoundary(child: _base(context, w, h));
                  return AnimatedBuilder(
                    animation: Listenable.merge(anims),
                    builder: (context, child) => Stack(
                      children: [
                        Positioned.fill(child: child!),
                        if (widget.masked)
                          Positioned.fill(
                            child: CustomPaint(
                              painter: _SamCoverPainter(
                                covers: covers,
                                revealed: widget.revealed,
                                cue: widget.cue,
                                version: widget.version,
                                cueT: _pulse.value,
                                revealT: {
                                  for (final e in _reveals.entries)
                                    e.key: e.value.value,
                                },
                              ),
                            ),
                          ),
                        if (widget.masked)
                          for (var i = 0; i < n; i++)
                            if (!widget.revealed.contains(i))
                              Positioned(
                                left: badges[i].dx - 13,
                                top: badges[i].dy - 13,
                                child: _CoverBadge(
                                  number: i + 1,
                                  isCue: i == widget.cue,
                                ),
                              )
                            else ...[
                              Builder(
                                builder: (context) {
                                  // The chip floats below the object on its
                                  // own slot (never capped by a narrow
                                  // object rect) and never covers another.
                                  final slot = chipSlots[i];
                                  if (slot == null) {
                                    return const SizedBox.shrink();
                                  }
                                  return Positioned.fromRect(
                                    rect: slot,
                                    child: Center(
                                      child: Container(
                                        height: 26,
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 10,
                                        ),
                                        decoration: BoxDecoration(
                                          color: Colors.white.withValues(
                                            alpha: 0.92,
                                          ),
                                          borderRadius: BorderRadius.circular(
                                            AppRadius.pill,
                                          ),
                                          boxShadow: const [
                                            BoxShadow(
                                              color: Color(0x33000000),
                                              blurRadius: 6,
                                              offset: Offset(0, 1),
                                            ),
                                          ],
                                        ),
                                        child: Center(
                                          widthFactor: 1,
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Flexible(
                                                child: Text(
                                                  widget.objects[i],
                                                  style: AppText.micro.copyWith(
                                                    color: context.accentText(
                                                      teal,
                                                    ),
                                                    fontWeight: FontWeight.w700,
                                                  ),
                                                  maxLines: 1,
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ],
                        if (widget.highlight && !widget.masked) ...[
                          Positioned.fill(
                            child: CustomPaint(
                              painter: _SamHighlightPainter(
                                covers: covers,
                                opacities: [
                                  for (var i = 0; i < n; i++) _staggerT(i),
                                ],
                                cue: widget.cue,
                                cueT: _pulse.value,
                                dimmed: widget.dimmed,
                                version: widget.version,
                              ),
                            ),
                          ),
                          for (var i = 0; i < n; i++)
                            Positioned(
                              left: badges[i].dx - 13,
                              top: badges[i].dy - 13,
                              child: Transform.scale(
                                scale:
                                    (0.6 +
                                        0.4 *
                                            Curves.easeOutBack.transform(
                                              _staggerT(i),
                                            )) *
                                    (i == widget.cue ? 1.15 : 1.0),
                                child: _CoverBadge(number: i + 1, isWalk: true),
                              ),
                            ),
                        ] else if (widget.showWalk)
                          for (var i = 0; i < n; i++)
                            Positioned(
                              left: badges[i].dx - 13,
                              top: badges[i].dy - 13,
                              child: _CoverBadge(number: i + 1, isWalk: true),
                            ),
                      ],
                    ),
                    child: base,
                  );
                },
              ),
            ),
          ),
        );
      },
    );
  }
}
