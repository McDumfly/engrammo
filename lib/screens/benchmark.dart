import '../theme/app_theme.dart';

import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';

import '../widgets/ai_help_button.dart';
import '../widgets/app_buttons.dart';
import '../l10n/app_localizations.dart';
import '../models/meta_task.dart';
import '../models/palace_drill.dart'
    show
        allConcreteNounsFor,
        localPalaceTask,
        localPictureTask,
        palaceRoutesFor;
import '../services/app_feedback.dart';
import '../services/memory_store.dart';
import '../services/meta_ai_service.dart';
import 'benchmark_stats.dart' show BenchmarkDetailPage;
import 'memory_profile.dart' show violet, violetDark, teal, amber, coral, sky;

final _rnd = Random();

class BenchmarkStore {
  static final Map<String, int> best = {};
  static final Map<String, List<int>> attempts = {};
  static int xp = 0;
  static int plays = 0;
  static bool bonusClaimed = false;
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
    } catch (_) {}
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
    _loading = null;
    _persistQueue = Future.value();
  }
}

class BenchmarkMeta {
  static Future<String> numberStimulus(int digits) async {
    try {
      final task = await MetaAIService.generateTask(
        MetaTaskRequest(kind: 'number', difficulty: digits.clamp(1, 9)),
      );
      if (!task.fallback && task.items.isNotEmpty) return task.items.first;
    } catch (_) {
    }
    return NumberGamePage.make(digits);
  }

  static Future<String> wordStimulus([String locale = 'en']) async {
    try {
      final task = await MetaAIService.generateTask(
        MetaTaskRequest(kind: 'verbal', difficulty: 2, locale: locale),
      );
      if (!task.fallback && task.items.isNotEmpty) return task.items.first;
    } catch (_) {
    }
    return VerbalGamePage.pickFresh(locale);
  }

  static Future<List<int>> sequenceStimulus(int length) async {
    try {
      final task = await MetaAIService.generateTask(
        MetaTaskRequest(kind: 'sequence', difficulty: length.clamp(1, 5)),
      );
      if (!task.fallback && task.items.isNotEmpty) {
        return [for (final e in task.items) int.tryParse(e) ?? 0];
      }
    } catch (_) {
    }
    return SequenceGamePage.make(length);
  }

  static Future<Set<int>> visualPattern(int size, int count) async {
    try {
      final task = await MetaAIService.generateTask(
        const MetaTaskRequest(kind: 'pattern', difficulty: 2),
      );
      if (!task.fallback && task.items.isNotEmpty) {
        final cells = <int>{};
        for (final e in task.items) {
          final v = int.tryParse(e);
          if (v != null && v >= 0 && v < size) cells.add(v);
        }
        if (cells.isNotEmpty) return cells;
      }
    } catch (_) {
    }
    return VisualGamePage.makePattern(size, count);
  }

  /// Picture-recall round: a unique Muse Image illustration plus SAM-spotted
  /// details. Offline this is just the local picture task (no image).
  static Future<MetaTask> pictureRound({
    required String seed,
    int difficulty = 2,
    String locale = 'en',
  }) async {
    final base = localPictureTask(
      difficulty: difficulty,
      seed: seed,
      locale: locale,
    );
    try {
      return await MetaAIService.enrichVisualTask(base, seed: seed);
    } catch (_) {
      return base;
    }
  }

  /// Spatial practice round: palace illustration plus SAM loci stations.
  /// Offline this is just the local palace task (no image).
  static Future<MetaTask> spatialRound({
    required String seed,
    required int stations,
    String locale = 'en',
  }) async {
    final difficulty = (stations - 3).clamp(1, 5);
    final base = localPalaceTask(
      difficulty: difficulty,
      seed: seed,
      locale: locale,
    );
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
  late final Future<CoachAnswer> _future = MetaAIService.practiceTip(
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
              Text(
                tr('ai_tip_title'),
                style: TextStyle(
                  color: context.mutedText,
                  fontWeight: FontWeight.w900,
                  fontSize: 11,
                  letterSpacing: 1.2,
                ),
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
    tint: violet,
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
    tint: violetDark,
    build: () => const VisualGamePage(),
  ),
  _GameDef(
    id: 'order',
    icon: HugeIcons.strokeRoundedBrain01,
    tint: amber,
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
          child: Center(
            child: AiHelpButton(topic: AiHelpTopics.benchmark),
          ),
        ),
      ],
    ),
    body: body,
  );
}

