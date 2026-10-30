import '../theme/app_theme.dart';

import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';

import '../l10n/app_localizations.dart';
import '../widgets/ai_help_button.dart';
import '../widgets/app_buttons.dart';
import '../services/app_feedback.dart';
import '../models/assessment.dart'
    show
        assessmentColorChips,
        backEasyReversed,
        backHardReversed,
        corsiProbeSequences,
        iconicEasyCueByForm,
        iconicHardCuesByForm,
        ordinal,
        pointsForBudget,
        resolveDominant,
        scoresAreBlank,
        spatialProbeBudgets;
import '../models/claims_policy.dart'
    show assessmentDisclaimer, resultDisclaimer;
import '../models/collectibles.dart' show engram;
import '../models/item_banks.dart'
    show StoryIdeaUnit, assessmentCategory, assessmentStory;
import '../models/memory_verdict.dart' show MemoryVerdict;
import '../models/norms.dart'
    show
        LocalNorm,
        minNormN,
        minReliability,
        minReliabilityN,
        splitHalfReliability;
import '../models/recall_scoring.dart'
    show
        RecallScore,
        scoreDigitSpan,
        scoreOrderedCells,
        scoreStoryRecall;
import '../models/study_recommendation.dart'
    show StudyRecommendation, heuristicStudyRecommendation;
import '../services/memory_store.dart';
import '../widgets/honesty_sheet.dart';
import '../widgets/recall_inputs.dart';
import 'assessment_interview.dart';

class MemoryKind {
  final String nameKey;
  final String moduleKey;
  final List<List<dynamic>> icon;
  final Color tint;
  const MemoryKind(this.nameKey, this.moduleKey, this.icon, this.tint);

  String get displayName => tr(nameKey);
  String get displayModule => tr(moduleKey);
}

const paper = Color(0xFFFFFFFF);
const ink = Color(0xFF22314A);
const muted = Color(0xFF5B6B82);
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
    'track_0_name',
    'mkind_0_sub',
    HugeIcons.strokeRoundedAudioWave01,
    sky,
  ),
  MemoryKind(
    'track_1_name',
    'mkind_1_sub',
    HugeIcons.strokeRoundedLayers01,
    violet,
  ),
  MemoryKind(
    'track_2_name',
    'mkind_2_sub',
    HugeIcons.strokeRoundedCastle01,
    teal,
  ),
  MemoryKind('track_3_name', 'mkind_3_sub', HugeIcons.strokeRoundedEye, amber),
  MemoryKind(
    'track_4_name',
    'mkind_4_sub',
    HugeIcons.strokeRoundedNotebook01,
    coral,
  ),
  MemoryKind(
    'track_5_name',
    'mkind_5_sub',
    HugeIcons.strokeRoundedBrain01,
    violetDark,
  ),
];

enum _ResponseMode { choice, recall, corsi }

class _Task {
  final int kind;
  final bool hard;
  final String stimulusTitle;
  final Widget stimulus;
  final String question;
  final List<String> options;
  final int correct;

  final String paradigm;
  final String source;
  final _ResponseMode mode;

  final List<String> expectedDigits;

  final List<StoryIdeaUnit> units;

  final String recallHint;
  final bool multiline;
  final String answerKey;

  final Widget? questionStimulus;

  final List<int> corsiSequence;

  final int points;
  const _Task({
    required this.kind,
    this.hard = false,
    required this.stimulusTitle,
    required this.stimulus,
    required this.question,
    this.options = const [],
    this.correct = 0,
    this.paradigm = '',
    this.source = '',
    this.mode = _ResponseMode.choice,
    this.expectedDigits = const [],
    this.units = const [],
    this.recallHint = '',
    this.multiline = false,
    this.answerKey = '',
    this.questionStimulus,
    this.corsiSequence = const [],
    this.points = 0,
  });

