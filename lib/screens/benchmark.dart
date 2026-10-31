import '../theme/app_theme.dart';

import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';

import '../widgets/ai_help_button.dart';
import '../widgets/app_buttons.dart';
import '../l10n/app_localizations.dart';
import '../models/meta_segment.dart';
import '../models/meta_task.dart';
import '../models/palace_drill.dart'
    show
        allConcreteNounsFor,
        localPalaceTask,
        localPictureTask,
        palaceRoutesFor,
        stationsFromLabels;
import '../services/app_feedback.dart';
import '../services/memory_store.dart';
import '../services/meta_ai_service.dart';
import 'benchmark_stats.dart' show BenchmarkDetailPage;
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

  /// Spatial practice round: Muse Spark fills the loci stimulus, Muse
  /// Image paints the palace, SAM turns it into ordered stations.
  /// Offline this is just the local palace task (no image). Mirrors the
  /// lesson path (Spark then enrich).
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
    try {
      return await MetaAIService.enrichSpatialTask(
        base,
        difficulty: difficulty,
        seed: seed,
      );
    } catch (_) {
      return base;
    }
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
                        fontWeight: FontWeight.w900,
                        fontSize: 11,
                        letterSpacing: 1.2,
                      ),
                    ),
                  ),
                  Text(
                    snap.data?.fallback == false ? 'SPARK OPEN' : 'LOCAL',
                    style: TextStyle(
                      color: context.mutedText,
                      fontWeight: FontWeight.w700,
                      fontSize: 10,
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
/// borrowing the models' names.
class _AiModelsStrip extends StatelessWidget {
  final String models;
  final bool live;
  const _AiModelsStrip(this.models, {this.live = false});

  @override
  Widget build(BuildContext context) {
    final dot = live ? teal : context.mutedText;
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
              live
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
                  live ? tr('bench_ai_live') : tr('bench_ai_local'),
                  style: TextStyle(
                    color: dot,
                    fontWeight: FontWeight.w900,
                    fontSize: 10,
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
                            fontWeight: FontWeight.w900,
                            fontSize: 11,
                            letterSpacing: 1.2,
                          ),
                        ),
                      ),
                      Text(
                        source,
                        style: TextStyle(
                          color: context.mutedText,
                          fontWeight: FontWeight.w700,
                          fontSize: 10,
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
                    color: blue,
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
    build: () => const VisualGamePage(),
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

class BenchmarkHubPage extends StatefulWidget {
  const BenchmarkHubPage({super.key});

  @override
  State<BenchmarkHubPage> createState() => _BenchmarkHubPageState();
}

class _BenchmarkHubPageState extends State<BenchmarkHubPage> {
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
      body: SafeArea(
        top: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 120),
          children: [
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: Text(
                    tr('bench_hub_title'),
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurface,
                      fontWeight: FontWeight.bold,
                      fontSize: 28,
                    ),
                  ),
                ),
                const AiHelpButton(topic: AiHelpTopics.benchmark),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              tr('bench_hub_sub'),
              style: TextStyle(color: context.mutedText, fontSize: 14),
            ),
            const SizedBox(height: 16),
            if (!BenchmarkStore.loaded)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: CircularProgressIndicator(),
                ),
              ),
            for (final g in _games) ...[
              _BenchmarkCard(
                def: g,
                onTap: () async {
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
                        attempts: List.of(
                          BenchmarkStore.attempts[g.id] ?? const <int>[],
                        ),
                        buildGame: g.build,
                        loadBest: () => BenchmarkStore.best[g.id],
                        loadAttempts: () => List.of(
                          BenchmarkStore.attempts[g.id] ?? const <int>[],
                        ),
                      ),
                    ),
                  );
                  if (mounted) setState(() {});
                },
              ),
              const SizedBox(height: 10),
            ],
            Text(
              tr('bench_hub_tip'),
              textAlign: TextAlign.center,
              style: TextStyle(color: context.mutedText, fontSize: 13),
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
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: context.cardBg,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: context.hairline, width: 2),
        ),
        child: Row(
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: def.tint.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(14),
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
                    style: TextStyle(
                      color: context.inkText,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  Text(
                    def.subtitleIn(AppLocalizations.localeCode),
                    style: TextStyle(color: context.mutedText, fontSize: 13),
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  b == null
                      ? '—'
                      : '$b ${def.bestLabelIn(AppLocalizations.localeCode)}',
                  style: TextStyle(
                    color: context.inkText,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
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

Widget _gameScaffold({
  required BuildContext context,
  required String title,
  required String counter,
  required Widget body,
  String aiModels = '',
  bool aiLive = false,
}) {
  final scheme = Theme.of(context).colorScheme;
  return Scaffold(
    backgroundColor: Theme.of(context).scaffoldBackgroundColor,
    appBar: AppBar(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      elevation: 0,
      scrolledUnderElevation: 0,
      leading: const EngramBackButton(),
      title: Text(
        title,
        style: TextStyle(
          color: scheme.onSurface,
          fontWeight: FontWeight.bold,
          fontSize: 17,
        ),
      ),
      actions: [
        Padding(
          padding: const EdgeInsets.only(right: 8),
          child: Center(
            child: Text(
              counter,
              style: TextStyle(
                color: context.mutedText,
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
          ),
        ),
        const Padding(
          padding: EdgeInsets.only(right: 12),
          child: Center(child: AiHelpButton(topic: AiHelpTopics.benchmark)),
        ),
      ],
    ),
    body: aiModels.isEmpty
        ? body
        : Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                child: _AiModelsStrip(aiModels, live: aiLive),
              ),
              Expanded(child: body),
            ],
          ),
  );
}

/// Lumosity-trap guard for practice games. Drills alone improve mostly
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
              fontWeight: FontWeight.w900,
              fontSize: 11,
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
          fontWeight: FontWeight.w900,
          fontSize: 17,
          letterSpacing: 0.5,
        ),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
    ),
  );
}

