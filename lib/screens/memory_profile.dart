import '../theme/app_theme.dart';

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';

import '../widgets/app_buttons.dart';
import '../services/app_feedback.dart';
import '../models/assessment.dart'
    show
        assessmentColorChips,
        chipNotAmong,
        resolveDominant;
import '../models/collectibles.dart' show engram;
import '../models/memory_verdict.dart' show MemoryVerdict;
import '../services/memory_store.dart';
import 'assessment_interview.dart';

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
  MemoryKind('Visual', 'Imagery lab', HugeIcons.strokeRoundedEye, amber),
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
  final bool hard;
  final String stimulusTitle;
  final Widget stimulus;
  final String question;
  final List<String> options;
  final int correct;

  /// Validated paradigm this probe is modeled on (shown under the
  /// stimulus) and the study it comes from. Every probe traces to
  /// `docs/RESEARCH.md` section 3.
  final String paradigm;
  final String source;
  const _Task({
    required this.kind,
    this.hard = false,
    required this.stimulusTitle,
    required this.stimulus,
    required this.question,
    required this.options,
    required this.correct,
    this.paradigm = '',
    this.source = '',
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

/// Row of color chips built from [assessmentColorChips]: the same
/// entry paints the circle and names the option, so label and hue
/// can never mismatch again.
Widget _chipRow(BuildContext context, {required List<int> chipIndexes}) {
  return _stimulusBox(
    context,
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var k = 0; k < chipIndexes.length; k++)
          Container(
            width: chipIndexes.length > 3 ? 40 : 52,
            height: chipIndexes.length > 3 ? 40 : 52,
            margin: EdgeInsets.only(
              right: k + 1 < chipIndexes.length ? 12 : 0,
            ),
            decoration: BoxDecoration(
              color: Color(
                assessmentColorChips[chipIndexes[k]].argb,
              ),
              shape: BoxShape.circle,
            ),
          ),
      ],
    ),
  );
}

