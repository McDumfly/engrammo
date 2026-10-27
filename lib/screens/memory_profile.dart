import '../theme/app_theme.dart';
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';

import '../widgets/app_buttons.dart';
import '../services/app_feedback.dart';
import '../models/collectibles.dart' show engram;
import '../models/meta_task.dart';
import '../services/memory_store.dart';
import '../services/meta_ai_service.dart';

class MemoryKind {
  final String name;
  final String module;
  final List<List<dynamic>> icon;
  final Color tint;
  const MemoryKind(this.name, this.module, this.icon, this.tint);
}

const paper = Color(0xFFFFFFFF);
const ink = Color(0xFF22314A);
const muted = Color(0xFF8494AB);
const line = Color(0xFFDEE9F7);
const violet = Color(0xFF45A3FF);
const violetDark = Color(0xFF1F6FC4);
const teal = Color(0xFF14B8A6);
const tealDark = Color(0xFF0B7E72);
const amber = Color(0xFFFF9500);
const coral = Color(0xFFFF6B6B);
const sky = Color(0xFF8FCBFF);
const trail = Color(0xFFC7E4FF);

const memoryKinds = [
  MemoryKind(
    'Sensory',
    'Audio flash and attention focus',
    HugeIcons.strokeRoundedAudioWave01,
    sky,
  ),
  MemoryKind(
    'Working memory',
    'Chunking forge',
    HugeIcons.strokeRoundedLayers01,
    violet,
  ),
  MemoryKind(
    'Spatial',
    'Palace builder',
    HugeIcons.strokeRoundedCastle01,
    teal,
  ),
  MemoryKind(
    'Visual',
    'Imagery lab',
    HugeIcons.strokeRoundedEye,
    amber,
  ),
  MemoryKind(
    'Episodic',
    'Journal and loci walk',
    HugeIcons.strokeRoundedNotebook01,
    coral,
  ),
  MemoryKind(
    'Semantic',
    'Names, faces and vocabulary',
    HugeIcons.strokeRoundedBrain01,
    violetDark,
  ),
];

class _Task {
  final int kind;
  final String stimulusTitle;
  final Widget stimulus;
  final String question;
  final List<String> options;
  final int correct;
  const _Task({
    required this.kind,
    required this.stimulusTitle,
    required this.stimulus,
    required this.question,
    required this.options,
    required this.correct,
  });
}

Widget _stimulusBox(BuildContext context, {required Widget child}) {
  return Container(
    width: double.infinity,
    padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 16),
    decoration: BoxDecoration(
      color: context.cardBg,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: context.hairline, width: 2),
    ),
    alignment: Alignment.center,
    child: child,
  );
}

List<_Task> _buildTasks(BuildContext context) {
  return [
    _Task(
      kind: 0,
      stimulusTitle: 'Memorize this digit sequence!',
      stimulus: _stimulusBox(context,
        child: Text(
          '7   3   9',
          style: TextStyle(
            fontSize: 40,
            fontWeight: FontWeight.bold,
            color: context.inkText,
            letterSpacing: 4,
          ),
        ),
      ),
      question: 'What was the middle digit?',
      options: const ['5', '3', '7', '9'],
      correct: 1,
    ),
    _Task(
      kind: 1,
      stimulusTitle: 'Hold it in mind, then reverse it!',
      stimulus: _stimulusBox(context,
        child: Text(
          '4   1   8',
          style: TextStyle(
            fontSize: 40,
            fontWeight: FontWeight.bold,
            color: context.inkText,
            letterSpacing: 4,
          ),
        ),
      ),
      question: 'What is the order reversed?',
      options: const ['4-1-8', '8-4-1', '8-1-4', '1-8-4'],
      correct: 2,
    ),
    _Task(
      kind: 2,
      stimulusTitle: 'Remember: which tile lit up?',
      stimulus: _stimulusBox(context,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    color: teal,
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    color: context.hairline,
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ],
            ),
            const SizedBox(width: 8),
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    color: context.hairline,
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    color: context.hairline,
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
      question: 'Which tile lit up?',
      options: const ['Top left', 'Top right', 'Bottom left', 'Bottom right'],
      correct: 0,
    ),
    _Task(
      kind: 3,
      stimulusTitle: 'Memorize the three colors!',
      stimulus: _stimulusBox(context,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: const BoxDecoration(
                color: violet,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 12),
            Container(
              width: 52,
              height: 52,
              decoration: const BoxDecoration(
                color: teal,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 12),
            Container(
              width: 52,
              height: 52,
              decoration: const BoxDecoration(
                color: amber,
                shape: BoxShape.circle,
              ),
            ),
          ],
        ),
      ),
      question: 'Which color was NOT among them?',
      options: const ['Purple', 'Green', 'Yellow', 'Red'],
      correct: 3,
    ),
    _Task(
      kind: 4,
      stimulusTitle: 'Read carefully, just once!',
      stimulus: _stimulusBox(context,
        child: Text(
          'Yesterday Anna bought 3 apples and a blue scarf at the market.',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 18, color: context.inkText, height: 1.4),
        ),
      ),
      question: 'What did Anna buy besides the scarf?',
      options: const [
        '2 pears',
        '3 apples',
        '1 hat',
        'A basket',
      ],
      correct: 1,
    ),
    _Task(
      kind: 5,
      stimulusTitle: 'Think about the meaning!',
      stimulus: _stimulusBox(context,
        child: Text(
          'Fruits',
          style: TextStyle(
            fontSize: 32,
            fontWeight: FontWeight.bold,
            color: context.inkText,
          ),
        ),
      ),
      question: 'Which one is a fruit?',
      options: const ['Carrot', 'Apple', 'Potato', 'Onion'],
      correct: 1,
    ),
  ];
}

