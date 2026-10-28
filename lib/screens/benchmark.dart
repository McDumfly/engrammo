import '../theme/app_theme.dart';

import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';

import '../widgets/app_buttons.dart';
import '../models/meta_task.dart';
import '../services/app_feedback.dart';
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
    if (list.length > 30) list.removeRange(0, list.length - 30);
    final prev = best[id];
    if (prev == null) {
      best[id] = score;
    } else if (higherIsBetter) {
      if (score > prev) best[id] = score;
    } else {
      if (score > 0 && score < prev) best[id] = score;
    }
  }

  static int get level => xp ~/ 120 + 1;
  static double get levelProgress => (xp % 120) / 120;
}

/// Meta-csatlakozók a négy helyi generátorhoz.
///
/// Mindegyik ugyanazt a mintát követi: egy `MetaAIService.generateTask`
/// hívás az adott `kind`-ra, siker esetén az élő tartalom, hiba vagy
/// `fallback` esetén a mai helyi generátor eredménye. A meglévő
/// játékoldalak változatlanok; ezeket az új kihívó- és napi feladatok
/// hívják majd.
class BenchmarkMeta {
  static Future<String> numberStimulus(int digits) async {
    try {
      final task = await MetaAIService.generateTask(
        MetaTaskRequest(kind: 'number', difficulty: digits.clamp(1, 9)),
      );
      if (!task.fallback && task.items.isNotEmpty) return task.items.first;
    } catch (_) {
      // Helyi tartalék alább.
    }
    return NumberGamePage.make(digits);
  }

  static Future<String> wordStimulus() async {
    try {
      final task = await MetaAIService.generateTask(
        const MetaTaskRequest(kind: 'verbal', difficulty: 2),
      );
      if (!task.fallback && task.items.isNotEmpty) return task.items.first;
    } catch (_) {
      // Helyi tartalék alább.
    }
    return VerbalGamePage.pickFresh();
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
      // Helyi tartalék alább.
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
      // Helyi tartalék alább.
    }
    return VisualGamePage.makePattern(size, count);
  }
}

class _GameDef {
  final String id;
  final String title;
  final String subtitle;
  final List<List<dynamic>> icon;
  final Color tint;
  final Widget Function() build;
  final String bestLabel;
  const _GameDef({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.tint,
    required this.build,
    required this.bestLabel,
  });
}

final _games = <_GameDef>[
  _GameDef(
    id: 'sequence',
    title: 'Sequence memory',
    subtitle: 'Repeat the flashing sequence!',
    icon: HugeIcons.strokeRoundedLayers01,
    tint: violet,
    build: () => const SequenceGamePage(),
    bestLabel: 'level',
  ),
  _GameDef(
    id: 'number',
    title: 'Number memory',
    subtitle: 'Memorize it, then pick it!',
    icon: HugeIcons.strokeRoundedHash,
    tint: sky,
    build: () => const NumberGamePage(),
    bestLabel: 'digits',
  ),
  _GameDef(
    id: 'verbal',
    title: 'Word memory',
    subtitle: 'Have you seen this word?',
    icon: HugeIcons.strokeRoundedNotebook01,
    tint: teal,
    build: () => const VerbalGamePage(),
    bestLabel: 'points',
  ),
  _GameDef(
    id: 'visual',
    title: 'Visual memory',
    subtitle: 'Redraw the pattern!',
    icon: HugeIcons.strokeRoundedEye,
    tint: violetDark,
    build: () => const VisualGamePage(),
    bestLabel: 'level',
  ),
  _GameDef(
    id: 'order',
    title: 'Number order',
    subtitle: 'Numbers in order, from memory!',
    icon: HugeIcons.strokeRoundedBrain01,
    tint: amber,
    build: () => const NumberOrderGamePage(),
    bestLabel: 'numbers',
  ),
];

class BenchmarkHubPage extends StatefulWidget {
  const BenchmarkHubPage({super.key});

  @override
  State<BenchmarkHubPage> createState() => _BenchmarkHubPageState();
}

class _BenchmarkHubPageState extends State<BenchmarkHubPage> {
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
            Text(
              'Test yourself',
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurface,
                fontWeight: FontWeight.bold,
                fontSize: 28,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Pick a challenge and beat your best!',
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
                        title: g.title,
                        subtitle: g.subtitle,
                        tint: g.tint,
                        bestLabel: g.bestLabel,
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
              'Tip: every game earns XP. Replay to beat your record!',
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
                    def.title,
                    style: TextStyle(
                      color: context.inkText,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  Text(
                    def.subtitle,
                    style: TextStyle(color: context.mutedText, fontSize: 13),
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  b == null ? '—' : '$b ${def.bestLabel}',
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
          padding: const EdgeInsets.only(right: 16),
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
      ],
    ),
    body: body,
  );
}