Widget _resultBox(
  BuildContext context, {
  required String title,
  required String detail,
  required VoidCallback onRetry,
  required String retryLabel,
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
      setState(() => _over = true);
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
                _nextRound();
              }),
              retryLabel: tr('bench_retry_xp'),
            ),
            _TransferCard('sequence'),
            _AiTip(gameId: 'sequence', level: _seq.length - 1),
            _AiVerdict(gameId: 'sequence', score: _seq.length - 1),
          ] else ...[
            Text(
              _busy
                  ? tr('bench_seq_watch', {'n': _level})
                  : tr('bench_seq_turn'),
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurface,
                fontWeight: FontWeight.bold,
                fontSize: 16,
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
            LinearProgressIndicator(
              value: _busy ? 0 : _input / _seq.length,
              minHeight: 8,
              backgroundColor: context.hairline,
              valueColor: const AlwaysStoppedAnimation(blue),
            ),
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
  int _dealId = 0;

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
    final deal = ++_dealId;
    Future.delayed(const Duration(milliseconds: 2500), () {
      if (mounted && _show && !_over && deal == _dealId) {
        setState(() => _show = false);
      }
    });
    unawaited(_prefetchNext());
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
      setState(() => _over = true);
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
                _deal();
              }),
              retryLabel: tr('bench_restart'),
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
            _bigButton(
              context,
              label: tr('bench_num_gotit'),
              onTap: () => setState(() => _show = false),
            ),
          ] else ...[
            Text(
              tr('bench_num_q'),
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurface,
                fontWeight: FontWeight.bold,
                fontSize: 18,
              ),
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

  /// Maps a Voice Transcribe transcript onto a guess: true for SEEN,
  /// false for NEW, null when the transcript is empty, ambiguous or
  /// says neither. Whole-word matching only, so "known" never counts
  /// as "no"; explicit negated phrases ("not seen", "nem láttam")
  /// always count as NEW.
  static bool? voiceGuessFromTranscript(
    String transcript, [
    String locale = 'en',
  ]) {
    final lower = transcript.toLowerCase();
    const negated = {
      'not seen',
      'never seen',
      'have not seen',
      "haven't seen",
      'did not see',
      "didn't see",
      'nem láttam',
      'nem lattam',
      'sosem láttam',
      'sosem lattam',
    };
    for (final phrase in negated) {
      if (lower.contains(phrase)) return false;
    }
    final tokens = lower
        .split(RegExp('[^a-záéíóöőúüű]+'))
        .where((t) => t.isNotEmpty)
        .toSet();
    if (tokens.isEmpty) return null;
    const seen = {
      'seen',
      'yes',
      'saw',
      'remember',
      'known',
      'láttam',
      'lattam',
      'igen',
      'ismerem',
      'tudom',
    };
    const fresh = {
      'new',
      'no',
      'not',
      'never',
      'új',
      'uj',
      'nem',
      'soha',
      'nemlattam',
    };
    final saysSeen = tokens.intersection(seen).isNotEmpty;
    final saysNew = tokens.intersection(fresh).isNotEmpty;
    if (saysSeen == saysNew) return null;
    return saysSeen;
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
  final _recorder = AudioRecorder();
  bool _voiceBusy = false;
  bool _recording = false;
  String _voiceNote = '';
  Timer? _voiceTimer;

  @override
  void initState() {
    super.initState();
    _pool = VerbalGamePage.wordPool(AppLocalizations.localeCode);
    _fresh = List.of(_pool)..shuffle();
    _next();
  }

  @override
  void dispose() {
    _voiceTimer?.cancel();
    _recorder.dispose();
    super.dispose();
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

  /// Voice answer: records a short clip, has Voice Transcribe turn it
  /// into text, and maps the transcript onto a SEEN/NEW guess. Tapping
  /// again finishes early; otherwise the clip auto-stops after 6
  /// seconds. Never throws and never pops anything up — every failure
  /// stays as one inline line and the tap buttons keep working.
  Future<void> _voiceAnswer() async {
    if (_over) return;
    if (_recording) {
      await _finishVoice();
      return;
    }
    if (_voiceBusy) return;
    // Átírás csak felhővel megy: kulcs/hozzájárulás nélkül nem indítunk
    // rögzítést, mert az eredmény úgyis csak „nem értettem" lenne.
    if (!await MetaAIService.cloudReady()) {
      if (!mounted) return;
      setState(() => _voiceNote = tr('bench_voice_nocloud'));
      return;
    }
    setState(() {
      _voiceBusy = true;
      _recording = true;
      _voiceNote = '';
    });
    try {
      if (!await _recorder.hasPermission()) {
        if (!mounted) return;
        setState(() {
          _voiceBusy = false;
          _recording = false;
          _voiceNote = tr('bench_voice_nomic');
        });
        return;
      }
      var dir = '';
      try {
        dir = (await getTemporaryDirectory()).path;
      } catch (_) {}
      final path = dir.isEmpty
          ? 'engrammo_voice.m4a'
          : '$dir/engrammo_voice.m4a';
      await _recorder.start(
        const RecordConfig(
          encoder: AudioEncoder.aacLc,
          bitRate: 64000,
          sampleRate: 16000,
          numChannels: 1,
        ),
        path: path,
      );
      if (!mounted) return;
      setState(() {});
      _voiceTimer?.cancel();
      _voiceTimer = Timer(const Duration(seconds: 6), () {
        if (mounted) _finishVoice();
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _voiceBusy = false;
        _recording = false;
        _voiceNote = tr('bench_voice_nomic');
      });
    }
  }

  Future<void> _finishVoice() async {
    if (!_recording) return;
    _voiceTimer?.cancel();
    _recording = false;
    if (!mounted) {
      _voiceBusy = false;
      return;
    }
    setState(() => _voiceNote = tr('bench_voice_working'));
    try {
      final path = await _recorder.stop();
      if (path == null || path.isEmpty) throw StateError('no audio');
      final bytes = await XFile(path).readAsBytes();
      // A felvétel fix nevű ideiglenes fájlba megy, így minden új rögzítés
      // felülírja az előzőt: legfeljebb egy 6 mp-es klip marad a temp
      // mappában (törlésre nincs keresztplatformos API a record+XFile
      // rétegben, ezért a forgatás a védelem a felhalmozódás ellen).
      if (bytes.isEmpty || bytes.length > 1500000) {
        throw StateError('bad audio');
      }
      final answer = await MetaAIService.transcribe(
        audioDataUrl: 'data:audio/aac;base64,${base64Encode(bytes)}',
        locale: AppLocalizations.localeCode,
      );
      if (!mounted) return;
      setState(() => _voiceBusy = false);
      if (_over) return;
      final heard = answer.text.trim();
      final guess = VerbalGamePage.voiceGuessFromTranscript(
        heard,
        AppLocalizations.localeCode,
      );
      if (guess == null) {
        setState(() {
          _voiceNote = heard.isEmpty
              ? tr('bench_voice_unclear')
              : '${tr('bench_voice_heard', {'text': heard})}\n'
                    '${tr('bench_voice_unclear')}';
        });
        return;
      }
      setState(() {
        _voiceNote = tr('bench_voice_heard', {'text': heard});
      });
      _guess(guess);
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _voiceBusy = false;
        _voiceNote = tr('bench_voice_nomic');
      });
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
        setState(() => _over = true);
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
      aiModels: 'Muse Spark • Voice Transcribe',
      aiLive: _wordLive,
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
                _next();
              }),
              retryLabel: tr('bench_verbal_retry'),
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
            const SizedBox(height: 10),
            GestureDetector(
              onTap: _voiceAnswer,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: teal, width: 2),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (_voiceBusy)
                      SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: teal,
                        ),
                      )
                    else
                      const HugeIcon(
                        icon: HugeIcons.strokeRoundedMic01,
                        color: teal,
                        size: 22,
                        strokeWidth: 2.0,
                      ),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        _recording
                            ? tr('bench_voice_listening')
                            : tr('bench_voice_answer'),
                        style: const TextStyle(
                          color: teal,
                          fontWeight: FontWeight.w900,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            if (_voiceNote.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(
                _voiceNote,
                textAlign: TextAlign.center,
                style: TextStyle(color: context.mutedText, fontSize: 12),
              ),
            ],
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
  const VisualGamePage({super.key});

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

  int get _size => _level >= 4 ? 16 : 9;
  int get _cols => _level >= 4 ? 4 : 3;

  @override
  void initState() {
    super.initState();
    _deal();
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
    final deal = ++_aiDealId;
    Future.delayed(const Duration(milliseconds: 2200), () {
      if (mounted &&
          _show &&
          !_over &&
          deal == _aiDealId &&
          _aiRound == null) {
        setState(() => _show = false);
      }
    });
    setState(() {});
    unawaited(_prefetchPattern());
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
      // A picture round is live when any model contributed: Spark filled
      // the scene (!fallback) or Image painted it (only live calls yield
      // a URL — offline rounds never carry one).
      _roundLive = !task.fallback || task.imageUrl.isNotEmpty;
    });
    Future.delayed(const Duration(milliseconds: 3500), () {
      if (mounted && _show && !_over && id == _aiDealId && _aiRound != null) {
        setState(() => _show = false);
      }
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
      setState(() => _over = true);
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
      setState(() => _over = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final ai = _aiRound;
    return _gameScaffold(
      context: context,
      title: tr('bench_game_visual_title'),
      counter: tr('bench_level_n', {'n': _level}),
      aiModels: 'Muse Spark • Muse Image • SAM 3.1',
      aiLive: _roundLive,
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
        children: [
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
                _deal();
              }),
              retryLabel: tr('bench_restart'),
            ),
            _TransferCard('visual'),
            _AiTip(gameId: 'visual', level: _level - 1),
            _AiVerdict(gameId: 'visual', score: _level - 1),
          ] else if (_aiLoading) ...[
            const SizedBox(height: 40),
            const Center(child: CircularProgressIndicator()),
            const SizedBox(height: 12),
            Text(
              tr('ai_picture_loading'),
              textAlign: TextAlign.center,
              style: TextStyle(color: context.mutedText, fontSize: 14),
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
                child: Image.network(
                  ai.imageUrl,
                  height: 200,
                  width: double.infinity,
                  fit: BoxFit.cover,
                  cacheWidth: 800,
                  loadingBuilder: (context, child, progress) {
                    if (progress == null) return child;
                    return const SizedBox(
                      height: 200,
                      child: Center(
                        child: SizedBox(
                          width: 28,
                          height: 28,
                          child: CircularProgressIndicator(strokeWidth: 3),
                        ),
                      ),
                    );
                  },
                  errorBuilder: (context, error, stack) =>
                      const SizedBox.shrink(),
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
                  style: TextStyle(color: context.mutedText, fontSize: 12),
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
                onTap: () => setState(() => _show = false),
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
                        border: Border.all(color: context.hairline, width: 2),
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
            Text(
              _show ? tr('bench_visual_memorize') : tr('bench_visual_tap'),
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurface,
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
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
                final on = _show ? _pattern.contains(i) : _picked.contains(i);
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
            _bigButton(
              context,
              label: _show ? tr('bench_watch') : tr('bench_check'),
              onTap: _show ? null : _check,
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
      setState(() => _over = true);
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
                _deal();
              }),
              retryLabel: tr('bench_order_retry'),
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
  int _stations = SpatialGamePage.minStations;
  late String _route;
  late List<String> _stationList;
  late List<String> _words;
  late int _target;
  late List<String> _options;
  bool _show = true;
  bool _over = false;
  int _dealId = 0;
  Timer? _hideTimer;
  String _palaceImage = '';
  String? _palaceLine;
  Uint8List? _camBytes;
  bool _camBusy = false;
  String _camError = '';
  List<String> _wonder = [];
  bool _wonderLoading = false;
  int _wonderToken = 0;
  bool _wonderLive = false;
  bool _taskLive = false;

  @override
  void initState() {
    super.initState();
    _deal();
  }

  @override
  void dispose() {
    _hideTimer?.cancel();
    super.dispose();
  }

  void _deal() {
    final id = ++_dealId;
    _hideTimer?.cancel();
    final locale = AppLocalizations.localeCode;
    final routeIdx = _rnd.nextInt(palaceRoutesFor(locale).length);
    _route = SpatialGamePage.routeNames(locale)[routeIdx];
    _stationList = SpatialGamePage.pickStations(
      _stations,
      routeIndex: routeIdx,
      locale: locale,
    );
    _words = SpatialGamePage.pickWords(_stations, null, locale);
    _target = _rnd.nextInt(_stationList.length);
    _options = SpatialGamePage.makeOptions(
      _words[_target],
      _words,
      null,
      locale,
    );
    _show = true;
    _palaceImage = '';
    _palaceLine = null;
    _camBytes = null;
    _camBusy = false;
    _camError = '';
    _wonder = [];
    _wonderLoading = false;
    _wonderLive = false;
    _taskLive = false;
    _armHideTimer(id);
    unawaited(_upgradeSpatial(id, _stations, locale));
    unawaited(_refreshWonder());
  }

  /// (Re)loads the Wonder route preview for the current stations. Stale
  /// responses are dropped, so palace upgrades and camera rooms always
  /// win over older previews.
  Future<void> _refreshWonder() async {
    final token = ++_wonderToken;
    final stations = List.of(_stationList);
    final route = _route;
    setState(() => _wonderLoading = true);
    final res = await BenchmarkMeta.wonderPreview(
      route: route,
      stations: stations,
      locale: AppLocalizations.localeCode,
    );
    if (!mounted || token != _wonderToken) return;
    setState(() {
      _wonder = res.views.isEmpty
          ? SpatialGamePage.localWonderPreview(
              stations,
              AppLocalizations.localeCode,
            )
          : res.views;
      _wonderLoading = false;
      _wonderLive = res.live && res.views.isNotEmpty;
    });
  }

  void _armHideTimer(int id) {
    _hideTimer?.cancel();
    final ms = 2500 + _stations * 900;
    _hideTimer = Timer(Duration(milliseconds: ms), () {
      if (mounted && _show && !_over && id == _dealId) {
        setState(() => _show = false);
      }
    });
  }

  Future<void> _upgradeSpatial(int id, int stations, String locale) async {
    MetaTask task;
    try {
      task = await BenchmarkMeta.spatialRound(
        seed:
            'bench:spatial:$stations:${DateTime.now().millisecondsSinceEpoch}',
        stations: stations,
        locale: locale,
      );
    } catch (_) {
      return;
    }
    if (!mounted || id != _dealId || _over) return;
    // The illustration upgrades the round even when the word deal does
    // not match: a live palace picture is still a live contribution.
    if (task.imageUrl.isNotEmpty) {
      setState(() {
        _palaceImage = task.imageUrl;
        _palaceLine = task.prompt;
        _taskLive = true;
      });
    }
    if (task.fallback && task.imageUrl.isEmpty) return;
    // Words/options swap only during the memorize phase: a slow network
    // must never rewrite the question under the player's eyes.
    if (!_show) return;
    if (task.items.length != stations || task.stations.length != stations) {
      return;
    }
    final answer = task.correct >= 0 && task.correct < task.options.length
        ? task.options[task.correct]
        : '';
    final target = task.items.indexOf(answer);
    if (target < 0 || task.options.length != 4) return;
    setState(() {
      _stationList = List.of(task.stations);
      _words = List.of(task.items);
      _target = target;
      _options = List.of(task.options);
      _palaceImage = task.imageUrl;
      _palaceLine = task.prompt;
      _taskLive = !task.fallback || task.imageUrl.isNotEmpty;
    });
    unawaited(_refreshWonder());
  }

  /// Camera palace: photographs the player's own room and lets SAM 3.1
  /// turn the spotted details into palace stations. The memorize timer
  /// pauses while the camera is open. Never throws and never pops
  /// anything up — failures stay as one inline line.
  Future<void> _useCameraRoom() async {
    if (_camBusy || _over || !_show) return;
    final deal = _dealId;
    _hideTimer?.cancel();
    setState(() {
      _camBusy = true;
      _camError = '';
    });
    try {
      // Without cloud AI (no key or consent off) SAM never runs: say so
      // instead of the misleading 'no clear details' line.
      if (!await MetaAIService.cloudReady()) {
        if (!mounted || deal != _dealId || _over) return;
        setState(() {
          _camBusy = false;
          _camError = tr('bench_spatial_cam_off');
        });
        if (_show) _armHideTimer(deal);
        return;
      }
      final shot = await ImagePicker().pickImage(
        source: ImageSource.camera,
        maxWidth: 1024,
        imageQuality: 70,
      );
      if (!mounted || deal != _dealId || _over) return;
      if (shot == null) {
        setState(() => _camBusy = false);
        if (_show) _armHideTimer(deal);
        return;
      }
      final bytes = await shot.readAsBytes();
      if (!mounted || deal != _dealId || _over) return;
      setState(() => _camBytes = bytes);
      final seg = await MetaAIService.segment(
        MetaSegmentRequest(
          imageRef: 'data:image/jpeg;base64,${base64Encode(bytes)}',
        ),
      );
      if (!mounted || deal != _dealId || _over || !_show) return;
      if (seg.labels.isEmpty) {
        setState(() {
          _camBusy = false;
          _camError = tr('bench_spatial_cam_empty');
        });
        _armHideTimer(deal);
        return;
      }
      setState(() {
        _stationList = stationsFromLabels(
          seg.labels,
          'cam:${DateTime.now().millisecondsSinceEpoch}',
          _stations,
          AppLocalizations.localeCode,
        );
        _camBusy = false;
      });
      unawaited(_refreshWonder());
      _armHideTimer(deal);
    } catch (_) {
      if (!mounted || deal != _dealId) return;
      setState(() {
        _camBusy = false;
        _camError = tr('bench_spatial_cam_fail');
      });
      if (_show && !_over) _armHideTimer(deal);
    }
  }

  void _pick(String v) {
    if (_show || _over) return;
    if (v == _words[_target]) {
      BenchmarkStore.submit(
        'spatial',
        _stations,
        higherIsBetter: true,
        xpGain: 8 + _stations * 3,
      );
      setState(() {
        if (_stations < SpatialGamePage.maxStations) _stations++;
        _deal();
      });
    } else {
      BenchmarkStore.submit(
        'spatial',
        _stations - 1,
        higherIsBetter: true,
        xpGain: 5,
      );
      setState(() => _over = true);
    }
  }

  Widget _wonderBox(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: context.cardBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: context.hairline, width: 2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            tr('bench_wonder_title'),
            style: TextStyle(
              color: context.mutedText,
              fontWeight: FontWeight.w900,
              fontSize: 11,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 6),
          if (_wonderLoading && _wonder.isEmpty)
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: context.mutedText,
                  ),
                ),
              ],
            )
          else
            for (var i = 0; i < _wonder.length; i++)
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text(
                  '${i + 1}. ${_wonder[i]}',
                  style: TextStyle(
                    color: context.inkText,
                    fontSize: 13,
                    height: 1.4,
                  ),
                ),
              ),
        ],
      ),
    );
  }

  Widget _cameraBox(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: context.cardBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: context.hairline, width: 2),
      ),
      child: Column(
        children: [
          if (_camBytes != null) ...[
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: Image.memory(
                _camBytes!,
                height: 120,
                width: double.infinity,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stack) =>
                    const SizedBox.shrink(),
              ),
            ),
            const SizedBox(height: 8),
          ],
          if (_camBusy)
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: context.mutedText,
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  tr('bench_spatial_cam_busy'),
                  style: TextStyle(color: context.mutedText, fontSize: 13),
                ),
              ],
            )
          else
            GestureDetector(
              onTap: _useCameraRoom,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: coral, width: 2),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const HugeIcon(
                      icon: HugeIcons.strokeRoundedCamera01,
                      color: coral,
                      size: 22,
                      strokeWidth: 2.0,
                    ),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        tr('bench_spatial_camera'),
                        style: const TextStyle(
                          color: coral,
                          fontWeight: FontWeight.w900,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          if (_camError.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              _camError,
              textAlign: TextAlign.center,
              style: TextStyle(color: context.mutedText, fontSize: 12),
            ),
          ],
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return _gameScaffold(
      context: context,
      title: tr('bench_game_spatial_title'),
      counter: tr('bench_stations_n', {'n': _stations}),
      aiModels: 'Muse Spark • Muse Image • SAM 3.1 • Wonder • Camera',
      aiLive: _taskLive || _wonderLive,
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
        children: [
          if (_over) ...[
            _resultBox(
              context,
              title: tr('bench_spatial_done_title', {'n': _stations - 1}),
              detail: tr('bench_spatial_done_detail'),
              onRetry: () => setState(() {
                _stations = SpatialGamePage.minStations;
                _over = false;
                _deal();
              }),
              retryLabel: tr('bench_restart'),
            ),
            _TransferCard('spatial'),
            _AiTip(gameId: 'spatial', level: _stations - 1),
            _AiVerdict(gameId: 'spatial', score: _stations - 1),
          ] else if (_show) ...[
            Text(
              tr('bench_spatial_memorize'),
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurface,
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              _palaceLine ??
                  tr('bench_spatial_palace', {
                    'route': _route,
                    'n': _stationList.length,
                  }),
              style: TextStyle(color: context.mutedText, fontSize: 13),
            ),
            if (_palaceImage.isNotEmpty) ...[
              const SizedBox(height: 12),
              ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Image.network(
                  _palaceImage,
                  height: 170,
                  width: double.infinity,
                  fit: BoxFit.cover,
                  cacheWidth: 800,
                  loadingBuilder: (context, child, progress) {
                    if (progress == null) return child;
                    return const SizedBox(
                      height: 170,
                      child: Center(
                        child: SizedBox(
                          width: 28,
                          height: 28,
                          child: CircularProgressIndicator(strokeWidth: 3),
                        ),
                      ),
                    );
                  },
                  errorBuilder: (context, error, stack) =>
                      const SizedBox.shrink(),
                ),
              ),
            ],
            const SizedBox(height: 12),
            for (var i = 0; i < _stationList.length; i++)
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
                    '${_stationList[i]} → ${_words[i]}',
                    style: TextStyle(
                      color: context.inkText,
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                    ),
                  ),
                ),
              ),
            const SizedBox(height: 4),
            _wonderBox(context),
            const SizedBox(height: 8),
            _cameraBox(context),
            const SizedBox(height: 8),
            _bigButton(
              context,
              label: tr('bench_spatial_gotit'),
              color: coral,
              onTap: () => setState(() => _show = false),
            ),
          ] else ...[
            Text(
              tr('bench_spatial_q', {'station': _stationList[_target]}),
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurface,
                fontWeight: FontWeight.bold,
                fontSize: 18,
              ),
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
                      o,
                      style: TextStyle(
                        color: context.inkText,
                        fontWeight: FontWeight.bold,
                        fontSize: 22,
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
