import 'dart:async';

import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';

import '../models/curriculum.dart';
import '../models/dynamic_task.dart';
import '../models/foundations.dart';
import '../models/lesson_content.dart';
import '../models/marathon.dart'
    show
        depthChipLabelIn,
        depthForNextSession,
        difficultyBoostForDepth,
        lagForDepth,
        nextReviewLineIn,
        practiceDepths,
        reviewGapDays,
        roundsForDepth,
        variantSeedFor;
import '../l10n/app_localizations.dart';
import '../models/meta_task.dart';
import '../models/recall_scoring.dart' show RecallScore, scoreTaskRecall;
import '../models/transfer_targets.dart';
import '../models/user_goals.dart';
import '../models/validated_tasks.dart' show localValidatedTask, specForId;
import 'my_goals.dart' show MyGoalsPage;
import '../services/app_feedback.dart';
import '../services/memory_growth.dart';
import '../services/memory_store.dart';
import '../services/meta_ai_service.dart';
import '../theme/app_theme.dart';
import '../widgets/ai_help_button.dart';
import '../widgets/app_buttons.dart';
import '../widgets/dynamic_task_view.dart';
import '../widgets/recall_inputs.dart';

String lessonKindFor(int chapter, int lesson) {
  const base = ['sensory', 'sequence', 'spatial', 'visual', 'verbal', 'verbal'];
  if (chapter == 6) {
    const mixed = ['number', 'verbal', 'sequence', 'spatial'];
    return mixed[lesson % mixed.length];
  }
  if (chapter == 7) {
    const hard = ['number', 'sequence', 'spatial', 'number'];
    return hard[lesson % hard.length];
  }
  if (chapter >= 30) {
    final track = trackOfChapter(chapter);
    if (track == 0) return lesson.isEven ? 'sensory' : 'interference';
    if (track == 1) return 'number';
    if (track == 4) {
      const episodic = ['episodic', 'verbal', 'replay', 'poem'];
      return episodic[lesson % episodic.length];
    }
    if (track == 5) {
      const transfer = ['face', 'foreign', 'semantic', 'prospective'];
      return transfer[lesson % transfer.length];
    }
    return base[track];
  }
  return base[trackOfChapter(chapter)];
}

int lessonDifficultyFor(int chapter, int section, int lesson) {
  final depth = chapterDepth(chapter);
  final base = depth >= 4
      ? 3
      : depth >= 2
      ? 2
      : 1;
  return (base + section + lesson ~/ 2).clamp(1, 5);
}

int lessonRoundsFor(int chapter, int section, int lesson) {
  if (chapter < 0) return 3;
  if (isFoundationLesson(chapter, section, lesson)) return 2;
  final depth = chapterDepth(chapter);
  final extra = depth >= 4
      ? 2
      : depth >= 2
      ? 1
      : 0;
  return (3 + section + lesson ~/ 2 + extra).clamp(3, 5);
}

int lessonLagFor(int rounds, int chapter) {
  if (rounds < 3) return 0;
  if (rounds >= 5 || chapterDepth(chapter) >= 4) return 2;
  return 1;
}

int lessonLagForLesson(int chapter, int section, int lesson) {
  if (chapter < 0 || section < 0 || lesson < 0) return 0;
  if (chapterDepth(chapter) == 0 && section == 0) return 0;
  return lessonLagFor(
    lessonRoundsFor(chapter, section, lesson),
    chapter,
  );
}

String _crossKindFor(String base) {
  switch (base) {
    case 'spatial':
      return 'visual';
    case 'visual':
      return 'spatial';
    case 'sequence':
      return 'verbal';
    case 'episodic':
      return 'verbal';
    case 'replay':
      return 'episodic';
    case 'poem':
      return 'verbal';
    case 'prospective':
      return 'verbal';
    case 'semantic':
      return 'face';
    case 'face':
      return 'foreign';
    case 'foreign':
      return 'verbal';
    case 'pattern':
      return 'visual';
    default:
      return 'sequence';
  }
}

bool lessonRoundKindWantsImage(String kind) =>
    kind != 'number' && kind != 'sequence' && kind != 'pattern';

String lessonRoundKindFor(int chapter, int lesson, int round, int rounds) {
  final base = lessonKindFor(chapter, lesson);
  if (rounds < 3 || chapter < 0) return base;
  if (chapter == 6) {
    const mixed = ['number', 'verbal', 'sequence', 'spatial'];
    return mixed[(lesson + round) % mixed.length];
  }
  if (chapter == 7) {
    const hard = ['number', 'sequence', 'spatial', 'number'];
    return hard[(lesson + round) % hard.length];
  }
  if (round.isEven) return base;
  return _crossKindFor(base);
}

int lessonRoundDifficultyFor(
  int chapter,
  int section,
  int lesson,
  int round,
  int rounds,
) {
  final base = lessonDifficultyFor(chapter, section, lesson);
  final boost = rounds <= 1 ? 0 : round ~/ 2;
  return (base + boost).clamp(1, 5);
}

bool recallCapableParadigm(String paradigmId) => const {
  'backward-span',
  'iconic-probe',
  'echoic-probe',
  'brown-peterson',
  'chunk-span',
  'loci-drill',
  'picture-recall',
  'pattern-span',
  'story-recall',
  'category-exemplar',
  'paired-associate',
  'face-name',
  'keyword-pair',
  'prospective-cue',
  'poem-chunk',
  'day-replay',
}.contains(paradigmId);

bool lessonRecallMode({
  required int chapter,
  required int difficulty,
  required String paradigm,
}) {
  return chapter >= 6 && difficulty >= 3 && recallCapableParadigm(paradigm);
}

String lessonRecallHint(String paradigm) {
  switch (paradigm) {
    case 'backward-span':
      return tr('lp_recall_backward');
    case 'iconic-probe':
    case 'echoic-probe':
      return tr('lp_recall_digit');
    case 'chunk-span':
      return tr('lp_recall_number');
    case 'brown-peterson':
      return tr('lp_recall_trigram');
    case 'story-recall':
      return tr('lp_recall_story');
    case 'paired-associate':
      return tr('lp_recall_target');
    case 'face-name':
      return tr('lp_recall_surname');
    case 'keyword-pair':
      return tr('lp_recall_meaning');
    case 'loci-drill':
      return tr('lp_recall_station');
    case 'picture-recall':
      return tr('lp_recall_detail');
    case 'pattern-span':
      return tr('lp_recall_cells');
    case 'category-exemplar':
      return tr('lp_recall_member');
    case 'prospective-cue':
      return tr('lp_recall_then');
    case 'poem-chunk':
      return tr('lp_recall_line');
    case 'day-replay':
      return tr('lp_recall_next');
    default:
      return tr('lp_recall_default');
  }
}

int lessonSessionStars({
  required int correct,
  required int total,
  required Duration elapsed,
}) {
  if (total <= 0) return 1;
  if (correct >= total) {
    final avgPerQuestion =
        elapsed.inMilliseconds / total.clamp(1, 1 << 30).toDouble();
    if (avgPerQuestion < const Duration(seconds: 15).inMilliseconds) {
      return 3;
    }
    return 2;
  }
  if (correct * 2 >= total) return 2;
  return 1;
}