Widget _bigButton(
  BuildContext context, {
  required String label,
  required VoidCallback? onTap,
  Color color = violet,
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
          border: Border.all(color: amber, width: 2),
        ),
        child: Column(
          children: [
            HugeIcon(
              icon: HugeIcons.strokeRoundedTrophy,
              color: amber,
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

  @override
  void initState() {
    super.initState();
    _nextRound();
  }

  void _nextRound() {
    final ai = _aiNext;
    _aiNext = null;
    setState(() {
      _busy = true;
      _over = false;
      _seq.add(ai ?? _rnd.nextInt(9));
      _input = 0;
      _level = _seq.length;
    });
    _play();
    unawaited(_prefetchNext());
  }

  Future<void> _prefetchNext() async {
    try {
      final s = await BenchmarkMeta.sequenceStimulus(1);
      if (s.isNotEmpty && mounted && !_over) _aiNext = s.first % 9;
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
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
        children: [
          if (_over) ...[
            _resultBox(
              context,
              title: tr('bench_seq_done_title'),
              detail: tr('bench_seq_done_detail', {
                'n': _seq.length - 1,
              }),
              onRetry: () => setState(() {
                _seq.clear();
                _nextRound();
              }),
              retryLabel: tr('bench_retry_xp'),
            ),
            _AiTip(gameId: 'sequence', level: _seq.length - 1),
          ]
          else ...[
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
                      color: lit ? amber : context.cardBg,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: lit ? amber : context.hairline,
                        width: 2,
                      ),
                      boxShadow: lit
                          ? [
                              BoxShadow(
                                color: amber.withValues(alpha: 0.5),
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
              valueColor: const AlwaysStoppedAnimation(violet),
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
    _aiNext = null;
    final cleaned = (ai ?? '').replaceAll(RegExp('[^0-9]'), '');
    _number = cleaned.length >= _digits
        ? cleaned.substring(0, _digits)
        : _make(_digits);
    final set = <String>{_number};
    while (set.length < 4) {
      final d = _make(_digits);
      set.add(d);
    }
    _options = set.toList()..shuffle();
    _show = true;
    Future.delayed(const Duration(milliseconds: 2500), () {
      if (mounted && _show && !_over) setState(() => _show = false);
    });
    unawaited(_prefetchNext());
  }

  Future<void> _prefetchNext() async {
    try {
      final s = await BenchmarkMeta.numberStimulus(_digits + 1);
      if (mounted && !_over) _aiNext = s;
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
            _AiTip(gameId: 'number', level: _digits - 1),
          ]
          else if (_show) ...[
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

List<String> _wordPoolFor(String locale) =>
    locale == 'hu' ? _wordPoolHu : _wordPool;

class VerbalGamePage extends StatefulWidget {
  const VerbalGamePage({super.key});

  static String pickFresh([String locale = 'en']) {
    final pool = _wordPoolFor(locale);
    return pool[_rnd.nextInt(pool.length)];
  }

  @override
  State<VerbalGamePage> createState() => _VerbalGamePageState();
}

class _VerbalGamePageState extends State<VerbalGamePage> {
  final Set<String> _seen = {};
  late final List<String> _fresh;
  late final List<String> _pool;
  String _word = '';
  int _score = 0;
  int _lives = 3;
  bool _over = false;
  String? _aiNext;

  @override
  void initState() {
    super.initState();
    _pool = _wordPoolFor(AppLocalizations.localeCode);
    _fresh = List.of(_pool)..shuffle();
    _next();
  }

  void _next() {
    String w;
    final ai = _aiNext;
    _aiNext = null;
    final aiOk =
        ai != null &&
        ai.trim().length >= 2 &&
        ai.trim().length <= 24 &&
        !ai.contains(' ') &&
        !_seen.contains(ai.trim()) &&
        !_fresh.contains(ai.trim());
    if (_seen.isNotEmpty && _rnd.nextDouble() < 0.35) {
      w = _seen.elementAt(_rnd.nextInt(_seen.length));
    } else if (aiOk) {
      w = ai.trim();
    } else if (_fresh.isNotEmpty) {
      w = _fresh.removeLast();
    } else {
      w = _pool[_rnd.nextInt(_pool.length)];
    }
    setState(() => _word = w);
    unawaited(_prefetchWord());
  }

  Future<void> _prefetchWord() async {
    try {
      final s = await BenchmarkMeta.wordStimulus(AppLocalizations.localeCode);
      if (mounted && !_over) _aiNext = s;
    } catch (_) {}
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
      counter: tr('bench_verbal_counter', {
        'score': _score,
        'lives': _lives,
      }),
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
                _score = 0;
                _lives = 3;
                _over = false;
                _next();
              }),
              retryLabel: tr('bench_verbal_retry'),
            ),
            _AiTip(gameId: 'verbal', level: _score),
          ]
          else ...[
            Row(
              children: [
                for (var i = 0; i < 3; i++)
                  Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: HugeIcon(
                      icon: HugeIcons.strokeRoundedFavourite,
                      color: i < _lives ? coral : context.hairline,
                      size: 24,
                      strokeWidth: 2.2,
                    ),
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
              child: Text(
                _word,
                style: TextStyle(
                  fontSize: 40,
                  fontWeight: FontWeight.bold,
                  color: context.inkText,
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
  Set<int>? _aiPattern;
  int _aiPatternSize = 0;
  MetaTask? _aiRound;
  bool _aiLoading = false;
  int _aiDealId = 0;

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
    if (ai != null && _aiPatternSize == _size && ai.length == count) {
      _pattern = Set.of(ai);
    } else {
      _pattern = {};
      while (_pattern.length < count) {
        _pattern.add(_rnd.nextInt(_size));
      }
    }
    _aiPattern = null;
    _aiRound = null;
    _aiLoading = false;
    _picked = {};
    _show = true;
    Future.delayed(const Duration(milliseconds: 2200), () {
      if (mounted && _show && !_over && _aiRound == null) {
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
      final p = await BenchmarkMeta.visualPattern(size, count);
      if (mounted && !_over && p.length == count) {
        _aiPattern = p;
        _aiPatternSize = size;
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
            _AiTip(gameId: 'visual', level: _level - 1),
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
                      color: on ? violet : context.cardBg,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: on ? violet : context.hairline,
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

  @override
  void initState() {
    super.initState();
    _deal();
  }

  void _deal() {
    final all = List.generate(12, (i) => i)..shuffle();
    _cells = all.take(_count).toList();
    _next = 1;
    _hidden = false;
    _over = false;
    setState(() {});
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
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
        children: [
          if (_over) ...[
            _resultBox(
              context,
              title: tr('bench_order_done_title', {'n': _count - 1}),
              detail: _count >= 7
                  ? tr('bench_order_hi')
                  : tr('bench_order_lo'),
              onRetry: () => setState(() {
                _count = 3;
                _deal();
              }),
              retryLabel: tr('bench_order_retry'),
            ),
            _AiTip(gameId: 'order', level: _count - 1),
          ]
          else ...[
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
                          : violet,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: filled ? violet : context.hairline,
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
    _options = SpatialGamePage.makeOptions(_words[_target], _words, null, locale);
    _show = true;
    _palaceImage = '';
    _palaceLine = null;
    final ms = 2500 + _stations * 900;
    _hideTimer = Timer(Duration(milliseconds: ms), () {
      if (mounted && _show && !_over && id == _dealId) {
        setState(() => _show = false);
      }
    });
    unawaited(_upgradeSpatial(id, _stations, locale));
  }

  Future<void> _upgradeSpatial(int id, int stations, String locale) async {
    MetaTask task;
    try {
      task = await BenchmarkMeta.spatialRound(
        seed: 'bench:spatial:$stations:${DateTime.now().millisecondsSinceEpoch}',
        stations: stations,
        locale: locale,
      );
    } catch (_) {
      return;
    }
    if (!mounted || id != _dealId || _over) return;
    if (task.fallback && task.imageUrl.isEmpty) return;
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
    });
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

  @override
  Widget build(BuildContext context) {
    return _gameScaffold(
      context: context,
      title: tr('bench_game_spatial_title'),
      counter: tr('bench_stations_n', {'n': _stations}),
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
            _AiTip(gameId: 'spatial', level: _stations - 1),
          ]
          else if (_show) ...[
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
            _bigButton(
              context,
              label: tr('bench_spatial_gotit'),
              color: coral,
              onTap: () => setState(() => _show = false),
            ),
          ] else ...[
            Text(
              tr('bench_spatial_q', {
                'station': _stationList[_target],
              }),
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