/// Fixed parallel assessment forms (matched difficulty, different
/// stimuli): Form A on even runs, Form B on odd runs, so retakes measure
/// memory rather than remembered answers (practice-effect control;
/// Woods et al. 2006). Fixed forms — never AI-generated probes — keep
/// scores comparable across runs and users.
List<_Task> _buildTasks(BuildContext context, {int form = 0}) {
  final b = form == 1;
  // Visual probes share one fixed chip set per form; the missing chip
  // is computed, never hand-written.
  final easyShown = b ? [1, 2, 3] : [0, 1, 2];
  final easyMissing = chipNotAmong(
    [for (final i in easyShown) assessmentColorChips[i]],
  );
  final hardShown = b ? [1, 2, 3, 4, 5] : [0, 1, 2, 3, 4];
  final hardMissing = chipNotAmong(
    [for (final i in hardShown) assessmentColorChips[i]],
  );
  return [
    _Task(
      kind: 0,
      stimulusTitle: 'Memorize this digit sequence!',
      stimulus: _stimulusBox(
        context,
        child: Text(
          b ? '5   1   8' : '7   3   9',
          style: TextStyle(
            fontSize: 40,
            fontWeight: FontWeight.bold,
            color: context.inkText,
            letterSpacing: 4,
          ),
        ),
      ),
      question: 'What was the middle digit?',
      options: b ? ['3', '1', '5', '8'] : ['5', '3', '7', '9'],
      correct: 1,
      paradigm: 'Echoic probe · 3 items, brief look',
      source: 'Peterson & Peterson 1959; Baddeley & Hitch 1974',
    ),
    _Task(
      kind: 0,
      hard: true,
      stimulusTitle: 'Five digits this time — hold them all!',
      stimulus: _stimulusBox(
        context,
        child: Text(
          b ? '9   3   6   2   7' : '2   8   4   9   1',
          style: TextStyle(
            fontSize: 36,
            fontWeight: FontWeight.bold,
            color: context.inkText,
            letterSpacing: 3,
          ),
        ),
      ),
      question: 'What was the 4th digit?',
      options: b ? ['3', '6', '2', '7'] : ['8', '4', '9', '1'],
      correct: 2,
      paradigm: 'Echoic probe · 5 items, brief look',
      source: 'Peterson & Peterson 1959; Cowan 2001',
    ),
    _Task(
      kind: 1,
      stimulusTitle: 'Hold it in mind, then reverse it!',
      stimulus: _stimulusBox(
        context,
        child: Text(
          b ? '9   2   6' : '4   1   8',
          style: TextStyle(
            fontSize: 40,
            fontWeight: FontWeight.bold,
            color: context.inkText,
            letterSpacing: 4,
          ),
        ),
      ),
      question: 'What is the order reversed?',
      options: b
          ? ['9-2-6', '6-9-2', '6-2-9', '2-6-9']
          : ['4-1-8', '8-4-1', '8-1-4', '1-8-4'],
      correct: 2,
      paradigm: 'Backward digit span · 3',
      source: 'WAIS digit span; Baddeley 1986',
    ),
    _Task(
      kind: 1,
      hard: true,
      stimulusTitle: 'Five digits — reverse all of them!',
      stimulus: _stimulusBox(
        context,
        child: Text(
          b ? '7   4   8   2   5' : '3   9   1   6   2',
          style: TextStyle(
            fontSize: 36,
            fontWeight: FontWeight.bold,
            color: context.inkText,
            letterSpacing: 3,
          ),
        ),
      ),
      question: 'What is the full order reversed?',
      options: b
          ? ['7-4-8-2-5', '5-4-8-2-7', '5-2-8-4-7', '2-5-7-4-8']
          : ['3-9-1-6-2', '2-9-1-6-3', '2-6-1-9-3', '6-2-3-9-1'],
      correct: 2,
      paradigm: 'Backward digit span · 5 (past the ~4 limit)',
      source: 'WAIS digit span; Cowan 2001',
    ),
    _Task(
      kind: 2,
      stimulusTitle: 'Remember: which tile lit up?',
      stimulus: _stimulusBox(
        context,
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
                    // Form A lights the top-left tile, Form B the
                    // bottom-right one (matched 1-location span).
                    color: b ? context.hairline : teal,
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
                    color: b ? teal : context.hairline,
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
      correct: b ? 3 : 0,
      paradigm: 'Spatial span · 1 location',
      source: 'Corsi 1972 block-tapping',
    ),
    _Task(
      kind: 2,
      hard: true,
      stimulusTitle: 'Two tiles this time — catch both!',
      stimulus: _stimulusBox(
        context,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (var col = 0; col < 3; col++)
              Padding(
                padding: EdgeInsets.only(left: col == 0 ? 0 : 8),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    for (var row = 0; row < 3; row++)
                      Container(
                        width: 44,
                        height: 44,
                        margin: EdgeInsets.only(top: row == 0 ? 0 : 8),
                        decoration: BoxDecoration(
                          // Form A: main diagonal; Form B: anti-diagonal
                          // (matched 2-location span).
                          color:
                              (b
                                  ? (row == 0 && col == 2) ||
                                        (row == 2 && col == 0)
                                  : (row == 0 && col == 0) ||
                                        (row == 2 && col == 2))
                              ? teal
                              : context.hairline,
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                  ],
                ),
              ),
          ],
        ),
      ),
      question: 'Which TWO tiles lit up?',
      options: [
        b ? 'Top-right + bottom-left' : 'Top-left + bottom-right',
        'Whole top row',
        'Whole left column',
        'Center + a corner',
      ],
      correct: 0,
      paradigm: 'Spatial span · 2 locations',
      source: 'Corsi 1972; Kessels et al. 2000',
    ),
    _Task(
      kind: 3,
      stimulusTitle: 'Memorize the three colors!',
      stimulus: _chipRow(context, chipIndexes: easyShown),
      question: 'Which color was NOT among them?',
      options: [
        assessmentColorChips[easyShown[0]].name,
        assessmentColorChips[easyShown[1]].name,
        assessmentColorChips[easyShown[2]].name,
        easyMissing.name,
      ],
      correct: 3,
      paradigm: 'Visual array · 3 colors',
      source: 'Luck & Vogel 1997 change detection',
    ),
    _Task(
      kind: 3,
      hard: true,
      stimulusTitle: 'Five colors — hold them all!',
      stimulus: _chipRow(context, chipIndexes: hardShown),
      question: 'Which color was NOT among them?',
      options: [
        assessmentColorChips[hardShown[4]].name,
        assessmentColorChips[hardShown[1]].name,
        hardMissing.name,
        assessmentColorChips[hardShown[0]].name,
      ],
      correct: 2,
      paradigm: 'Visual array · 5 colors (past capacity ~4)',
      source: 'Luck & Vogel 1997; Cowan 2001',
    ),
    _Task(
      kind: 4,
      stimulusTitle: 'Read carefully, just once!',
      stimulus: _stimulusBox(
        context,
        child: Text(
          b
              ? 'This morning Tom found 2 keys and a green wallet in the park.'
              : 'Yesterday Anna bought 3 apples and a blue scarf at the market.',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 18, color: context.inkText, height: 1.4),
        ),
      ),
      question: b
          ? 'What did Tom find besides the wallet?'
          : 'What did Anna buy besides the scarf?',
      options: b
          ? ['2 keys', '3 coins', 'A phone', 'A glove']
          : ['2 pears', '3 apples', '1 hat', 'A basket'],
      correct: b ? 0 : 1,
      paradigm: 'Story recall · 1 detail, single reading',
      source: 'WMS Logical Memory; Craik & Tulving 1975',
    ),
    _Task(
      kind: 4,
      hard: true,
      stimulusTitle: 'Two facts this time — catch both!',
      stimulus: _stimulusBox(
        context,
        child: Text(
          b
              ? 'On Friday Lisa lent 4 books and a silver camera to her '
                  'neighbor, then called Ann at 6.'
              : 'On Tuesday Maria borrowed 2 novels and a red umbrella from the '
                  'library, then met Tom at 5.',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 17, color: context.inkText, height: 1.4),
        ),
      ),
      question: b
          ? 'What did Lisa lend besides the camera?'
          : 'What did Maria borrow besides the umbrella?',
      options: b
          ? ['4 books', '2 books', 'A laptop', 'A bike']
          : ['2 novels', '3 magazines', 'A map', '1 novel'],
      correct: 0,
      paradigm: 'Story recall · 2 details + time anchor',
      source: 'WMS Logical Memory; Craik & Tulving 1975',
    ),
    _Task(
      kind: 5,
      stimulusTitle: 'Think about the meaning!',
      stimulus: _stimulusBox(
        context,
        child: Text(
          b ? 'Vegetables' : 'Fruits',
          style: TextStyle(
            fontSize: 32,
            fontWeight: FontWeight.bold,
            color: context.inkText,
          ),
        ),
      ),
      question: b ? 'Which one is a vegetable?' : 'Which one is a fruit?',
      options: b
          ? ['Apple', 'Carrot', 'Pear', 'Grape']
          : ['Carrot', 'Apple', 'Potato', 'Onion'],
      correct: 1,
      paradigm: 'Category exemplar · clear prototype',
      source: 'Collins & Quillian 1969; Rosch 1975',
    ),
    _Task(
      kind: 5,
      hard: true,
      stimulusTitle: 'Trickier category — think!',
      stimulus: _stimulusBox(
        context,
        child: Text(
          b ? 'Birds' : 'Mammals',
          style: TextStyle(
            fontSize: 32,
            fontWeight: FontWeight.bold,
            color: context.inkText,
          ),
        ),
      ),
      question: b ? 'Which one is a bird?' : 'Which one is a mammal?',
      options: b
          ? ['Bat', 'Penguin', 'Butterfly', 'Bee']
          : ['Shark', 'Dolphin', 'Penguin', 'Crocodile'],
      correct: 1,
      paradigm: 'Category exemplar · lookalike lures',
      source: 'Collins & Quillian 1969; Rosch 1975',
    ),
  ];
}