class LessonPlanStep {
  final bool stimulus;
  final int task;
  const LessonPlanStep({required this.stimulus, required this.task});
}

List<LessonPlanStep> lessonSessionPlan(int rounds, int lag) {
  final plan = <LessonPlanStep>[];
  final pending = <int>[];
  for (var r = 0; r < rounds; r++) {
    plan.add(LessonPlanStep(stimulus: true, task: r));
    pending.add(r);
    if (r < rounds - 1) {
      if (pending.length > lag) {
        plan.add(LessonPlanStep(stimulus: false, task: pending.removeAt(0)));
      }
    }
  }
  while (pending.isNotEmpty) {
    plan.add(LessonPlanStep(stimulus: false, task: pending.removeAt(0)));
  }
  return plan;
}

List<MetaTask> loadLocalLessonTasks({
  required int chapter,
  required int section,
  required int lesson,
  int depth = 0,
}) {
  final d = depth.clamp(0, practiceDepths);
  final rounds = roundsForDepth(lessonRoundsFor(chapter, section, lesson), d);
  final boost = difficultyBoostForDepth(d);
  final seedBase = d <= 0
      ? '$chapter-$section-$lesson'
      : variantSeedFor(chapter, section, lesson, d);
  return [
    for (var r = 0; r < rounds; r++)
      localValidatedTask(
        MetaTaskRequest(
          kind: lessonRoundKindFor(chapter, lesson, r, rounds),
          difficulty:
              (lessonRoundDifficultyFor(chapter, section, lesson, r, rounds) +
                      boost)
                  .clamp(1, 5),
          seed: '$seedBase-r$r',
          locale: AppLocalizations.localeCode,
        ),
      ),
  ];
}

Future<List<MetaTask>> loadLessonTasks({
  required int chapter,
  required int section,
  required int lesson,
  required Future<MetaTask> Function(int round) loadRound,
  Duration timeout = const Duration(seconds: 15),
  void Function(int done, int total)? onProgress,
  int depth = 0,
}) async {
  final rounds = roundsForDepth(
    lessonRoundsFor(chapter, section, lesson),
    depth,
  );
  var done = 0;
  Future<MetaTask> tracked(int r) async {
    try {
      return await loadRound(r);
    } finally {
      done++;
      onProgress?.call(done, rounds);
    }
  }

  try {
    final tasks = await Future.wait([
      for (var r = 0; r < rounds; r++) tracked(r),
    ]).timeout(timeout);
    if (tasks.isEmpty) throw StateError('no tasks');
    return tasks;
  } catch (_) {
    return loadLocalLessonTasks(
      chapter: chapter,
      section: section,
      lesson: lesson,
      depth: depth,
    );
  }
}

class LessonPlayerPage extends StatefulWidget {
  final int chapterIndex;
  final int sectionIndex;
  final int lessonIndex;

  final int practiceDepth;
  const LessonPlayerPage({
    super.key,
    required this.chapterIndex,
    required this.sectionIndex,
    required this.lessonIndex,
    this.practiceDepth = 0,
  });

  @override
  State<LessonPlayerPage> createState() => _LessonPlayerPageState();
}

enum _Phase { coach, loading, stimulus, question, done }