  int get maxPoints => points > 0 ? points : (hard ? 60 : 40);
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

List<String> _shuffledOptions(List<String> opts, int seed) {
  final out = List<String>.of(opts)..shuffle(Random(seed));
  return out;
}

List<_Task> _buildTasks(BuildContext context, {int form = 0}) {
  final f = form % 4;
  const iconicEasy = [
    ['7', '3', '9'],
    ['5', '1', '8'],
    ['4', '7', '2'],
    ['9', '6', '3'],
  ];
  const iconicHard = [
    ['2', '8', '4', '9', '1', '6'],
    ['9', '3', '6', '2', '7', '4'],
    ['5', '1', '9', '4', '8', '3'],
    ['3', '7', '2', '6', '5', '9'],
  ];
  const backEasy = [
    ['4', '1', '8'],
    ['9', '2', '6'],
    ['5', '8', '3'],
    ['7', '4', '1'],
  ];
  const backHard = [
    ['3', '9', '1', '6', '2'],
    ['7', '4', '8', '2', '5'],
    ['6', '2', '9', '5', '3'],
    ['8', '5', '1', '7', '4'],
  ];
  final corsiEasy = corsiProbeSequences[0][f];
  final corsiMedium = corsiProbeSequences[1][f];
  final corsiHard = corsiProbeSequences[2][f];
  const visEasyShown = [
    [0, 1, 2],
    [1, 2, 3],
    [2, 3, 4],
    [0, 2, 5],
  ];
  const visEasyTest = [
    [0, 1, 2],
    [1, 2, 0],
    [5, 3, 4],
    [0, 2, 5],
  ];
  const visEasyAns = [0, 1, 1, 0];
  const visHardShown = [
    [0, 1, 2, 3, 4],
    [1, 2, 3, 4, 5],
    [0, 1, 3, 4, 5],
    [0, 2, 3, 4, 5],
  ];
  const visHardTest = [
    [0, 1, 2, 5, 4],
    [1, 2, 3, 4, 5],
    [0, 1, 3, 4, 5],
    [0, 1, 3, 4, 5],
  ];
  const visHardAns = [1, 0, 0, 1];
  final locale = AppLocalizations.localeCode;
  final storyEasy = assessmentStory(f, false, locale);
  final storyHard = assessmentStory(f, true, locale);
  final catEasy = assessmentCategory(f, false, locale);
  final catHard = assessmentCategory(f, true, locale);
  final easyCue = iconicEasyCueByForm[f];
  final easyCued = iconicEasy[f][easyCue];
  final hardCues = iconicHardCuesByForm[f];
  final hardCued = [iconicHard[f][hardCues[0]], iconicHard[f][hardCues[1]]];
  final easyRev = backEasyReversed(f);
  final hardRev = backHardReversed(f);
  final backEasyExp = easyRev ? backEasy[f].reversed.toList() : backEasy[f];
  final backHardExp = hardRev ? backHard[f].reversed.toList() : backHard[f];
  final catEasyOpts =
      _shuffledOptions([catEasy.correct, ...catEasy.lures], 10 + f);
  final catHardOpts =
      _shuffledOptions([catHard.correct, ...catHard.lures], 20 + f);
  return [
    _Task(
      kind: 0,
      stimulusTitle: tr('mtask_k0_easy_title'),
      stimulus: _stimulusBox(
        context,
        child: Text(
          iconicEasy[f].join('   '),
          style: TextStyle(
            fontSize: 40,
            fontWeight: FontWeight.bold,
            color: context.inkText,
            letterSpacing: 4,
          ),
        ),
      ),
      question: tr('mtask_k0_easy_q', {'ord': ordinal(easyCue + 1)}),
      mode: _ResponseMode.recall,
      expectedDigits: [easyCued],
      recallHint: tr('mtask_type_digit'),
      answerKey: easyCued,
      paradigm: tr('mtask_iconic_easy'),
      source: 'Sperling 1960; Luck & Vogel 1997',
    ),
    _Task(
      kind: 0,
      hard: true,
      stimulusTitle: tr('mtask_k0_hard_title'),
      stimulus: _stimulusBox(
        context,
        child: Text(
          iconicHard[f].join('   '),
          style: TextStyle(
            fontSize: 32,
            fontWeight: FontWeight.bold,
            color: context.inkText,
            letterSpacing: 3,
          ),
        ),
      ),
      question: tr('mtask_k0_hard_q', {
        'a': ordinal(hardCues[0] + 1),
        'b': ordinal(hardCues[1] + 1),
      }),
      mode: _ResponseMode.recall,
      expectedDigits: hardCued,
      recallHint: tr('mtask_type_2digits'),
      answerKey: hardCued.join('-'),
      paradigm: tr('mtask_iconic_hard'),
      source: 'Sperling 1960; Cowan 2001',
    ),
    _Task(
      kind: 1,
      stimulusTitle: tr('mtask_k1_easy_title'),
      stimulus: _stimulusBox(
        context,
        child: Text(
          backEasy[f].join('   '),
          style: TextStyle(
            fontSize: 40,
            fontWeight: FontWeight.bold,
            color: context.inkText,
            letterSpacing: 4,
          ),
        ),
      ),
      question: easyRev ? tr('mtask_rev') : tr('mtask_fwd'),
      mode: _ResponseMode.recall,
      expectedDigits: backEasyExp,
      recallHint: tr('mtask_type_digits'),
      answerKey: backEasyExp.join('-'),
      paradigm: tr('mtask_span3'),
      source: 'WAIS digit span; Baddeley 1986',
    ),
    _Task(
      kind: 1,
      hard: true,
      stimulusTitle: tr('mtask_k1_hard_title'),
      stimulus: _stimulusBox(
        context,
        child: Text(
          backHard[f].join('   '),
          style: TextStyle(
            fontSize: 36,
            fontWeight: FontWeight.bold,
            color: context.inkText,
            letterSpacing: 3,
          ),
        ),
      ),
      question: hardRev ? tr('mtask_rev_full') : tr('mtask_fwd_full'),
      mode: _ResponseMode.recall,
      expectedDigits: backHardExp,
      recallHint: tr('mtask_type_digits'),
      answerKey: backHardExp.join('-'),
      paradigm: tr('mtask_span5'),
      source: 'WAIS digit span; Cowan 2001',
    ),
    _Task(
      kind: 2,
      stimulusTitle: tr('mtask_corsi3_title'),
      stimulus: CorsiSequenceStimulus(
        key: ValueKey('corsi-stim-$f-easy'),
        sequence: corsiEasy,
      ),
      question: tr('mtask_corsi_tap'),
      mode: _ResponseMode.corsi,
      corsiSequence: corsiEasy,
      points: spatialProbeBudgets[0],
      paradigm: tr('mtask_corsi3'),
      source: 'Corsi 1972 block-tapping',
    ),
    _Task(
      kind: 2,
      stimulusTitle: tr('mtask_corsi5_title'),
      stimulus: CorsiSequenceStimulus(
        key: ValueKey('corsi-stim-$f-medium'),
        sequence: corsiMedium,
      ),
      question: tr('mtask_corsi_tap'),
      mode: _ResponseMode.corsi,
      corsiSequence: corsiMedium,
      points: spatialProbeBudgets[1],
      paradigm: tr('mtask_corsi5'),
      source: 'Corsi 1972; Kessels et al. 2000',
    ),
    _Task(
      kind: 2,
      hard: true,
      stimulusTitle: tr('mtask_corsi6_title'),
      stimulus: CorsiSequenceStimulus(
        key: ValueKey('corsi-stim-$f-hard'),
        sequence: corsiHard,
      ),
      question: tr('mtask_corsi_tap'),
      mode: _ResponseMode.corsi,
      corsiSequence: corsiHard,
      points: spatialProbeBudgets[2],
      paradigm: tr('mtask_corsi6'),
      source: 'Corsi 1972; Kessels et al. 2000',
    ),
    _Task(
      kind: 3,
      stimulusTitle: tr('mtask_vis3_title'),
      stimulus: _chipRow(context, chipIndexes: visEasyShown[f]),
      question: tr('mtask_vis_q'),
      questionStimulus: _chipRow(context, chipIndexes: visEasyTest[f]),
      options: [tr('mtask_same'), tr('mtask_different')],
      correct: visEasyAns[f],
      paradigm: tr('mtask_vis3'),
      source: 'Luck & Vogel 1997 change detection',
    ),
    _Task(
      kind: 3,
      hard: true,
      stimulusTitle: tr('mtask_vis5_title'),
      stimulus: _chipRow(context, chipIndexes: visHardShown[f]),
      question: tr('mtask_vis_q'),
      questionStimulus: _chipRow(context, chipIndexes: visHardTest[f]),
      options: [tr('mtask_same'), tr('mtask_different')],
      correct: visHardAns[f],
      paradigm: tr('mtask_vis5'),
      source: 'Luck & Vogel 1997; Cowan 2001',
    ),
    _Task(
      kind: 4,
      stimulusTitle: tr('mtask_story_title'),
      stimulus: _stimulusBox(
        context,
        child: Text(
          storyEasy.text,
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 18, color: context.inkText, height: 1.4),
        ),
      ),
      question: tr('mtask_story_q'),
      mode: _ResponseMode.recall,
      units: storyEasy.units,
      recallHint: tr('mtask_story_hint'),
      multiline: true,
      answerKey: storyEasy.text,
      paradigm: tr('mtask_story3'),
      source: 'WMS Logical Memory; Craik & Tulving 1975',
    ),
    _Task(
      kind: 4,
      hard: true,
      stimulusTitle: tr('mtask_story2_title'),
      stimulus: _stimulusBox(
        context,
        child: Text(
          storyHard.text,
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 17, color: context.inkText, height: 1.4),
        ),
      ),
      question: tr('mtask_story_q'),
      mode: _ResponseMode.recall,
      units: storyHard.units,
      recallHint: tr('mtask_story_hint2'),
      multiline: true,
      answerKey: storyHard.text,
      paradigm: tr('mtask_story5'),
      source: 'WMS Logical Memory; Craik & Tulving 1975',
    ),
    _Task(
      kind: 5,
      stimulusTitle: tr('mtask_cat_title'),
      stimulus: _stimulusBox(
        context,
        child: Text(
          catEasy.category,
          style: TextStyle(
            fontSize: 32,
            fontWeight: FontWeight.bold,
            color: context.inkText,
          ),
        ),
      ),
      question: tr('mtask_cat_q'),
      options: catEasyOpts,
      correct: catEasyOpts.indexOf(catEasy.correct),
      paradigm: tr('mtask_cat_easy'),
      source: 'Collins & Quillian 1969; Rosch 1975',
    ),
    _Task(
      kind: 5,
      hard: true,
      stimulusTitle: tr('mtask_cat_title2'),
      stimulus: _stimulusBox(
        context,
        child: Text(
          catHard.category,
          style: TextStyle(
            fontSize: 32,
            fontWeight: FontWeight.bold,
            color: context.inkText,
          ),
        ),
      ),
      question: tr('mtask_cat_q'),
      options: catHardOpts,
      correct: catHardOpts.indexOf(catHard.correct),
      paradigm: tr('mtask_cat_hard'),
      source: 'Collins & Quillian 1969; Rosch 1975',
    ),
  ];
}