/// Meta-feladat leképezése a szintmérő `_Task` alakjára.
///
/// A helyi `_buildTasks` marad az offline tartalék; ez csak akkor fut,
/// ha a `MetaAIService.generateTask` élő (nem-fallback) választ adott.
// ignore: library_private_types_in_public_api
_Task metaTaskToAssessmentTask(
  BuildContext context,
  MetaTask task,
  int kind,
) {
  final correct = task.correct.clamp(0, task.options.length - 1);
  return _Task(
    kind: kind,
    stimulusTitle: task.prompt.isEmpty ? 'Figyelj!' : task.prompt,
    stimulus: _stimulusBox(
      context,
      child: Text(
        task.items.isEmpty ? '···' : task.items.join('   '),
        textAlign: TextAlign.center,
        style: TextStyle(
          fontSize: 32,
          fontWeight: FontWeight.bold,
          color: context.inkText,
          letterSpacing: 3,
        ),
      ),
    ),
    question: task.question.isEmpty ? 'Mi volt a helyes?' : task.question,
    options:
        task.options.isEmpty ? const ['···'] : List<String>.of(task.options),
    correct: task.options.isEmpty ? 0 : correct,
  );
}

/// Szintmérő-feladatok Meta-forrásból, helyi tartalékkal.
///
/// Sorrend: sensory, working, spatial, visual, episodic, semantic.
/// Minden fajtára egy `MetaAIService.generateTask` hívás fut; ahol a
/// válasz `fallback`, ott a mai `_buildTasks` adott eleme marad.
// ignore: library_private_types_in_public_api
Future<List<_Task>> loadAssessmentTasks(BuildContext context) async {
  const kinds = ['sensory', 'working', 'spatial', 'visual', 'episodic', 'semantic'];
  // A contextet csak itt, az await-ek előtt használjuk: a helyi
  // tartalék most épül fel, az élő találatokat utána képezzük le.
  final local = _buildTasks(context);
  final kindsForTask = [
    for (var i = 0; i < local.length; i++) kinds[i % kinds.length],
  ];
  final fetched = <MetaTask?>[];
  for (final kind in kindsForTask) {
    try {
      fetched.add(
        await MetaAIService.generateTask(
          MetaTaskRequest(kind: kind, difficulty: 2),
        ),
      );
    } catch (_) {
      fetched.add(null);
    }
  }
  final out = <_Task>[];
  for (var i = 0; i < local.length; i++) {
    final task = fetched[i];
    if (task == null || task.fallback) {
      out.add(local[i]);
    } else {
      // ignore: use_build_context_synchronously
      out.add(metaTaskToAssessmentTask(context, task, local[i].kind));
    }
  }
  return out;
}

class MemoryAssessmentPage extends StatefulWidget {
  const MemoryAssessmentPage({super.key});

  @override
  State<MemoryAssessmentPage> createState() => _MemoryAssessmentPageState();
}

class _MemoryAssessmentPageState extends State<MemoryAssessmentPage> {
  @override
  void initState() {
    super.initState();
    // Best-effort élő Meta-hívás a szintmérő képernyőn: a válasz
    // naplózódik (`MetaAIService.lastCalls`), a UI addig is a helyi
    // `_buildTasks` tartalékkal rajzol, így offline sem törik meg.
    unawaited(
      MetaAIService.generateTask(
        const MetaTaskRequest(kind: 'sensory', difficulty: 2),
      ),
    );
  }