/// Nagy lapos pill gomb a benchmark-játékokhoz (az [EngramButton]
/// nyelvezetével, Stadium formával, 3D-sáv nélkül). A `color` a játék
/// saját színét őrzi (pl. teal SEEN) — a forma mindig ugyanaz.
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

  /// Helyi tartalék a Meta-híváshoz (tesztelhető, UI nélkül).
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

  @override
  void initState() {
    super.initState();
    _nextRound();
  }

  void _nextRound() {
    setState(() {
      _busy = true;
      _over = false;
      _seq.add(_rnd.nextInt(9));
      _input = 0;
      _level = _seq.length;
    });
    _play();
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
      title: 'Sequence memory',
      counter: 'Level $_level',
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
        children: [
          if (_over)
            _resultBox(
              context,
              title: 'Nice streak!',
              detail:
                  'You reached level ${_seq.length - 1}. One more run and you will climb even higher — +XP every round!',
              onRetry: () => setState(() {
                _seq.clear();
                _nextRound();
              }),
              retryLabel: 'RETRY (DOUBLE XP FEELING)',
            )
          else ...[
            Text(
              _busy
                  ? 'Watch the sequence… ($_level steps)'
                  : 'Your turn! Repeat the sequence.',
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

  /// Helyi tartalék a Meta-híváshoz (tesztelhető, UI nélkül).
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
    _number = _make(_digits);
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
      title: 'Number memory',
      counter: '$_digits digits',
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
        children: [
          if (_over)
            _resultBox(
              context,
              title: '${_digits - 1} digits!',
              detail: 'The human average is around 7. New round, new record — can you hit 8?',
              onRetry: () => setState(() {
                _digits = 3;
                _over = false;
                _deal();
              }),
              retryLabel: 'RESTART',
            )
          else if (_show) ...[
            Text(
              'Memorize it! It disappears in a few seconds.',
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
              label: 'GOT IT, SHOW THE QUESTION',
              onTap: () => setState(() => _show = false),
            ),
          ] else ...[
            Text(
              'Which number did you see?',
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

class VerbalGamePage extends StatefulWidget {
  const VerbalGamePage({super.key});

  /// Helyi tartalék a Meta-híváshoz (tesztelhető, UI nélkül).
  static String pickFresh() => _wordPool[_rnd.nextInt(_wordPool.length)];

  @override
  State<VerbalGamePage> createState() => _VerbalGamePageState();
}

class _VerbalGamePageState extends State<VerbalGamePage> {
  final Set<String> _seen = {};
  final List<String> _fresh = List.of(_wordPool)..shuffle();
  String _word = '';
  int _score = 0;
  int _lives = 3;
  bool _over = false;

  @override
  void initState() {
    super.initState();
    _next();
  }

  void _next() {
    String w;
    if (_seen.isNotEmpty && _rnd.nextDouble() < 0.35) {
      w = _seen.elementAt(_rnd.nextInt(_seen.length));
    } else if (_fresh.isNotEmpty) {
      w = _fresh.removeLast();
    } else {
      w = _wordPool[_rnd.nextInt(_wordPool.length)];
    }
    setState(() => _word = w);
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
      title: 'Word memory',
      counter: '$_score points • $_lives lives',
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
        children: [
          if (_over)
            _resultBox(
              context,
              title: '$_score points!',
              detail: _score >= 20
                  ? 'Phenomenal word memory! A new record is in sight?'
                  : _score >= 10
                  ? 'Nice! One more round and you will hit 20!'
                  : 'Good start! Watch out for words you already saw.',
              onRetry: () => setState(() {
                _seen.clear();
                _fresh
                  ..clear()
                  ..addAll(List.of(_wordPool)..shuffle());
                _score = 0;
                _lives = 3;
                _over = false;
                _next();
              }),
              retryLabel: 'RETRY WITH 3 LIVES',
            )
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
                  'Score: $_score',
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
                    label: 'SEEN',
                    color: teal,
                    onTap: () => _guess(true),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _bigButton(
                    context,
                    label: 'NEW WORD',
                    onTap: () => _guess(false),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              '3 mistakes and it\'s over. The longer you last, the more XP!',
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

  /// Helyi tartalék a Meta-híváshoz (tesztelhető, UI nélkül).
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

  int get _size => _level >= 4 ? 16 : 9;
  int get _cols => _level >= 4 ? 4 : 3;

  @override
  void initState() {
    super.initState();
    _deal();
  }

  void _deal() {
    final count = (_level + 2).clamp(3, _size - 1);
    _pattern = {};
    while (_pattern.length < count) {
      _pattern.add(_rnd.nextInt(_size));
    }
    _picked = {};
    _show = true;
    Future.delayed(const Duration(milliseconds: 2200), () {
      if (mounted && _show && !_over) setState(() => _show = false);
    });
    setState(() {});
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

  @override
  Widget build(BuildContext context) {
    return _gameScaffold(
      context: context,
      title: 'Visual memory',
      counter: 'Level $_level',
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
        children: [
          if (_over)
            _resultBox(
              context,
              title: 'Level ${_level - 1}!',
              detail: 'Redraw it from memory next time — the pattern keeps getting denser!',
              onRetry: () => setState(() {
                _level = 1;
                _over = false;
                _deal();
              }),
              retryLabel: 'RESTART',
            )
          else ...[
            Text(
              _show ? 'Memorize the pattern!' : 'Tap back the same tiles!',
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
              label: _show ? 'WATCH…' : 'CHECK',
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
      title: 'Number order',
      counter: '$_count numbers • next: $_next',
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
        children: [
          if (_over)
            _resultBox(
              context,
              title: '${_count - 1} numbers!',
              detail: _count >= 7
                  ? 'Excellent ordered recall — 7+ from memory is strong!'
                  : 'After the first tap everything disappears — trust your memory!',
              onRetry: () => setState(() {
                _count = 3;
                _deal();
              }),
              retryLabel: 'RETRY WITH 3 NUMBERS',
            )
          else ...[
            Text(
              'Tap in order from 1! After the first tap the numbers disappear.',
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
              'Tip: remember the positions, don\'t cram the numbers!',
              textAlign: TextAlign.center,
              style: TextStyle(color: context.mutedText, fontSize: 13),
            ),
          ],
        ],
      ),
    );
  }
}