// ignore: library_private_types_in_public_api
Future<List<_Task>> loadAssessmentTasks(BuildContext context) async {
  final runs = await MemoryStore.loadAssessmentRuns();
  // ignore: use_build_context_synchronously
  return _buildTasks(context, form: runs % 4);
}

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
          tr('mprof_before'),
          style: TextStyle(
            color: Theme.of(context).colorScheme.onSurface,
            fontWeight: FontWeight.bold,
            fontSize: 17,
          ),
        ),
        actions: [
          AiHelpButton(
            topic: AiHelpTopics.assessment,
            helpContext: tr('mprof_intro_help'),
          ),
          const SizedBox(width: 12),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
        children: [
          Text(
            tr('mprof_nocheat'),
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurface,
              fontWeight: FontWeight.w900,
              fontSize: 28,
              height: 1.2,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            tr('mprof_nocheat_body'),
            style: TextStyle(color: context.inkText, fontSize: 16, height: 1.5),
          ),
          const SizedBox(height: 12),
          Text(
            assessmentDisclaimer,
            style: TextStyle(
              color: context.mutedText,
              fontSize: 13,
              height: 1.5,
            ),
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
                  tr('mprof_next'),
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurface,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  tr('mprof_next_body'),
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
            label: tr('mprof_start'),
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

class _MemoryAssessmentPageState extends State<MemoryAssessmentPage>
    with WidgetsBindingObserver {
  int _form = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    MemoryStore.loadAssessmentRuns().then((runs) {
      if (!mounted) return;
      setState(() => _form = runs % 4);
    });
  }

  bool _firstArmed = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _taskCache = null;
    if (!_firstArmed) {
      _firstArmed = true;
      _armSenseTimerIfNeeded();
    }
  }

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

  final List<double> _itemProps = [];

  final List<int> _hardHits = List.filled(6, 0);
  final List<int> _latSumMs = List.filled(6, 0);
  final List<int> _latCount = List.filled(6, 0);
  final Stopwatch _latencyClock = Stopwatch();
  bool _latencyWasRunning = false;

  Timer? _senseTimer;
  int _senseLeft = 0;
  bool _senseWasTicking = false;

  int? _picked;

  RecallScore? _recall;
  bool get _answered => _picked != null || _recall != null;

  int _xp = 0;
  int _combo = 0;
  int _lastGain = 0;
  bool _lastGood = false;

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _senseTimer?.cancel();
    _latencyClock.stop();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive) {
      _senseWasTicking = _senseTimer?.isActive ?? false;
      _senseTimer?.cancel();
      _latencyWasRunning = _latencyClock.isRunning;
      _latencyClock.stop();
    } else if (state == AppLifecycleState.resumed) {
      if (_latencyWasRunning) {
        _latencyWasRunning = false;
        _latencyClock.start();
      }
      if (_senseWasTicking) {
        _senseWasTicking = false;
        if (mounted && !_revealed && _step < _tasks.length) {
          _startSenseTicker();
        }
      }
    }
  }

  void _armSenseTimerIfNeeded() {
    _senseTimer?.cancel();
    _senseWasTicking = false;
    final task = _tasks[_step];
    if (task.kind == 0 && !_revealed) {
      _senseLeft = task.hard ? 6 : 4;
      _startSenseTicker();
    }
  }

  void _startSenseTicker() {
    _senseTimer?.cancel();
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

  void _reveal() {
    if (_revealed) return;
    AppFeedback.light();
    _senseTimer?.cancel();
    _senseWasTicking = false;
    setState(() {
      _revealed = true;
    });
    _latencyClock
      ..reset()
      ..start();
  }

  Future<void> _nextStep() async {
    if (_step + 1 < _tasks.length) {
      setState(() {
        _step++;
        _revealed = false;
        _picked = null;
        _recall = null;
      });
      _latencyClock
        ..stop()
        ..reset();
      _latencyWasRunning = false;
      _armSenseTimerIfNeeded();
    } else {
      await MemoryStore.saveScores(List.of(_scores));
      await MemoryStore.recordAssessmentRun(
        itemProps: List.of(_itemProps),
        scores: List.of(_scores),
      );
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

  void _registerResult({
    required _Task task,
    required double proportion,
    required bool exact,
  }) {
    final prop = proportion.clamp(0.0, 1.0);
    final gain = exact
        ? 20 + (_combo >= 1 ? 10 : 0) + (_combo >= 3 ? 10 : 0)
        : (20 * prop).round();
    final latencyMs = _latencyClock.elapsed.inMilliseconds;
    setState(() {
      _scores[task.kind] += pointsForBudget(
        proportion: prop,
        max: task.maxPoints,
      );
      if (task.hard && exact) _hardHits[task.kind]++;
      while (_itemProps.length <= _step) {
        _itemProps.add(0);
      }
      _itemProps[_step] = prop;
      if (latencyMs > 0) {
        _latSumMs[task.kind] += latencyMs;
        _latCount[task.kind]++;
      }
      _lastGain = gain;
      _lastGood = prop >= 0.99;
      if (exact) {
        _combo++;
        _xp += gain;
      } else {
        _combo = 0;
        _xp += gain;
      }
    });
  }

  void _answer(int option) {
    if (_answered) return;
    final task = _tasks[_step];
    final good = option == task.correct;
    _registerResult(
      task: task,
      proportion: good ? 1 : 0,
      exact: good,
    );
    setState(() => _picked = option);
    Future.delayed(const Duration(milliseconds: 750), () {
      if (!mounted) return;
      unawaited(_nextStep());
    });
  }

  void _submitRecall(String text) {
    if (_answered) return;
    final task = _tasks[_step];
    final RecallScore score;
    if (task.units.isNotEmpty) {
      score = scoreStoryRecall(task.units, text);
    } else {
      score = scoreDigitSpan(task.expectedDigits, text);
    }
    _registerResult(
      task: task,
      proportion: score.proportion,
      exact: score.exact,
    );
    setState(() => _recall = score);
    Future.delayed(const Duration(milliseconds: 1500), () {
      if (!mounted) return;
      unawaited(_nextStep());
    });
  }

  void _answerCorsi(List<int> taps) {
    if (_answered) return;
    final task = _tasks[_step];
    final score = scoreOrderedCells(task.corsiSequence, taps);
    _registerResult(
      task: task,
      proportion: score.proportion,
      exact: score.exact,
    );
    setState(() => _recall = score);
    Future.delayed(const Duration(milliseconds: 1500), () {
      if (!mounted) return;
      unawaited(_nextStep());
    });
  }

  Future<bool> _confirmExit() async {
    final leave = await showDialog<bool>(
      context: context,
      builder: (dlgCtx) => AlertDialog(
        key: const ValueKey('assessment-exit-dialog'),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          tr('assess_leave'),
          style: TextStyle(
            color: context.inkText,
            fontWeight: FontWeight.w800,
          ),
        ),
        content: Text(
          tr('mprof_leave_body'),
          style: TextStyle(color: context.mutedText),
        ),
        actions: [
          TextButton(
            key: const ValueKey('assessment-exit-stay'),
            onPressed: () {
              AppFeedback.light();
              Navigator.of(dlgCtx).pop(false);
            },
            child: Text(tr('assess_keep')),
          ),
          FilledButton(
            key: const ValueKey('assessment-exit-leave'),
            onPressed: () {
              AppFeedback.light();
              Navigator.of(dlgCtx).pop(true);
            },
            child: Text(tr('assess_leave_btn')),
          ),
        ],
      ),
    );
    return leave == true;
  }

  Future<void> _onBackPressed() async {
    final leave = await _confirmExit();
    if (leave && mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final task = _tasks[_step];
    final kind = memoryKinds[task.kind];
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        final leave = await _confirmExit();
        if (leave && context.mounted) Navigator.of(context).pop();
      },
      child: Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: EngramBackButton(onPressed: _onBackPressed),
        title: Text(
          tr('mprof_title', {'n': _step + 1, 'total': _tasks.length}),
          style: TextStyle(
            color: Theme.of(context).colorScheme.onSurface,
            fontWeight: FontWeight.bold,
            fontSize: 17,
          ),
        ),
        actions: [
          AiHelpButton(
            topic: AiHelpTopics.assessment,
            helpContext: tr('mprof_task_help'),
          ),
          const SizedBox(width: 12),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(6),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(99),
              child: LinearProgressIndicator(
                value: (_step + 1) / _tasks.length,
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
                      kind.displayName,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurface,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    Text(
                      kind.displayModule,
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
                      tr('streak_balance', {'n': _xp}),
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
                    tr('mprof_combo', {'n': _combo}),
                    style: TextStyle(
                      color: violetDark,
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                )
              else
                Text(
                  tr('mprof_earn'),
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
                tr('mprof_sense', {'n': _senseLeft}),
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
                child: Text(
                  tr('mprof_continue'),
                  style: const TextStyle(
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
              tr('mprof_prompt_gone'),
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
            if (task.questionStimulus != null) ...[
              task.questionStimulus!,
              const SizedBox(height: 12),
            ],
            if (task.mode == _ResponseMode.choice)
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
                              : _picked != null && i == _picked
                              ? coral
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
                          if (_picked != null &&
                              i == _picked &&
                              _picked != task.correct)
                            const HugeIcon(
                              icon: HugeIcons.strokeRoundedCancelCircle,
                              color: coral,
                              size: 22,
                              strokeWidth: 2.2,
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
            if (task.mode == _ResponseMode.recall)
              RecallTextField(
                key: ValueKey('recall-$_step'),
                hint: task.recallHint,
                keyboard: task.multiline
                    ? TextInputType.multiline
                    : TextInputType.text,
                submitted: _recall != null,
                detail: _recall?.detail ?? '',
                exact: _recall?.exact ?? false,
                answerKey: task.answerKey,
                onSubmit: _submitRecall,
              ),
            if (task.mode == _ResponseMode.corsi) ...[
              CorsiTapGrid(
                key: ValueKey('corsi-$_step'),
                submitted: _recall != null,
                onDone: _answerCorsi,
              ),
              if (_recall != null) ...[
                const SizedBox(height: 8),
                Text(
                  _recall!.detail,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: context.inkText,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
              ],
            ],
            if (_answered)
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
                                  ? tr('mprof_sealed', {
                                      'combo': _combo,
                                      'gain': _lastGain,
                                    })
                                  : tr('mprof_nice', {'gain': _lastGain}))
                            : _lastGain > 0
                            ? tr('mprof_partial', {'gain': _lastGain})
                            : tr('mprof_next_double'),
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

  final StudyRecommendation? recommendation;

  final ValueChanged<int>? onStartTrack;
  const MemoryResultPage({
    super.key,
    required this.scores,
    this.xp = 0,
    this.hardHits = const [],
    this.latenciesMs = const [],
    this.verdict,
    this.recommendation,
    this.onStartTrack,
  });

  @override
  Widget build(BuildContext context) {
    final result = resolveDominant(
      scores: scores,
      hardHits: hardHits.length == scores.length ? hardHits : null,
      latenciesMs: latenciesMs.length == scores.length ? latenciesMs : null,
      interviewKind: verdict?.kind,
    );
    final best = result.kind;
    final v = verdict;
    final tiedNames = [
      for (final i in result.tied) memoryKinds[i].displayName,
    ].join(', ');
    final rec =
        recommendation ??
        heuristicStudyRecommendation(
          scores: scores,
          hardHits: hardHits.length == scores.length ? hardHits : null,
          latenciesMs: latenciesMs.length == scores.length
              ? latenciesMs
              : null,
          interviewKind: verdict?.kind,
        );
    var weakest = -1;
    for (var i = 0; i < scores.length; i++) {
      if (i == rec.track) continue;
      if (weakest < 0 || scores[i] < scores[weakest]) weakest = i;
    }
    final showWeakest = !scoresAreBlank(scores) && weakest >= 0;
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: const EngramBackButton(),
        title: Text(
          tr('mprof_result'),
          style: TextStyle(
            color: Theme.of(context).colorScheme.onSurface,
            fontWeight: FontWeight.bold,
            fontSize: 17,
          ),
        ),
        actions: [
          AiHelpButton(
            topic: AiHelpTopics.assessment,
            helpContext: tr('mprof_result_help'),
          ),
          const SizedBox(width: 12),
        ],
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
                            ? tr('mprof_balanced')
                            : tr('mprof_strongest', {
                                'name': memoryKinds[best].displayName,
                              }),
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 17,
                        ),
                      ),
                      Text(
                        best == null
                            ? tr('mprof_tied', {'names': tiedNames})
                            : memoryKinds[best].displayModule,
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
          const SizedBox(height: 8),
          Text(
            resultDisclaimer,
            style: TextStyle(
              color: context.mutedText,
              fontSize: 13,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 4),
          GestureDetector(
            onTap: () => showHonestySheet(context),
            child: Text(
              tr('onboarding_honesty_link'),
              style: const TextStyle(
                color: violet,
                fontWeight: FontWeight.bold,
                fontSize: 13,
              ),
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
                              ? tr('mprof_local', {
                                  'name': memoryKinds[v.kind].displayName,
                                  'pct': (v.confidence * 100).round(),
                                })
                              : tr('mprof_ai_verdict', {
                                  'name': memoryKinds[v.kind].displayName,
                                  'pct': (v.confidence * 100).round(),
                                }),
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
              color: teal.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: teal, width: 2),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: teal.withValues(alpha: 0.16),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      alignment: Alignment.center,
                      child: const HugeIcon(
                        icon: HugeIcons.strokeRoundedAiChat02,
                        color: teal,
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
                            rec.fallback
                                ? tr('mprof_study', {
                                    'name': memoryKinds[rec.track].displayName,
                                  })
                                : tr('mprof_ai_study', {
                                    'name': memoryKinds[rec.track].displayName,
                                  }),
                            style: TextStyle(
                              color: context.inkText,
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            rec.rationale,
                            style: TextStyle(
                              color: context.inkText,
                              fontSize: 13,
                              height: 1.4,
                            ),
                          ),
                          if (showWeakest) ...[
                            const SizedBox(height: 4),
                            Text(
                              tr('mprof_weakest', {
                                'name': memoryKinds[weakest].displayName,
                              }),
                              style: TextStyle(
                                color: context.mutedText,
                                fontSize: 13,
                                height: 1.4,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
                if (onStartTrack != null) ...[
                  const SizedBox(height: 12),
                  GestureDetector(
                    onTap: () => onStartTrack!(rec.track),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 13),
                      decoration: BoxDecoration(
                        color: teal,
                        borderRadius: BorderRadius.circular(14),
                        boxShadow: const [
                          BoxShadow(color: tealDark, offset: Offset(0, 4)),
                        ],
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        tr('mprof_start_track', {
                          'name': memoryKinds[rec.track]
                              .displayName
                              .toUpperCase(),
                        }),
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                          letterSpacing: 1,
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 12),
          _CalibrationCard(scores: scores),
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
                        tr('mprof_earned', {'n': xp}),
                        style: TextStyle(
                          color: context.inkText,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      Text(
                        tr('mprof_bonus'),
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
              child: Text(
                tr('mprof_continue_btn'),
                style: const TextStyle(
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
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const HugeIcon(
                    icon: HugeIcons.strokeRoundedRefresh,
                    color: violet,
                    size: 20,
                    strokeWidth: 2.2,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    tr('mprof_retake'),
                    style: const TextStyle(
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

class _CalibrationCard extends StatelessWidget {
  final List<int> scores;
  const _CalibrationCard({required this.scores});

  Future<({Map<int, LocalNorm> norms, List<List<double>> runs})> _load() async {
    final norms = await MemoryStore.loadLocalNorms();
    final runs = await MemoryStore.loadAssessmentRunsData();
    return (norms: norms, runs: runs);
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder(
      future: _load(),
      builder: (context, snap) {
        final norms = snap.data?.norms ?? const <int, LocalNorm>{};
        final runs = snap.data?.runs ?? const <List<double>>[];
        final n = norms.values.isEmpty
            ? 0
            : norms.values.map((v) => v.n).reduce((a, b) => a > b ? a : b);
        final myAvg = scores.isEmpty
            ? 0
            : scores.reduce((a, b) => a + b) / scores.length;
        String line1 = n <= 0
            ? tr('mprof_calibrating')
            : (n == 1
                ? tr('mprof_calibrated_one')
                : tr('mprof_calibrated_many', {'n': n}));
        String? line2;
        if (n >= minNormN && norms.length == 6) {
          final appAvg =
              norms.values.map((v) => v.mean).reduce((a, b) => a + b) /
              6 *
              100;
          line2 = tr('mprof_avg', {
            'mine': myAvg.round(),
            'app': appAvg.round(),
          });
        }
        String? line3;
        if (runs.length >= minReliabilityN) {
          final r = splitHalfReliability(runs);
          if (r != null) {
            line3 = r >= minReliability
                ? tr('mprof_rel_ok', {
                    'r': r.toStringAsFixed(2),
                    'n': runs.length,
                  })
                : tr('mprof_rel_low', {
                    'r': r.toStringAsFixed(2),
                    'n': runs.length,
                  });
          }
        }
        return Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: context.cardBg,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: context.hairline, width: 2),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                tr('mprof_quality'),
                style: TextStyle(
                  color: context.inkText,
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                line1,
                style: TextStyle(color: context.mutedText, fontSize: 13),
              ),
              if (line2 != null) ...[
                const SizedBox(height: 2),
                Text(
                  line2,
                  style: TextStyle(color: context.mutedText, fontSize: 13),
                ),
              ],
              if (line3 != null) ...[
                const SizedBox(height: 2),
                Text(
                  line3,
                  style: TextStyle(color: context.mutedText, fontSize: 13),
                ),
              ],
            ],
          ),
        );
      },
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
                        kind.displayName,
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