  List<_Task> get _tasks => _buildTasks(context);
  int _step = 0;
  bool _revealed = false;
  final List<int> _scores = List.filled(6, 0);
  int? _picked;
  int _xp = 0;
  int _combo = 0;
  int _lastGain = 0;
  bool _lastGood = false;

  void _answer(int option) {
    if (_picked != null) return;
    final task = _tasks[_step];
    final good = option == task.correct;
    final gain = good ? 20 + (_combo >= 1 ? 10 : 0) + (_combo >= 3 ? 10 : 0) : 0;
    setState(() {
      _picked = option;
      _scores[task.kind] = good ? 100 : 20;
      _lastGain = gain;
      _lastGood = good;
      if (good) {
        _combo++;
        _xp += gain;
      } else {
        _combo = 0;
      }
    });
    Future.delayed(const Duration(milliseconds: 750), () {
      if (!mounted) return;
      if (_step + 1 < _tasks.length) {
        setState(() {
          _step++;
          _revealed = false;
          _picked = null;
        });
      } else {
        // Remember the profile locally so Battle Zone can default
        // the game mode to the user's strongest memory type.
        unawaited(MemoryStore.saveScores(List.of(_scores)));
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (_) =>
                MemoryResultPage(scores: List.of(_scores), xp: _xp),
          ),
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final task = _tasks[_step];
    final kind = memoryKinds[task.kind];
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: const EngramBackButton(),
        title: Text(
          'Memory assessment ${_step + 1}/${_tasks.length}',
          style: TextStyle(
            color: Theme.of(context).colorScheme.onSurface,
            fontWeight: FontWeight.bold,
            fontSize: 17,
          ),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(6),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(99),
              child: LinearProgressIndicator(
                value: (_step) / _tasks.length,
                minHeight: 6,
                backgroundColor: context.hairline,
                valueColor: const AlwaysStoppedAnimation(violet),
              ),
            ),
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: kind.tint.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(12),
                ),
                alignment: Alignment.center,
                child: HugeIcon(
                  icon: kind.icon,
                  color: kind.tint,
                  size: 24,
                  strokeWidth: 2.0,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      kind.name,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurface,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    Text(
                      kind.module,
                      style: TextStyle(color: context.mutedText, fontSize: 13),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: amber.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(99),
                  border: Border.all(color: amber, width: 1.5),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    HugeIcon(
                      icon: engram.icon,
                      color: engram.color,
                      size: 16,
                      strokeWidth: 2.4,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '$_xp engrams',
                      style: TextStyle(
                        color: context.inkText,
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              if (_combo >= 2)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: violet.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(99),
                    border: Border.all(color: violet, width: 1.5),
                  ),
                  child: Text(
                    'Combo x$_combo',
                    style: TextStyle(
                      color: violetDark,
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                )
              else
                Text(
                  'Every correct answer earns XP',
                  style: TextStyle(color: context.mutedText, fontSize: 12),
                ),
            ],
          ),
          const SizedBox(height: 16),
          if (!_revealed) ...[
            Text(
              task.stimulusTitle,
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurface,
                fontWeight: FontWeight.bold,
                fontSize: 18,
              ),
            ),
            const SizedBox(height: 12),
            task.stimulus,
            const SizedBox(height: 16),
            GestureDetector(
              onTap: () {
                AppFeedback.light();
                setState(() => _revealed = true);
              },
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 14),
                decoration: BoxDecoration(
                  color: violet,
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: const [
                    BoxShadow(color: violetDark, offset: Offset(0, 4)),
                  ],
                ),
                alignment: Alignment.center,
                child: const Text(
                  'CONTINUE TO QUESTION',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                    letterSpacing: 1,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'The prompt disappears — answer from memory!',
              textAlign: TextAlign.center,
              style: TextStyle(color: context.mutedText, fontSize: 13),
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
            const SizedBox(height: 12),
            for (var i = 0; i < task.options.length; i++)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: GestureDetector(
                  onTap: () => _answer(i),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 13,
                    ),
                    decoration: BoxDecoration(
                      color: _picked == null
                          ? context.cardBg
                          : i == task.correct
                              ? teal.withValues(alpha: 0.14)
                              : (i == _picked
                                  ? coral.withValues(alpha: 0.12)
                                  : context.cardBg),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: _picked != null && i == task.correct
                            ? teal
                            : context.hairline,
                        width: 2,
                      ),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            task.options[i],
                            style: TextStyle(
                              color: context.inkText,
                              fontWeight: FontWeight.w600,
                              fontSize: 15,
                            ),
                          ),
                        ),
                        if (_picked != null && i == task.correct)
                          const HugeIcon(
                            icon: HugeIcons
                                .strokeRoundedCheckmarkCircle02,
                            color: teal,
                            size: 22,
                            strokeWidth: 2.2,
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            if (_picked != null)
              Container(
                margin: const EdgeInsets.only(top: 4),
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: _lastGood
                      ? amber.withValues(alpha: 0.16)
                      : context.cardBg,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: _lastGood ? amber : context.hairline,
                    width: 2,
                  ),
                ),
                child: Row(
                  children: [
                    HugeIcon(
                      icon: _lastGood
                          ? engram.icon
                          : HugeIcons.strokeRoundedRefresh,
                      color: _lastGood ? engram.color : context.mutedText,
                      size: 20,
                      strokeWidth: 2.2,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _lastGood
                            ? (_combo >= 3
                                ? 'Engram sealed! Combo x$_combo, +$_lastGain'
                                : 'Nice! +$_lastGain engrams')
                            : 'No worries — the next one is worth double engrams!',
                        style: TextStyle(
                          color: context.inkText,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ],
      ),
    );
  }
}

class MemoryResultPage extends StatelessWidget {
  final List<int> scores;
  final int xp;
  const MemoryResultPage({super.key, required this.scores, this.xp = 0});

  @override
  Widget build(BuildContext context) {
    var best = 0;
    for (var i = 1; i < scores.length; i++) {
      if (scores[i] > scores[best]) best = i;
    }
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: const EngramBackButton(),
        title: Text(
          'Memory profile',
          style: TextStyle(
            color: Theme.of(context).colorScheme.onSurface,
            fontWeight: FontWeight.bold,
            fontSize: 17,
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: violet,
              borderRadius: BorderRadius.circular(16),
              boxShadow: const [
                BoxShadow(color: violetDark, offset: Offset(0, 4)),
              ],
            ),
            child: Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: context.cardBg.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  alignment: Alignment.center,
                  child: HugeIcon(
                    icon: memoryKinds[best].icon,
                    color: Colors.white,
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
                        'Strongest: ${memoryKinds[best].name}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 17,
                        ),
                      ),
                      Text(
                        memoryKinds[best].module,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.85),
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
                Text(
                  '${scores[best]}%',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 20,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: context.cardBg,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: amber, width: 2),
            ),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: amber.withValues(alpha: 0.16),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  alignment: Alignment.center,
                  child: HugeIcon(
                    icon: engram.icon,
                    color: engram.color,
                    size: 24,
                    strokeWidth: 2.2,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Engrams earned: $xp',
                        style: TextStyle(
                          color: context.inkText,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      Text(
                        'Come back tomorrow for a +10 bonus.',
                        style: TextStyle(color: context.mutedText, fontSize: 13),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          for (var i = 0; i < memoryKinds.length; i++) ...[
            _ScoreRow(kind: memoryKinds[i], score: scores[i]),
            const SizedBox(height: 10),
          ],
          const SizedBox(height: 8),
          GestureDetector(
            onTap: () {
              AppFeedback.light();
              Navigator.of(context).pushReplacement(
                MaterialPageRoute(
                  builder: (_) => const MemoryAssessmentPage(),
                ),
              );
            },
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 14),
              decoration: BoxDecoration(
                color: context.cardBg,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: context.hairline, width: 2),
              ),
              alignment: Alignment.center,
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  HugeIcon(
                    icon: HugeIcons.strokeRoundedRefresh,
                    color: violet,
                    size: 20,
                    strokeWidth: 2.2,
                  ),
                  SizedBox(width: 8),
                  Text(
                    'RETAKE',
                    style: TextStyle(
                      color: violet,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ScoreRow extends StatelessWidget {
  final MemoryKind kind;
  final int score;
  const _ScoreRow({required this.kind, required this.score});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: context.cardBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: context.hairline, width: 2),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: kind.tint.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(12),
            ),
            alignment: Alignment.center,
            child: HugeIcon(
              icon: kind.icon,
              color: kind.tint,
              size: 24,
              strokeWidth: 2.0,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        kind.name,
                        style: TextStyle(
                          color: context.inkText,
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                        ),
                      ),
                    ),
                    Text(
                      '$score%',
                      style: TextStyle(
                        color: context.inkText,
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(99),
                  child: TweenAnimationBuilder<double>(
                    tween: Tween(begin: 0, end: score / 100),
                    duration: const Duration(milliseconds: 800),
                    builder: (context, value, _) {
                      return LinearProgressIndicator(
                        value: value,
                        minHeight: 10,
                        backgroundColor: context.faintBg,
                        valueColor: AlwaysStoppedAnimation(kind.tint),
                      );
                    },
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