/// Assessment tasks: fixed parallel forms, never AI-generated.
///
/// A measurement instrument must give every user the same items, or
/// scores stop being comparable. AI therefore never replaces probes
/// here (it only reads the finished scores + interview at the verdict
/// stage). Retakes alternate Form A/B via [MemoryStore].
// ignore: library_private_types_in_public_api
Future<List<_Task>> loadAssessmentTasks(BuildContext context) async {
  final runs = await MemoryStore.loadAssessmentRuns();
  // ignore: use_build_context_synchronously
  return _buildTasks(context, form: runs % 2);
}

/// Honest preamble every assessment run starts with.
///
/// Cheating (writing things down, asking for help, re-reading) does
/// not raise the user's level — it only hides their real dominant
/// type from them, so the training path adapts to a lie. Saying this
/// up front is standard test-instruction practice.
class MemoryAssessmentIntroPage extends StatelessWidget {
  const MemoryAssessmentIntroPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: const EngramBackButton(),
        title: Text(
          'Before we start',
          style: TextStyle(
            color: Theme.of(context).colorScheme.onSurface,
            fontWeight: FontWeight.bold,
            fontSize: 17,
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
        children: [
          Text(
            'One rule: no cheating.',
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurface,
              fontWeight: FontWeight.w900,
              fontSize: 28,
              height: 1.2,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'No writing things down, no asking for help, no second '
            'looks. Cheating only hurts you: it hides your real '
            'dominant memory type, and then your whole training path '
            'adapts to a lie. Answer from memory alone — wrong '
            'answers are useful data too.',
            style: TextStyle(color: context.inkText, fontSize: 16, height: 1.5),
          ),
          const SizedBox(height: 16),
          Container(
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
                  'What happens next',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurface,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '• 12 quick probes — 2 for each of your 6 memory types\n'
                  '• A 6-question interview about HOW you remember\n'
                  '• An AI reads both legs and names your dominant type\n'
                  '• Retakes alternate parallel forms, so memorized answers '
                  'do not inflate your score',
                  style: TextStyle(
                    color: context.inkText,
                    fontSize: 14,
                    height: 1.6,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          EngramButton(
            label: 'START — I PLAY FAIR',
            onPressed: () {
              AppFeedback.medium();
              Navigator.of(context).pushReplacement(
                MaterialPageRoute(
                  builder: (_) => const MemoryAssessmentPage(),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

class MemoryAssessmentPage extends StatefulWidget {
  const MemoryAssessmentPage({super.key});

  @override
  State<MemoryAssessmentPage> createState() => _MemoryAssessmentPageState();
}

class _MemoryAssessmentPageState extends State<MemoryAssessmentPage> {
  /// Parallel form of this run (0 = A, 1 = B): alternates per finished
  /// run so retakes cannot be passed from remembered answers.
  int _form = 0;

  @override
  void initState() {
    super.initState();
    MemoryStore.loadAssessmentRuns().then((runs) {
      if (!mounted) return;
      setState(() => _form = runs % 2);
    });
  }

  bool _firstArmed = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Theme (or other dependencies) changed: drop the cached tasks so
    // the next access rebuilds them with the fresh context.
    _taskCache = null;
    if (!_firstArmed) {
      _firstArmed = true;
      _armSenseTimerIfNeeded();
    }
  }

  /// Memoized task list: rebuilding all 12 widget trees on every
  /// per-second timer tick wasted frames, so the list is rebuilt only
  /// when the form flips or dependencies (theme) change.
  List<_Task>? _taskCache;
  int _taskCacheForm = -1;

  List<_Task> get _tasks {
    final cached = _taskCache;
    if (cached != null && _taskCacheForm == _form) return cached;
    final fresh = _buildTasks(context, form: _form);
    _taskCache = fresh;
    _taskCacheForm = _form;
    return fresh;
  }
  int _step = 0;
  bool _revealed = false;
  final List<int> _scores = List.filled(6, 0);

  /// Tie-break evidence for `resolveDominant`: hard-item hits per
  /// kind, plus mean recall latency (ms) per kind.
  final List<int> _hardHits = List.filled(6, 0);
  final List<int> _latSumMs = List.filled(6, 0);
  final List<int> _latCount = List.filled(6, 0);
  DateTime? _revealTime;

  /// Sensory probes auto-hide: a sensory trace is measured with a
  /// brief look, not unlimited study (Peterson & Peterson 1959).
  Timer? _senseTimer;
  int _senseLeft = 0;

  int? _picked;
  int _xp = 0;
  int _combo = 0;
  int _lastGain = 0;
  bool _lastGood = false;

  @override
  void dispose() {
    _senseTimer?.cancel();
    super.dispose();
  }

  void _armSenseTimerIfNeeded() {
    _senseTimer?.cancel();
    final task = _tasks[_step];
    if (task.kind == 0 && !_revealed) {
      _senseLeft = task.hard ? 6 : 5;
      _senseTimer = Timer.periodic(const Duration(seconds: 1), (t) {
        if (!mounted) return;
        if (_revealed || _tasks[_step].kind != 0) {
          t.cancel();
          return;
        }
        if (_senseLeft <= 1) {
          t.cancel();
          _reveal();
        } else {
          setState(() => _senseLeft--);
        }
      });
    }
  }

  void _reveal() {
    if (_revealed) return;
    AppFeedback.light();
    _senseTimer?.cancel();
    setState(() {
      _revealed = true;
      _revealTime = DateTime.now();
    });
  }

  Future<void> _nextStep() async {
    if (_step + 1 < _tasks.length) {
      setState(() {
        _step++;
        _revealed = false;
        _picked = null;
        _revealTime = null;
      });
      _armSenseTimerIfNeeded();
    } else {
      // Remember the profile locally so Battle Zone can default
      // the game mode to the user's strongest memory type. Awaited:
      // the scores must be on disk before leaving the assessment.
      await MemoryStore.saveScores(List.of(_scores));
      if (!mounted) return;
      final latencies = [
        for (var i = 0; i < 6; i++)
          _latCount[i] == 0 ? 0 : _latSumMs[i] ~/ _latCount[i],
      ];
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => AssessmentInterviewPage(
            scores: List.of(_scores),
            hardHits: List.of(_hardHits),
            latenciesMs: latencies,
            xp: _xp,
          ),
        ),
      );
    }
  }

  void _answer(int option) {
    if (_picked != null) return;
    final task = _tasks[_step];
    final good = option == task.correct;
    final gain = good
        ? 20 + (_combo >= 1 ? 10 : 0) + (_combo >= 3 ? 10 : 0)
        : 0;
    final latencyMs = _revealTime == null
        ? 0
        : DateTime.now().difference(_revealTime!).inMilliseconds;
    setState(() {
      _picked = option;
      // Two probes per type: easy 40 + hard 60 (see assessment.dart).
      if (good) {
        _scores[task.kind] += task.hard ? 60 : 40;
        if (task.hard) _hardHits[task.kind]++;
      }
      if (latencyMs > 0) {
        _latSumMs[task.kind] += latencyMs;
        _latCount[task.kind]++;
      }
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
      unawaited(_nextStep());
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
            if (task.paradigm.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                '${task.paradigm} · ${task.source}',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: context.mutedText,
                  fontStyle: FontStyle.italic,
                  fontSize: 12,
                ),
              ),
            ],
            if (task.kind == 0) ...[
              const SizedBox(height: 8),
              Text(
                'Memorize fast — it hides in $_senseLeft s!',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: coral,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
            ],
            const SizedBox(height: 16),
            GestureDetector(
              onTap: _reveal,
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
                            icon: HugeIcons.strokeRoundedCheckmarkCircle02,
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
  final List<int> hardHits;
  final List<int> latenciesMs;
  final MemoryVerdict? verdict;
  const MemoryResultPage({
    super.key,
    required this.scores,
    this.xp = 0,
    this.hardHits = const [],
    this.latenciesMs = const [],
    this.verdict,
  });

  @override
  Widget build(BuildContext context) {
    // Research-backed tie ladder: hard items, then recall speed,
    // then the interview verdict — and a balanced card when the top
    // is still tied, never a fake single winner.
    final result = resolveDominant(
      scores: scores,
      hardHits: hardHits.length == scores.length ? hardHits : null,
      latenciesMs: latenciesMs.length == scores.length ? latenciesMs : null,
      interviewKind: verdict?.kind,
    );
    final best = result.kind;
    final v = verdict;
    final tiedNames = [
      for (final i in result.tied) memoryKinds[i].name,
    ].join(', ');
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
              color: best == null ? teal : violet,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: best == null ? tealDark : violetDark,
                  offset: const Offset(0, 4),
                ),
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
                    icon: best == null
                        ? HugeIcons.strokeRoundedBalanceScale
                        : memoryKinds[best].icon,
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
                        best == null
                            ? 'Balanced profile'
                            : 'Strongest: ${memoryKinds[best].name}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 17,
                        ),
                      ),
                      Text(
                        best == null
                            ? 'Tied at the top: $tiedNames'
                            : memoryKinds[best].module,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.85),
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
                if (best != null)
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
          const SizedBox(height: 8),
          Text(
            result.rationale,
            style: TextStyle(
              color: context.mutedText,
              fontStyle: FontStyle.italic,
              fontSize: 13,
              height: 1.4,
            ),
          ),
          if (v != null) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: context.cardBg,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: violet, width: 2),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: violet.withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    alignment: Alignment.center,
                    child: const HugeIcon(
                      icon: HugeIcons.strokeRoundedAiChat02,
                      color: violet,
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
                          v.fallback
                              ? 'Local analysis: ${memoryKinds[v.kind].name} '
                                    '(${(v.confidence * 100).round()}%)'
                              : 'AI verdict: ${memoryKinds[v.kind].name} '
                                    '(${(v.confidence * 100).round()}%)',
                          style: TextStyle(
                            color: context.inkText,
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          v.rationale,
                          style: TextStyle(
                            color: context.inkText,
                            fontSize: 13,
                            height: 1.4,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
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
                        style: TextStyle(
                          color: context.mutedText,
                          fontSize: 13,
                        ),
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
              AppFeedback.medium();
              Navigator.of(context).pop();
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
                'CONTINUE',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1,
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          GestureDetector(
            onTap: () {
              AppFeedback.light();
              Navigator.of(context).pushReplacement(
                MaterialPageRoute(
                  builder: (_) => const MemoryAssessmentIntroPage(),
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