class _LessonPlayerPageState extends State<LessonPlayerPage>
    with WidgetsBindingObserver {
  _Phase _phase = _Phase.coach;
  bool _upgrading = false;
  double _upgradeProgress = 0;
  int _upgradeDone = 0;
  int _upgradeTotal = 0;
  List<MetaTask> _tasks = const [];
  List<LessonPlanStep> _plan = const [];
  int _planPos = 0;
  int? _picked;
  RecallScore? _recall;
  final Map<int, bool> _results = {};
  final List<Duration> _latencies = [];

  final Stopwatch _sessionClock = Stopwatch();
  final Stopwatch _questionClock = Stopwatch();
  bool _sessionWasRunning = false;
  bool _questionWasRunning = false;
  int _stars = 0;
  bool _saved = false;
  int? _nextGapDays;

  int get _depth => widget.practiceDepth.clamp(0, practiceDepths);
  int get _rounds => roundsForDepth(
    lessonRoundsFor(
      widget.chapterIndex,
      widget.sectionIndex,
      widget.lessonIndex,
    ),
    _depth,
  );
  int get _lag => lagForDepth(
    lessonLagForLesson(
      widget.chapterIndex,
      widget.sectionIndex,
      widget.lessonIndex,
    ),
    _depth,
  );

  String? _ownTargetId;
  final TextEditingController _ownMaterialCtrl = TextEditingController();
  final TextEditingController _ownForgotCtrl = TextEditingController();
  bool _ownPrefilled = false;
  String? _ownBusy;
  String _ownTeacherText = '';
  String _ownDiagnoseText = '';
  bool _ownBuilding = false;
  DynamicTask? _ownDynamic;
  List<UserGoal> _userGoals = const [];
  String _recapText = '';
  String _missedText = '';
  bool _missedBusy = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadUserGoals();
  }

  Future<void> _loadUserGoals() async {
    try {
      final goals = await MemoryStore.loadUserGoals();
      if (!mounted) return;
      setState(() => _userGoals = goals);
    } catch (_) {
    }
  }

  Future<void> _openGoalsManager() async {
    AppFeedback.light();
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const MyGoalsPage()),
    );
    if (mounted) _loadUserGoals();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _sessionClock.stop();
    _questionClock.stop();
    _ownMaterialCtrl.dispose();
    _ownForgotCtrl.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive) {
      _sessionWasRunning = _sessionClock.isRunning;
      _questionWasRunning = _questionClock.isRunning;
      _sessionClock.stop();
      _questionClock.stop();
    } else if (state == AppLifecycleState.resumed) {
      if (_sessionWasRunning) {
        _sessionWasRunning = false;
        _sessionClock.start();
      }
      if (_questionWasRunning) {
        _questionWasRunning = false;
        if (_phase == _Phase.question) _questionClock.start();
      }
    }
  }

  List<TransferTarget> get _ownTargets =>
      transferTargetsForTrack(trackOfChapter(widget.chapterIndex));

  UserGoal? get _selectedGoal {
    final id = _ownTargetId;
    if (id == null) return null;
    for (final g in _userGoals) {
      if (g.id == id) return g;
    }
    return null;
  }

  String get _effectiveTargetId {
    if (_ownTargetId != null) {
      if (_ownTargets.any((t) => t.id == _ownTargetId)) return _ownTargetId!;
      if (_userGoals.any((g) => g.id == _ownTargetId)) return _ownTargetId!;
    }
    final targets = _ownTargets;
    return targets.isEmpty ? 'todos-errands' : targets.first.id;
  }

  String get _effectiveCustomLabel => _selectedGoal?.title ?? '';
  String get _effectiveCustomStrategy =>
      _selectedGoal?.analysis?.strategy ?? '';
  String get _effectiveCustomSource => _selectedGoal?.analysis?.source ?? '';

  Future<void> _prefillOwnMaterial() async {
    if (_ownPrefilled) return;
    _ownPrefilled = true;
    final goal = _selectedGoal;
    if (goal != null) {
      if (mounted) {
        setState(() {
          if (goal.material.isNotEmpty) _ownMaterialCtrl.text = goal.material;
          if (goal.forgotNote.isNotEmpty) _ownForgotCtrl.text = goal.forgotNote;
        });
      }
      return;
    }
    try {
      final saved = await MemoryStore.loadOwnMaterial(_effectiveTargetId);
      if (saved.isNotEmpty && mounted) {
        setState(() => _ownMaterialCtrl.text = saved);
      }
    } catch (_) {
    }
  }

  Future<void> _runOwnTeach() async {
    if (_ownBusy != null) return;
    setState(() {
      _ownBusy = 'teach';
      _ownTeacherText = '';
    });
    final answer = await MetaAIService.explainTechnique(
      targetId: _effectiveTargetId,
      userMaterial: _ownMaterialCtrl.text,
      forgotNote: _ownForgotCtrl.text,
      locale: AppLocalizations.localeCode,
      customLabel: _effectiveCustomLabel,
      customStrategy: _effectiveCustomStrategy,
    );
    if (!mounted) return;
    setState(() {
      _ownBusy = null;
      _ownTeacherText = answer.text;
    });
  }

  Future<void> _runOwnDiagnose() async {
    if (_ownBusy != null || _ownForgotCtrl.text.trim().isEmpty) return;
    setState(() {
      _ownBusy = 'diagnose';
      _ownDiagnoseText = '';
    });
    final answer = await MetaAIService.diagnoseForgetting(
      targetId: _effectiveTargetId,
      forgotNote: _ownForgotCtrl.text,
      locale: AppLocalizations.localeCode,
      customLabel: _effectiveCustomLabel,
      customStrategy: _effectiveCustomStrategy,
    );
    if (!mounted) return;
    setState(() {
      _ownBusy = null;
      _ownDiagnoseText = answer.text;
    });
  }

  Future<void> _runOwnBuild() async {
    if (_ownBuilding) return;
    setState(() {
      _ownBuilding = true;
      _ownDynamic = null;
    });
    final goal = _selectedGoal;
    if (goal != null) {
      unawaited(
        MemoryStore.updateUserGoal(
          goal.copyWith(
            material: _ownMaterialCtrl.text.trim(),
            forgotNote: _ownForgotCtrl.text.trim(),
            updatedAt: DateTime.now(),
          ),
        ),
      );
    } else {
      unawaited(
        MemoryStore.saveOwnMaterial(
          _effectiveTargetId,
          _ownMaterialCtrl.text,
        ),
      );
    }
    final task = await MetaAIService.buildDynamicTask(
      DynamicTaskRequest(
        targetId: _effectiveTargetId,
        customLabel: _effectiveCustomLabel,
        customStrategy: _effectiveCustomStrategy,
        customSource: _effectiveCustomSource,
        userMaterial: _ownMaterialCtrl.text,
        forgotNote: _ownForgotCtrl.text,
        difficulty: goal?.analysis?.difficulty ?? 1,
        locale: AppLocalizations.localeCode,
        seed: 'own:${widget.chapterIndex}:${DateTime.now().millisecondsSinceEpoch}',
      ),
    );
    if (!mounted) return;
    setState(() {
      _ownBuilding = false;
      _ownDynamic = task;
    });
  }

  Widget _sessionProgressBar() {
    final n = _tasks.length;
    if (n <= 1) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            tr('lp_progress', {'done': _answeredCount, 'n': n}),
            textAlign: TextAlign.center,
            style: TextStyle(
              color: context.mutedText,
              fontWeight: FontWeight.w600,
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 6),
          LinearProgressIndicator(
            key: const ValueKey('lesson-session-progress'),
            value: _answeredCount / n,
            minHeight: 8,
            borderRadius: BorderRadius.circular(8),
          ),
        ],
      ),
    );
  }

  Widget _historyStrip() {
    final n = _tasks.length;
    if (n <= 1) return const SizedBox.shrink();
    final current = _step?.task;
    return Padding(
      key: const ValueKey('lesson-history-strip'),
      padding: const EdgeInsets.only(bottom: 12),
      child: Wrap(
        spacing: 6,
        runSpacing: 6,
        alignment: WrapAlignment.center,
        children: [
          for (var i = 0; i < n; i++)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: _results[i] == true
                    ? const Color(0xFF14B8A6).withValues(alpha: 0.14)
                    : _results.containsKey(i)
                    ? const Color(0xFFFF6B6B).withValues(alpha: 0.12)
                    : i == current
                    ? context.washBg
                    : context.cardBg,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: i == current
                      ? context.washBorder
                      : context.faintBorder,
                  width: 2,
                ),
              ),
              child: Text(
                tr('lp_history', {
                  'i': i + 1,
                  'kind': drillKindLabelIn(
                    AppLocalizations.localeCode,
                    _taskKind(i),
                  ),
                }),
                style: TextStyle(
                  color: context.inkText,
                  fontWeight: FontWeight.w700,
                  fontSize: 12,
                ),
              ),
            ),
        ],
      ),
    );
  }

  LessonPlanStep? get _step => _planPos < _plan.length ? _plan[_planPos] : null;
  MetaTask? get _activeTask {
    final step = _step;
    if (step == null || _tasks.isEmpty) return null;
    if (step.task < 0 || step.task >= _tasks.length) return null;
    return _tasks[step.task];
  }

  int get _answeredCount => _results.length;
  int get _correctCount => _results.values.where((c) => c).length;

  LessonSpec get _lesson => chapters[widget.chapterIndex]
      .sections[widget.sectionIndex]
      .lessons[widget.lessonIndex];

  Future<MetaTask> _loadRoundTask(int round, {bool withImage = true}) async {
    final kind = lessonRoundKindFor(
      widget.chapterIndex,
      widget.lessonIndex,
      round,
      _rounds,
    );
    final difficulty =
        (lessonRoundDifficultyFor(
                  widget.chapterIndex,
                  widget.sectionIndex,
                  widget.lessonIndex,
                  round,
                  _rounds,
                ) +
                difficultyBoostForDepth(_depth))
            .clamp(1, 5);
    final seedBase = _depth <= 0
        ? '${widget.chapterIndex}-${widget.sectionIndex}-${widget.lessonIndex}'
        : variantSeedFor(
            widget.chapterIndex,
            widget.sectionIndex,
            widget.lessonIndex,
            _depth,
          );
    final seed = '$seedBase-r$round';
    try {
      final task = await MetaAIService.generateTask(
        MetaTaskRequest(
          kind: kind,
          difficulty: difficulty,
          seed: seed,
          locale: AppLocalizations.localeCode,
        ),
      );
      if (!withImage || !lessonRoundKindWantsImage(kind)) return task;
      if (kind == 'spatial') {
        return await MetaAIService.enrichSpatialTask(
          task,
          difficulty: difficulty,
          seed: seed,
        );
      }
      return await MetaAIService.enrichVisualTask(task, seed: seed);
    } catch (_) {
      return localValidatedTask(
        MetaTaskRequest(
          kind: kind,
          difficulty: difficulty,
          seed: seed,
          locale: AppLocalizations.localeCode,
        ),
      );
    }
  }

  void _startDrill() {
    final local = loadLocalLessonTasks(
      chapter: widget.chapterIndex,
      section: widget.sectionIndex,
      lesson: widget.lessonIndex,
      depth: _depth,
    );
    setState(() {
      _tasks = local;
      _plan = lessonSessionPlan(_rounds, _lag);
      _planPos = 0;
      _picked = null;
      _results.clear();
      _latencies.clear();
      _saved = false;
      _stars = 0;
      _recapText = '';
      _missedText = '';
      _missedBusy = false;
      _upgrading = false;
      _upgradeProgress = 0;
      _upgradeDone = 0;
      _upgradeTotal = 0;
      _phase = _plan.first.stimulus ? _Phase.stimulus : _Phase.question;
    });
    _sessionClock
      ..reset()
      ..start();
    _questionClock
      ..reset()
      ..stop();
    if (_phase == _Phase.question) _questionClock.start();
    unawaited(_upgradeInBackground());
  }

  Future<void> _upgradeInBackground() async {
    bool hasKey;
    try {
      hasKey = await MetaAIService.hasAnyKey();
    } catch (_) {
      hasKey = false;
    }
    if (!hasKey || !mounted) return;
    final rounds = _rounds;
    if (rounds <= 0 || !mounted) return;
    setState(() {
      _upgrading = true;
      _upgradeProgress = 0;
      _upgradeDone = 0;
      _upgradeTotal = rounds;
    });
    var done = 0;
    var imageLeft = 2;
    for (var r = 0; r < rounds; r++) {
      final kind = lessonRoundKindFor(
        widget.chapterIndex,
        widget.lessonIndex,
        r,
        rounds,
      );
      final withImage = lessonRoundKindWantsImage(kind) && imageLeft > 0;
      if (withImage) imageLeft--;
      MetaTask upgraded;
      try {
        upgraded = await _loadRoundTask(r, withImage: withImage).timeout(
          const Duration(seconds: 30),
          onTimeout: () => loadLocalLessonTasks(
            chapter: widget.chapterIndex,
            section: widget.sectionIndex,
            lesson: widget.lessonIndex,
            depth: _depth,
          )[r],
        );
      } catch (_) {
        upgraded = loadLocalLessonTasks(
          chapter: widget.chapterIndex,
          section: widget.sectionIndex,
          lesson: widget.lessonIndex,
          depth: _depth,
        )[r];
      }
      if (!mounted) return;
      done++;
      setState(() {
        if (r < _tasks.length && !_results.containsKey(r)) {
          _tasks[r] = upgraded;
        }
        _upgradeDone = done;
        _upgradeProgress = done / rounds;
      });
    }
    if (!mounted) return;
    setState(() => _upgrading = false);
  }

  void _advancePlan() {
    if (_planPos + 1 >= _plan.length) return;
    setState(() {
      _planPos++;
      _picked = null;
      _recall = null;
      _phase = _plan[_planPos].stimulus ? _Phase.stimulus : _Phase.question;
    });
    _questionClock
      ..reset()
      ..stop();
    if (_phase == _Phase.question) _questionClock.start();
  }

  void _showQuestion() {
    _advancePlan();
  }

  Future<void> _recordAnswer({required bool correct}) async {
    final taskIndex = _step!.task;
    final elapsed = _questionClock.elapsed;
    _questionClock.stop();
    setState(() {
      _results[taskIndex] = correct;
      _latencies.add(elapsed);
    });
    if (correct) {
      AppFeedback.medium();
    } else {
      AppFeedback.heavy();
    }
    if (_results.length >= _tasks.length) {
      await _finishSession();
    }
  }

  Future<void> _answer(int option) async {
    final task = _activeTask;
    if (_picked != null ||
        _recall != null ||
        task == null ||
        _step?.stimulus == true) {
      return;
    }
    setState(() => _picked = option);
    await _recordAnswer(correct: option == task.correct);
  }

  Future<void> _submitRecall(String text) async {
    final task = _activeTask;
    if (_picked != null ||
        _recall != null ||
        task == null ||
        _step?.stimulus == true) {
      return;
    }
    final score = scoreTaskRecall(task, text);
    setState(() => _recall = score);
    await _recordAnswer(correct: score.exact);
  }

  void _nextAfterAnswer() {
    if (_results.length >= _tasks.length) return;
    _advancePlan();
  }

  Future<void> _finishSession() async {
    final totalElapsed = _sessionClock.elapsed;
    _sessionClock.stop();
    _questionClock.stop();
    final stars = lessonSessionStars(
      correct: _correctCount,
      total: _tasks.length,
      elapsed: totalElapsed,
    );
    setState(() => _stars = stars);
    await MemoryStore.saveLessonStars(
      chapter: widget.chapterIndex,
      section: widget.sectionIndex,
      lesson: widget.lessonIndex,
      stars: stars,
    );
    final sessionMinutes =
        (totalElapsed.inSeconds / 60).ceil().clamp(1, 240);
    await MemoryStore.recordLessonSession(
      track: trackOfChapter(widget.chapterIndex),
      chapter: widget.chapterIndex,
      section: widget.sectionIndex,
      lesson: widget.lessonIndex,
      minutes: sessionMinutes,
    );
    final growthBase = stars.clamp(0, 3);
    if (growthBase > 0) {
      await applyGrowth(
        kind: trackOfChapter(widget.chapterIndex),
        base: growthBase,
      );
    }
    int? nextGap;
    try {
      final reps = await MemoryStore.loadLessonReps();
      final key = MemoryStore.lessonKey(
        widget.chapterIndex,
        widget.sectionIndex,
        widget.lessonIndex,
      );
      final nextDepth = depthForNextSession(
        reps: reps[key] ?? 0,
        stars: stars,
      );
      nextGap = reviewGapDays[nextDepth.clamp(0, reviewGapDays.length - 1)];
    } catch (_) {
      nextGap = null;
    }
    unawaited(MemoryStore.recordStreakDay());
    if (!mounted) return;
    setState(() {
      _saved = true;
      _nextGapDays = nextGap;
      _phase = _Phase.done;
    });
    unawaited(_loadRecap());
  }

  Future<void> _loadRecap() async {
    final answer = await MetaAIService.sessionRecap(
      correct: _correctCount,
      total: _tasks.length,
      trackLabel: trackName(
        trackOfChapter(widget.chapterIndex),
        AppLocalizations.localeCode,
      ),
      locale: AppLocalizations.localeCode,
    );
    if (!mounted) return;
    setState(() => _recapText = answer.text);
  }

  Future<void> _runMissedDiagnose() async {
    if (_missedBusy) return;
    final missed = <String>[];
    for (var i = 0; i < _tasks.length; i++) {
      if (_results[i] == false) {
        final t = _tasks[i];
        final bit = t.question.isNotEmpty ? t.question : t.prompt;
        if (bit.trim().isNotEmpty) missed.add(bit.trim());
      }
    }
    if (missed.isEmpty) return;
    setState(() {
      _missedBusy = true;
      _missedText = '';
    });
    var note = missed.join('; ');
    if (note.length > 500) note = note.substring(0, 500);
    final answer = await MetaAIService.diagnoseForgetting(
      targetId: _effectiveTargetId,
      forgotNote: note,
      locale: AppLocalizations.localeCode,
      customLabel: _effectiveCustomLabel,
      customStrategy: _effectiveCustomStrategy,
    );
    if (!mounted) return;
    setState(() {
      _missedBusy = false;
      _missedText = answer.text;
    });
  }

  String _appBarTitle(String realm) {
    final step = widget.lessonIndex + 1;
    if (_phase == _Phase.coach || _tasks.isEmpty) {
      return tr('lp_appbar_base', {'realm': realm, 'step': step});
    }
    return tr('lp_appbar_done', {
      'realm': realm,
      'step': step,
      'done': _answeredCount,
      'n': _tasks.length,
    });
  }

  bool get _needsExitConfirm =>
      _tasks.isNotEmpty &&
      (_phase == _Phase.stimulus || _phase == _Phase.question);

  Future<bool> _confirmExit() async {
    final leave = await showDialog<bool>(
      context: context,
      builder: (dlgCtx) => AlertDialog(
        key: const ValueKey('lesson-exit-dialog'),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          tr('lp_exit_title'),
          style: TextStyle(color: context.inkText, fontWeight: FontWeight.w800),
        ),
        content: Text(
          tr('lp_exit_body'),
          style: TextStyle(color: context.mutedText),
        ),
        actions: [
          TextButton(
            key: const ValueKey('lesson-exit-stay'),
            onPressed: () {
              AppFeedback.light();
              Navigator.of(dlgCtx).pop(false);
            },
            child: Text(tr('lp_exit_stay')),
          ),
          FilledButton(
            key: const ValueKey('lesson-exit-leave'),
            onPressed: () {
              AppFeedback.light();
              Navigator.of(dlgCtx).pop(true);
            },
            child: Text(tr('lp_exit_leave')),
          ),
        ],
      ),
    );
    return leave == true;
  }

  Future<void> _onBackPressed() async {
    if (!_needsExitConfirm) {
      if (mounted) Navigator.of(context).pop();
      return;
    }
    final leave = await _confirmExit();
    if (leave && mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final chapter = chapters[widget.chapterIndex];
    return PopScope(
      canPop: !_needsExitConfirm,
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
            _appBarTitle(
              chapterRealmIn(
                AppLocalizations.localeCode,
                widget.chapterIndex,
              ),
            ),
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurface,
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
          actions: [
            AiHelpButton(
              topic: AiHelpTopics.lesson,
              helpContext:
                  '${chapter.realm}, Part ${widget.sectionIndex + 1}, '
                  'Step ${widget.lessonIndex + 1}: ${_lesson.title}',
            ),
            const SizedBox(width: 12),
          ],
        ),
        body: switch (_phase) {
          _Phase.coach => _coachView(),
          _Phase.loading => _loadingView(),
          _Phase.stimulus => _stimulusView(),
          _Phase.question || _Phase.done => _questionView(),
        },
      ),
    );
  }

  Widget _coachView() {
    final coach = coachFor(
      widget.chapterIndex,
      widget.sectionIndex,
      AppLocalizations.localeCode,
    );
    final foundation = isFoundationLesson(
      widget.chapterIndex,
      widget.sectionIndex,
      widget.lessonIndex,
    );
    final lagIntro = wantsLagIntroduction(
      widget.chapterIndex,
      widget.sectionIndex,
      _lag,
    );
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
      children: [
        Text(
          lessonTitleIn(
            AppLocalizations.localeCode,
            widget.chapterIndex,
            widget.sectionIndex,
            widget.lessonIndex,
          ),
          style: TextStyle(
            color: Theme.of(context).colorScheme.onSurface,
            fontWeight: FontWeight.w900,
            fontSize: 24,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          coach.title,
          style: TextStyle(
            color: context.mutedText,
            fontWeight: FontWeight.w700,
            fontSize: 14,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          key: const ValueKey('lesson-session-info'),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: context.cardBg,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: context.faintBorder),
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  foundation
                      ? tr('lp_session_foundation', {'n': _rounds})
                      : _lag <= 0
                      ? tr('lp_session_plain', {'n': _rounds})
                      : _lag == 1
                      ? tr('lp_session_lag_one', {'n': _rounds})
                      : tr('lp_session_lag_many', {
                          'n': _rounds,
                          'lag': _lag,
                        }),
                  style: TextStyle(
                    color: context.mutedText,
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
              ),
            ],
          ),
        ),
        if (foundation) ...[
          const SizedBox(height: 12),
          _workedExampleCard(),
        ],
        if (lagIntro) ...[const SizedBox(height: 12), _lagIntroCard()],
        const SizedBox(height: 12),
        _transferTargetsCard(),
        const SizedBox(height: 12),
        Container(
          key: const ValueKey('lesson-how-it-works'),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: context.cardBg,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: context.faintBorder),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                tr('lp_how_title'),
                style: TextStyle(
                  color: context.mutedText,
                  fontWeight: FontWeight.w900,
                  fontSize: 11,
                  letterSpacing: 1.2,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                tr('lp_how_body', {'n': _rounds}),
                style: TextStyle(
                  color: context.inkText,
                  fontSize: 13,
                  height: 1.5,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: context.washBg,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: context.washBorder, width: 2),
          ),
          child: Text(
            coach.intro,
            style: TextStyle(color: context.inkText, fontSize: 15, height: 1.5),
          ),
        ),
        const SizedBox(height: 12),
        for (var i = 0; i < coach.steps.length; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: context.cardBg,
                    shape: BoxShape.circle,
                    border: Border.all(color: context.washBorder, width: 2),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    '${i + 1}',
                    style: TextStyle(
                      color: context.inkText,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      coach.steps[i],
                      style: TextStyle(
                        color: context.inkText,
                        fontSize: 14,
                        height: 1.4,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        const SizedBox(height: 4),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: context.cardBg,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: context.faintBorder),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                tr('lp_why_title'),
                style: TextStyle(
                  color: context.mutedText,
                  fontWeight: FontWeight.w900,
                  fontSize: 11,
                  letterSpacing: 1.2,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                coach.why,
                style: TextStyle(
                  color: context.inkText,
                  fontSize: 13,
                  height: 1.45,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                coach.source,
                style: TextStyle(
                  color: context.mutedText,
                  fontStyle: FontStyle.italic,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Container(
          key: const ValueKey('lesson-depth-chip'),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: context.washBg,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: context.washBorder),
          ),
          child: Row(
            children: [
              HugeIcon(
                icon: HugeIcons.strokeRoundedRepeat,
                color: context.mutedText,
                size: 16,
                strokeWidth: 2.0,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  depthChipLabelIn(AppLocalizations.localeCode, _depth),
                  style: TextStyle(
                    color: context.mutedText,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        EngramButton(
          key: const ValueKey('lesson-coach-next'),
          label: tr('lp_start'),
          onPressed: () => _startDrill(),
        ),
      ],
    );
  }

  String _taskKind(int taskIndex) => lessonRoundKindFor(
    widget.chapterIndex,
    widget.lessonIndex,
    taskIndex,
    _tasks.length,
  );

  Widget _workedExampleCard() {
    final example = workedExampleForTrack(
      trackOfChapter(widget.chapterIndex),
      AppLocalizations.localeCode,
    );
    return Container(
      key: const ValueKey('lesson-worked-example'),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: context.washBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: context.washBorder, width: 2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            tr('lp_watchme'),
            style: TextStyle(
              color: context.mutedText,
              fontWeight: FontWeight.w900,
              fontSize: 11,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            example.situation,
            style: TextStyle(
              color: context.inkText,
              fontWeight: FontWeight.w700,
              fontSize: 14,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 8),
          for (var i = 0; i < example.thinkAloud.length; i++)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Text(
                '${i + 1}. ${example.thinkAloud[i]}',
                style: TextStyle(
                  color: context.inkText,
                  fontSize: 13,
                  height: 1.4,
                ),
              ),
            ),
          const SizedBox(height: 4),
          Text(
            example.payoff,
            style: TextStyle(
              color: context.mutedText,
              fontStyle: FontStyle.italic,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }

  Widget _lagIntroCard() {
    return Container(
      key: const ValueKey('lesson-lag-intro'),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: context.cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: context.faintBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            tr('lp_lag_title'),
            style: TextStyle(
              color: context.mutedText,
              fontWeight: FontWeight.w900,
              fontSize: 11,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            tr('lp_lag_body', {'n': _rounds}),
            style: TextStyle(
              color: context.inkText,
              fontSize: 13,
              height: 1.45,
            ),
          ),
        ],
      ),
    );
  }

  Widget _transferTargetsCard() {
    final targets = transferTargetsForTrack(
      trackOfChapter(widget.chapterIndex),
    );
    if (targets.isEmpty) return const SizedBox.shrink();
    return Container(
      key: const ValueKey('lesson-transfer-targets'),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: context.cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: context.faintBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            tr('lp_transfer_title'),
            style: TextStyle(
              color: context.mutedText,
              fontWeight: FontWeight.w900,
              fontSize: 11,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final t in targets)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: context.washBg,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: context.washBorder),
                  ),
                  child: Text(
                    t.labelIn(AppLocalizations.localeCode),
                    style: TextStyle(
                      color: context.inkText,
                      fontWeight: FontWeight.w700,
                      fontSize: 12,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            tr('lp_transfer_note'),
            style: TextStyle(
              color: context.mutedText,
              fontSize: 12,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }

  Widget _loadingView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 48),
        child: Column(
          key: const ValueKey('lesson-loading-progress'),
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              _upgradeTotal > 0
                  ? tr('lp_loading_n', {
                      'done': _upgradeDone,
                      'total': _upgradeTotal,
                    })
                  : tr('lp_loading'),
              style: TextStyle(
                color: context.mutedText,
                fontWeight: FontWeight.w700,
                fontSize: 13,
              ),
            ),
            const SizedBox(height: 12),
            LinearProgressIndicator(
              value: _upgradeTotal > 0 ? _upgradeProgress : null,
              minHeight: 8,
              borderRadius: BorderRadius.circular(8),
            ),
          ],
        ),
      ),
    );
  }

  Widget _upgradeBar() {
    if (!_upgrading) return const SizedBox.shrink();
    return Padding(
      key: const ValueKey('lesson-upgrade-progress'),
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            tr('lp_upgrade', {
              'done': _upgradeDone,
              'total': _upgradeTotal,
            }),
            textAlign: TextAlign.center,
            style: TextStyle(
              color: context.mutedText,
              fontWeight: FontWeight.w600,
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 6),
          LinearProgressIndicator(
            value: _upgradeTotal > 0 ? _upgradeProgress : null,
            minHeight: 6,
            borderRadius: BorderRadius.circular(6),
          ),
        ],
      ),
    );
  }

  Widget _stimulusView() {
    final task = _activeTask!;
    final n = _tasks.length;
    final round = _step!.task;
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
      children: [
        _upgradeBar(),
        _sessionProgressBar(),
        _historyStrip(),
        if (n > 1)
          Text(
            tr('lp_badge_hold', {
              'badge': stimulusBadgeIn(
                AppLocalizations.localeCode,
                round,
                n,
                _taskKind(round),
              ),
            }),
            style: TextStyle(
              color: context.mutedText,
              fontWeight: FontWeight.w700,
              fontSize: 13,
            ),
          ),
        if (n > 1) const SizedBox(height: 4),
        Text(
          task.prompt,
          style: TextStyle(
            color: Theme.of(context).colorScheme.onSurface,
            fontWeight: FontWeight.bold,
            fontSize: 20,
          ),
        ),
        const SizedBox(height: 12),
        _stimulusBox(task),
        if (task.paradigm.isNotEmpty) ...[
          const SizedBox(height: 8),
          Text(
            '${specForId(task.paradigm).displayName} · ${task.source}',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: context.mutedText,
              fontStyle: FontStyle.italic,
              fontSize: 12,
            ),
          ),
        ],
        const SizedBox(height: 20),
        EngramButton(
          key: const ValueKey('lesson-memorized'),
          label: tr('lp_memorized'),
          onPressed: _showQuestion,
        ),
        const SizedBox(height: 8),
        Text(
          _lag > 0 && n > 1
              ? tr('lp_remember_lag', {'i': round + 1, 'n': n})
              : tr('lp_disappears'),
          textAlign: TextAlign.center,
          style: TextStyle(color: context.mutedText, fontSize: 13),
        ),
      ],
    );
  }

  bool get _isGridStimulus {
    final task = _activeTask;
    final items = task?.items ?? const [];
    if (items.isEmpty || items.length > 9) return false;
    final kind = _step == null ? '' : _taskKind(_step!.task);
    if (kind != 'spatial' && kind != 'visual') return false;
    return items.every((e) {
      final n = int.tryParse(e);
      return n != null && n >= 0 && n < 9;
    });
  }

  bool get _isLociStimulus {
    final task = _activeTask;
    if (task == null || _step == null) return false;
    if (_taskKind(_step!.task) != 'spatial') return false;
    return task.stations.isNotEmpty &&
        task.items.isNotEmpty &&
        task.stations.length == task.items.length;
  }

  bool get _isPictureStimulus {
    if (_isGridStimulus || _isLociStimulus) return false;
    if (_step == null) return false;
    return _taskKind(_step!.task) == 'visual';
  }

  Widget _stimulusBox(MetaTask task) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 14),
      decoration: BoxDecoration(
        color: context.cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: context.hairline, width: 2),
      ),
      alignment: Alignment.center,
      child: _isLociStimulus
          ? _lociStimulus(task)
          : _isPictureStimulus
          ? _pictureStimulus(task)
          : _isGridStimulus
          ? _gridStimulus(task)
          : _textStimulus(task),
    );
  }

  Widget _taskImage(String imageUrl) {
    if (imageUrl.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Image.network(
          imageUrl,
          height: 150,
          width: double.infinity,
          fit: BoxFit.cover,
          cacheHeight: 300,
          loadingBuilder: (context, child, progress) {
            if (progress == null) return child;
            return const SizedBox(
              height: 150,
              child: Center(
                child: SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(strokeWidth: 2.5),
                ),
              ),
            );
          },
          errorBuilder: (context, error, stackTrace) => const SizedBox.shrink(),
        ),
      ),
    );
  }

  Widget _techniqueCue(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: TextStyle(
          color: context.mutedText,
          fontStyle: FontStyle.italic,
          fontSize: 12,
          height: 1.4,
        ),
      ),
    );
  }

  Widget _lociStimulus(MetaTask task) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _taskImage(task.imageUrl),
        _techniqueCue(tr('lp_cue_loci')),
        for (var i = 0; i < task.stations.length; i++)
          Padding(
            padding: EdgeInsets.only(top: i == 0 ? 0 : 6),
            child: Row(
              children: [
                Container(
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    color: context.washBg,
                    shape: BoxShape.circle,
                    border: Border.all(color: context.washBorder, width: 2),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    '${i + 1}',
                    style: TextStyle(
                      color: context.inkText,
                      fontWeight: FontWeight.bold,
                      fontSize: 11,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    task.stations[i],
                    style: TextStyle(color: context.mutedText, fontSize: 12),
                  ),
                ),
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: context.washBg,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: context.washBorder),
                  ),
                  child: Text(
                    task.items[i],
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
    );
  }

  Widget _pictureStimulus(MetaTask task) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _taskImage(task.imageUrl),
        _techniqueCue(tr('lp_cue_picture')),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          alignment: WrapAlignment.center,
          children: [
            for (final item in task.items)
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
                    fontSize: 15,
                  ),
                ),
              ),
          ],
        ),
        if (task.stations.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              tr('ai_picture_sam', {'n': task.stations.length}),
              textAlign: TextAlign.center,
              style: TextStyle(color: context.mutedText, fontSize: 12),
            ),
          ),
      ],
    );
  }

  Widget _textStimulus(MetaTask task) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _taskImage(task.imageUrl),
        Text(
          task.items.isEmpty ? '···' : task.items.join('   '),
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 34,
            fontWeight: FontWeight.bold,
            color: context.inkText,
            letterSpacing: 3,
          ),
        ),
      ],
    );
  }

  Widget _gridStimulus(MetaTask task) {
    final lit = task.items.map(int.parse).toSet();
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var row = 0; row < 3; row++)
          Padding(
            padding: EdgeInsets.only(top: row == 0 ? 0 : 8),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (var col = 0; col < 3; col++)
                  Container(
                    width: 52,
                    height: 52,
                    margin: EdgeInsets.only(left: col == 0 ? 0 : 8),
                    decoration: BoxDecoration(
                      color: lit.contains(row * 3 + col)
                          ? const Color(0xFF14B8A6)
                          : context.hairline,
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _questionView() {
    if (_phase == _Phase.done) _prefillOwnMaterial();
    final task = _phase == _Phase.done && _tasks.isNotEmpty
        ? _tasks[_plan.isNotEmpty ? _plan.last.task : 0]
        : _activeTask!;
    final done = _phase == _Phase.done;
    final n = _tasks.length;
    final showNext =
        !done && (_picked != null || _recall != null) && _results.length < n;
    final lastCorrect = _results.isEmpty
        ? false
        : _results[_step?.task ?? _plan.last.task] ?? false;
    final round = _step?.task ?? 0;
    final roundDiff = lessonRoundDifficultyFor(
      widget.chapterIndex,
      widget.sectionIndex,
      widget.lessonIndex,
      round,
      n,
    );
    final recall =
        !done &&
        lessonRecallMode(
          chapter: widget.chapterIndex,
          difficulty: roundDiff,
          paradigm: task.paradigm,
        );
    final answerKey =
        task.correct >= 0 && task.correct < task.options.length
        ? task.options[task.correct]
        : '';
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (!done) _upgradeBar(),
          if (!done) _sessionProgressBar(),
          if (!done) _historyStrip(),
          if (!done && n > 1)
            Text(
              tr('lp_question_count', {
                'q': _answeredCount + 1,
                'n': n,
                'd': (_step?.task ?? 0) + 1,
              }),
              style: TextStyle(
                color: context.mutedText,
                fontWeight: FontWeight.w700,
                fontSize: 13,
              ),
            ),
          if (!done && n > 1) const SizedBox(height: 4),
          if (!done && _lag > 0 && n > 1)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Text(
                delayedQuestionLeadIn(
                  AppLocalizations.localeCode,
                  _step?.task ?? 0,
                  n,
                  _taskKind(_step?.task ?? 0),
                ),
                style: TextStyle(
                  color: context.mutedText,
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                ),
              ),
            ),
          Text(
            recall && task.paradigm == 'story-recall'
                ? tr('lp_retell')
                : task.question,
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurface,
              fontWeight: FontWeight.bold,
              fontSize: 20,
            ),
          ),
          const SizedBox(height: 12),
          if (recall)
            RecallTextField(
              key: const ValueKey('lesson-recall'),
              hint: lessonRecallHint(task.paradigm),
              keyboard: task.paradigm == 'story-recall'
                  ? TextInputType.multiline
                  : TextInputType.text,
              submitted: _recall != null,
              detail: _recall?.detail ?? '',
              exact: _recall?.exact ?? false,
              answerKey: answerKey,
              onSubmit: _submitRecall,
            ),
          if (!recall)
            for (var i = 0; i < task.options.length; i++)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: GestureDetector(
                  key: ValueKey('lesson-option-$i'),
                  onTap: () => _answer(i),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 13,
                    ),
                    decoration: BoxDecoration(
                      color: _picked != null && i == task.correct
                          ? const Color(
                              0xFF14B8A6,
                            ).withValues(alpha: 0.14)
                          : _picked != null && i == _picked
                          ? const Color(
                              0xFFFF6B6B,
                            ).withValues(alpha: 0.12)
                          : context.cardBg,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: _picked != null && i == task.correct
                            ? const Color(0xFF14B8A6)
                            : _picked != null && i == _picked
                            ? const Color(0xFFFF6B6B)
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
                            color: Color(0xFF14B8A6),
                            size: 22,
                            strokeWidth: 2.2,
                          ),
                        if (_picked != null &&
                            i == _picked &&
                            _picked != task.correct)
                          const HugeIcon(
                            icon: HugeIcons.strokeRoundedCancelCircle,
                            color: Color(0xFFFF6B6B),
                            size: 22,
                            strokeWidth: 2.2,
                          ),
                      ],
                    ),
                  ),
                ),
              ),
          if (showNext) ...[
            const SizedBox(height: 8),
            Text(
              lastCorrect ? tr('lp_locked_in') : tr('lp_good_rep'),
              textAlign: TextAlign.center,
              style: TextStyle(color: context.mutedText, fontSize: 13),
            ),
            const SizedBox(height: 12),
            EngramButton(
              key: const ValueKey('lesson-next-step'),
              label: tr('lp_next'),
              onPressed: _nextAfterAnswer,
            ),
          ],
          if (done && _saved) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: context.washBg,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: context.washBorder, width: 2),
              ),
              child: Column(
                children: [
                  Text(
                    tr('lp_stars', {'n': _stars}),
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: context.inkText,
                      fontWeight: FontWeight.w900,
                      fontSize: 18,
                    ),
                  ),
                  if (n > 1)
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(
                        tr('lp_correct_count', {
                          'c': _correctCount,
                          'n': n,
                        }),
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: context.mutedText,
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  const SizedBox(height: 4),
                  Text(
                    _correctCount >= n
                        ? tr('lp_locked_done')
                        : tr('lp_good_reps'),
                    textAlign: TextAlign.center,
                    style: TextStyle(color: context.mutedText, fontSize: 13),
                  ),
                  if (_nextGapDays != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      nextReviewLineIn(
                        AppLocalizations.localeCode,
                        daysLeft: _nextGapDays!,
                      ),
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: context.mutedText,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                  if (task.explanation.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text(
                      task.explanation,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: context.inkText,
                        fontStyle: FontStyle.italic,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            if (_recapText.isNotEmpty) ...[
              const SizedBox(height: 16),
              _aiRecapCard(),
            ],
            const SizedBox(height: 16),
            _missedCard(),
            const SizedBox(height: 16),
            _makeItYoursCard(),
            const SizedBox(height: 16),
            EngramButton(
              key: const ValueKey('lesson-continue'),
              label: tr('lp_continue'),
              onPressed: () => Navigator.of(context).pop(true),
            ),
          ],
        ],
      ),
    );
  }

  Widget _aiRecapCard() {
    return Container(
      key: const ValueKey('lesson-ai-recap'),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: context.cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: context.faintBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            tr('ai_recap_title'),
            style: TextStyle(
              color: context.mutedText,
              fontWeight: FontWeight.w900,
              fontSize: 11,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            _recapText,
            style: TextStyle(
              color: context.inkText,
              fontSize: 13,
              height: 1.45,
            ),
          ),
        ],
      ),
    );
  }

  Widget _missedCard() {
    final missedCount = _results.values.where((c) => !c).length;
    return Container(
      key: const ValueKey('lesson-missed'),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: context.cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: context.faintBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            tr('lp_missed_title'),
            style: TextStyle(
              color: context.mutedText,
              fontWeight: FontWeight.w900,
              fontSize: 11,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 6),
          if (missedCount == 0)
            Text(
              tr('lp_missed_hint'),
              style: TextStyle(color: context.inkText, fontSize: 13),
            )
          else if (_missedText.isNotEmpty)
            Text(
              _missedText,
              style: TextStyle(
                color: context.inkText,
                fontSize: 13,
                height: 1.45,
              ),
            )
          else
            EngramButton(
              key: const ValueKey('lesson-missed-diagnose'),
              label: tr('lp_missed_button'),
              isLoading: _missedBusy,
              onPressed: _missedBusy ? null : _runMissedDiagnose,
            ),
        ],
      ),
    );
  }

  Widget _makeItYoursCard() {
    final targets = _ownTargets;
    final busy = _ownBusy != null || _ownBuilding;
    return Container(
      key: const ValueKey('lesson-make-it-yours'),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: context.cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: context.faintBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            tr('lp_yours_title'),
            style: TextStyle(
              color: context.mutedText,
              fontWeight: FontWeight.w900,
              fontSize: 11,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            tr('lp_yours_blurb'),
            style: TextStyle(
              color: context.inkText,
              fontSize: 13,
              height: 1.45,
            ),
          ),
          const SizedBox(height: 10),
          DropdownButton<String>(
            key: const ValueKey('own-target-picker'),
            value: _effectiveTargetId,
            isExpanded: true,
            items: [
              for (final t in targets)
                DropdownMenuItem(
                  value: t.id,
                  child: Text(t.labelIn(AppLocalizations.localeCode)),
                ),
              for (final g in _userGoals)
                DropdownMenuItem(
                  value: g.id,
                  child: Text(
                    tr('lp_my_goal', {'title': g.title}),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
            ],
            onChanged: busy
                ? null
                : (v) {
                    if (v == null) return;
                    setState(() {
                      _ownTargetId = v;
                      _ownPrefilled = false;
                      _ownTeacherText = '';
                      _ownDiagnoseText = '';
                      _ownDynamic = null;
                    });
                    _prefillOwnMaterial();
                  },
          ),
          Align(
            alignment: Alignment.centerRight,
            child: GestureDetector(
              key: const ValueKey('own-manage-goals'),
              onTap: busy ? null : _openGoalsManager,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Text(
                  _userGoals.isEmpty
                      ? tr('lp_new_goal')
                      : tr('lp_manage_goals'),
                  style: TextStyle(
                    color: busy
                        ? context.mutedText
                        : const Color(0xFF45A3FF),
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            key: const ValueKey('own-material-input'),
            controller: _ownMaterialCtrl,
            maxLines: 3,
            minLines: 1,
            autocorrect: false,
            enableSuggestions: false,
            textCapitalization: TextCapitalization.none,
            decoration: InputDecoration(
              labelText: tr('myg_label_title'),
              hintText: tr('lp_hint_material'),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 10,
              ),
            ),
            style: TextStyle(color: context.inkText, fontSize: 14),
          ),
          const SizedBox(height: 8),
          TextField(
            key: const ValueKey('own-forgot-input'),
            controller: _ownForgotCtrl,
            maxLines: 2,
            minLines: 1,
            autocorrect: false,
            enableSuggestions: false,
            textCapitalization: TextCapitalization.none,
            decoration: InputDecoration(
              labelText: tr('lp_label_forgot'),
              hintText: tr('lp_hint_forgot'),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 10,
              ),
            ),
            style: TextStyle(color: context.inkText, fontSize: 14),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              OutlinedButton(
                key: const ValueKey('own-teach-button'),
                onPressed: busy ? null : _runOwnTeach,
                child: Text(tr('myg_teach_btn')),
              ),
              OutlinedButton(
                key: const ValueKey('own-diagnose-button'),
                onPressed:
                    busy || _ownForgotCtrl.text.trim().isEmpty
                    ? null
                    : _runOwnDiagnose,
                child: Text(tr('myg_diag_btn')),
              ),
              FilledButton(
                key: const ValueKey('own-build-button'),
                onPressed: busy ? null : _runOwnBuild,
                child: Text(tr('myg_build_btn')),
              ),
            ],
          ),
          if (busy) ...[
            const SizedBox(height: 10),
            LinearProgressIndicator(
              key: const ValueKey('own-ai-progress'),
              minHeight: 6,
              borderRadius: BorderRadius.circular(6),
            ),
            const SizedBox(height: 4),
            Text(
              _ownBuilding ? tr('myg_build_busy') : tr('lp_thinking'),
              textAlign: TextAlign.center,
              style: TextStyle(color: context.mutedText, fontSize: 12),
            ),
          ],
          if (_ownTeacherText.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(
              _ownTeacherText,
              key: const ValueKey('own-teach-result'),
              style: TextStyle(
                color: context.inkText,
                fontSize: 13,
                height: 1.45,
              ),
            ),
          ],
          if (_ownDiagnoseText.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(
              _ownDiagnoseText,
              key: const ValueKey('own-diagnose-result'),
              style: TextStyle(
                color: context.inkText,
                fontSize: 13,
                height: 1.45,
              ),
            ),
          ],
          if (_ownDynamic != null) ...[
            const SizedBox(height: 12),
            DynamicTaskView(
              key: const ValueKey('own-dynamic-task'),
              task: _ownDynamic!,
            ),
          ],
        ],
      ),
    );
  }
}
