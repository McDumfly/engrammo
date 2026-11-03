import 'dart:async';
import 'dart:math' as math;

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
import '../models/palace_drill.dart' show spatialSceneForLesson;
import '../models/recall_scoring.dart' show RecallScore, scoreTaskRecall;
import '../models/transfer_targets.dart';
import '../models/user_goals.dart';
import '../models/validated_tasks.dart' show localValidatedTask, specForId;
import 'my_goals.dart' show MyGoalsPage;
import '../services/app_feedback.dart';
import '../services/memory_growth.dart';
import '../services/memory_store.dart';
import '../services/meta_ai_service.dart';
import '../theme/app_colors.dart' show blue, coral, orange, success, teal;
import '../theme/app_theme.dart';
import '../theme/app_tokens.dart';
import '../widgets/ai_help_button.dart';
import '../widgets/app_buttons.dart';
import '../widgets/app_kit.dart';
import '../widgets/dynamic_task_view.dart';
import '../widgets/recall_inputs.dart';
import '../widgets/sam_overlay.dart';

String lessonKindFor(int chapter, int lesson, {int? section}) {
  const base = ['sensory', 'sequence', 'spatial', 'visual', 'verbal', 'verbal'];
  // Detail Studio's Pattern vault (ch 18, section 1) drills the visual
  // pattern-span paradigm (Luck & Vogel 1997; Cowan 2001) instead of the
  // generic visual kind, so every registered paradigm is reachable in
  // lessons — not only in duels. Section-agnostic calls keep the old
  // mapping for backwards compatibility.
  if (chapter == 18 && section == 1) return 'pattern';
  // Foundations drill the procedure their coach card teaches, so the
  // largest lab-proven wins land in week 1 instead of fieldwork:
  // chunk-span for Digit chunks (Miller 1956; Ericsson, Chase & Faloon
  // 1980), day-replay/story for the Journal (Gais, Lucas & Born 2006),
  // face-name/keyword for Baker breaker + Keyword chain (Morris et al.,
  // d ≈ 2.4; Atkinson & Raugh 1975). Section-agnostic calls keep the
  // old mapping (same rule as ch 18 above); both lesson paths (AI and
  // local) pass the section, so real lessons get the taught procedure.
  if (chapter == 1 && section == 0) return 'number';
  if (chapter == 4 && section != null) {
    const journal = ['replay', 'episodic', 'replay'];
    return journal[section.clamp(0, 2)];
  }
  if (chapter == 5 && section != null) {
    const names = ['face', 'foreign', 'semantic'];
    return names[section.clamp(0, 2)];
  }
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
  return lessonLagFor(lessonRoundsFor(chapter, section, lesson), chapter);
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

/// How many image rounds of ONE lesson run get an AI painting plus SAM
/// segmentation. Semantics: per lesson run (each `_startDrill` resets it),
/// counted only over rounds whose kind wants an image.
/// The models have unlimited credit: every chapter paints every round, so
/// the walk order always comes from SAM labels on a real picture.
int chapterImageBudget(int chapter, int rounds) {
  return rounds.clamp(0, 1 << 30);
}

String lessonRoundKindFor(
  int chapter,
  int lesson,
  int round,
  int rounds, {
  int? section,
}) {
  final base = lessonKindFor(chapter, lesson, section: section);
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
  if (!recallCapableParadigm(paradigm)) return false;
  if (chapter >= 6 && difficulty >= 3) return true;
  // Early single-word recall: producing one concrete word (a surname, a
  // meaning, a paired noun) runs the lab procedure in its natural
  // response format — Morris et al. face-name mnemonic (42%→79%,
  // d ≈ 2.4), Atkinson & Raugh (1975) keyword (72% vs 46%), Karpicke &
  // Roediger (2008) retrieval practice — and recall formats beat
  // recognition (Rowland 2014, g=0.50; Adesope et al. 2017, g=0.51).
  // Foundations sit at difficulty 1, so gating on >= 2 keeps the first
  // two lessons recognition-only scaffolding (~85% rule, Wilson et al.
  // 2019) and switches to production from lesson 3. Multi-item
  // paradigms (spans, stories, grids, walks) stay scaffolded until the
  // finals, as before.
  if (difficulty >= 2 &&
      (paradigm == 'face-name' ||
          paradigm == 'keyword-pair' ||
          paradigm == 'paired-associate')) {
    return true;
  }
  return false;
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
          kind: lessonRoundKindFor(
            chapter,
            lesson,
            r,
            rounds,
            section: section,
          ),
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

/// AI-státuszkártya gyorsítótárazott lekérdezéssel: a kulcs/hozzájárulás
/// ellenőrzése oldalanként egyszer fut, nem minden újraépüléskor.
class _AiStatusCard extends StatefulWidget {
  const _AiStatusCard();

  @override
  State<_AiStatusCard> createState() => _AiStatusCardState();
}

class _AiStatusCardState extends State<_AiStatusCard> {
  late final Future<List<bool>> _future = Future.wait([
    MetaAIService.hasAnyKey(),
    MetaAIService.cloudConsent(),
  ]);

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<bool>>(
      future: _future,
      builder: (context, snap) {
        final data = snap.data;
        final on = data != null && data.length == 2 && data[0] && data[1];
        return Container(
          key: const ValueKey('lesson-ai-status'),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: on ? teal.withValues(alpha: 0.10) : context.cardBg,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: on ? teal.withValues(alpha: 0.5) : context.faintBorder,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: on ? teal : context.mutedText.withValues(alpha: 0.5),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  on ? tr('ai_palace_on') : tr('ai_palace_off'),
                  style: TextStyle(
                    color: context.inkText,
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                    height: 1.4,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

enum _Phase { coach, loading, stimulus, question, done }

class _LessonPlayerPageState extends State<LessonPlayerPage>
    with WidgetsBindingObserver, TickerProviderStateMixin {
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
  int _gainEngrams = 0;
  int _streakNow = 0;
  late final AnimationController _shake = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 320),
  );
  late final AnimationController _starsIn = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  );

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

  void _onForgotChanged() {
    if (mounted) setState(() {});
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _ownForgotCtrl.addListener(_onForgotChanged);
    _loadUserGoals();
  }

  Future<void> _loadUserGoals() async {
    try {
      final goals = await MemoryStore.loadUserGoals();
      if (!mounted) return;
      setState(() => _userGoals = goals);
    } catch (_) {}
  }

  Future<void> _openGoalsManager() async {
    AppFeedback.light();
    await Navigator.of(context)
        .push(MaterialPageRoute(builder: (_) => const MyGoalsPage()));
    if (mounted) _loadUserGoals();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _sessionClock.stop();
    _questionClock.stop();
    _ownMaterialCtrl.dispose();
    _ownForgotCtrl.removeListener(_onForgotChanged);
    _ownForgotCtrl.dispose();
    _shake.dispose();
    _starsIn.dispose();
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
    } catch (_) {}
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
        MemoryStore.saveOwnMaterial(_effectiveTargetId, _ownMaterialCtrl.text),
      );
    }
    final built = await MetaAIService.buildDynamicTask(
      DynamicTaskRequest(
        targetId: _effectiveTargetId,
        customLabel: _effectiveCustomLabel,
        customStrategy: _effectiveCustomStrategy,
        customSource: _effectiveCustomSource,
        userMaterial: _ownMaterialCtrl.text,
        forgotNote: _ownForgotCtrl.text,
        difficulty: goal?.analysis?.difficulty ?? 1,
        locale: AppLocalizations.localeCode,
        seed:
            'own:${widget.chapterIndex}:${DateTime.now().millisecondsSinceEpoch}',
        wantsImage: widget.chapterIndex == 2,
      ),
    );
    // Palace Builder own-material blocks carry an illustration prompt:
    // paint and segment them so the player's own rooms get real pictures.
    final task = await MetaAIService.enrichDynamicTask(built);
    if (!mounted) return;
    setState(() {
      _ownBuilding = false;
      _ownDynamic = task;
    });
  }

  /// Palace Builder coach card: tells the player upfront whether every
  /// round will be AI-painted and SAM-segmented, or what to switch on
  /// (cloud consent + API key in Settings) to get the pictures.
  Widget _aiStatusCard() {
    return const _AiStatusCard();
  }

  Widget _sessionProgressBar() {
    final n = _tasks.length;
    if (n <= 1) return const SizedBox.shrink();
    final current = _step?.task;
    return Semantics(
      label: tr('lp_progress', {'done': _answeredCount, 'n': n}),
      child: Padding(
        key: const ValueKey('lesson-session-progress'),
        padding: const EdgeInsets.only(bottom: 16),
        child: Row(
          children: [
            for (var i = 0; i < n; i++) ...[
              if (i > 0) const SizedBox(width: 6),
              Expanded(
                child: AppProgressBar(
                  height: 8,
                  value: _results.containsKey(i) ? 1 : 0,
                  color: _results[i] == false ? coral : teal,
                  track: i == current && !_results.containsKey(i)
                      ? context.washBorder
                      : context.hairline,
                ),
              ),
            ],
          ],
        ),
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

  LessonSpec get _lesson {
    final ci = widget.chapterIndex.clamp(0, chapters.length - 1);
    final sections = chapters[ci].sections;
    final si = widget.sectionIndex.clamp(0, sections.length - 1);
    final lessons = sections[si].lessons;
    final li = widget.lessonIndex.clamp(0, lessons.length - 1);
    return lessons[li];
  }

  Future<MetaTask> _loadRoundTask(int round, {bool withImage = true}) async {
    final kind = lessonRoundKindFor(
      widget.chapterIndex,
      widget.lessonIndex,
      round,
      _rounds,
      section: widget.sectionIndex,
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
          scene: widget.chapterIndex == 2
              ? spatialSceneForLesson(widget.sectionIndex, widget.lessonIndex)
              : '',
          locale: AppLocalizations.localeCode,
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
      _gainEngrams = 0;
      _streakNow = 0;
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
    // SAM-as-default, honestly gated: the upgrade loop runs only when cloud
    // AI can actually paint and segment (key + consent). Offline lessons
    // keep their local tasks instead of churning through fallback rounds;
    // [_aiStatusCard] tells the player how to switch AI on.
    bool ready;
    try {
      ready = await MetaAIService.cloudReady();
    } catch (_) {
      ready = false;
    }
    if (!ready || !mounted) return;
    final rounds = _rounds;
    if (rounds <= 0 || !mounted) return;
    setState(() {
      _upgrading = true;
      _upgradeProgress = 0;
      _upgradeDone = 0;
      _upgradeTotal = rounds;
    });
    var done = 0;
    var imageLeft = chapterImageBudget(widget.chapterIndex, rounds);
    for (var r = 0; r < rounds; r++) {
      final kind = lessonRoundKindFor(
        widget.chapterIndex,
        widget.lessonIndex,
        r,
        rounds,
        section: widget.sectionIndex,
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
        // Csak a jövőbeli köröket cseréljük: az éppen nézett stimulus
        // memorizálás közben nem változhat meg a játékos alatt.
        final current = _step?.task ?? -1;
        if (r < _tasks.length && r > current && !_results.containsKey(r)) {
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
      AppFeedback.select();
    } else {
      AppFeedback.medium();
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
    if (option != task.correct) _shake.forward(from: 0);
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
    final sessionMinutes = (totalElapsed.inSeconds / 60).ceil().clamp(1, 240);
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
      final nextDepth = depthForNextSession(reps: reps[key] ?? 0, stars: stars);
      nextGap = reviewGapDays[nextDepth.clamp(0, reviewGapDays.length - 1)];
    } catch (_) {
      nextGap = null;
    }
    var gain = 0, streakNow = 0;
    try {
      final before = await MemoryStore.loadStreakState();
      final after = await MemoryStore.recordStreakDay();
      gain = after.engrams - before.engrams;
      streakNow = after.streak;
    } catch (_) {}
    if (!mounted) return;
    setState(() {
      _saved = true;
      _nextGapDays = nextGap;
      _gainEngrams = gain;
      _streakNow = streakNow;
      _phase = _Phase.done;
    });
    _starsIn.forward(from: 0);
    final earned = _stars.clamp(0, 3);
    for (var i = 0; i < earned; i++) {
      Future.delayed(Duration(milliseconds: 150 * i), () {
        if (!mounted || _phase != _Phase.done) return;
        AppFeedback.select();
      });
    }
    if (earned == 3) {
      Future.delayed(const Duration(milliseconds: 550), () {
        if (!mounted || _phase != _Phase.done) return;
        AppFeedback.heavy();
      });
    }
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
    return tr('lp_appbar_base', {'realm': realm, 'step': step});
  }

  bool get _needsExitConfirm =>
      _tasks.isNotEmpty &&
      (_phase == _Phase.stimulus || _phase == _Phase.question);

  Future<bool> _confirmExit() async {
    final leave = await showAppDialog<bool>(
      context,
      title: tr('lp_exit_title'),
      body: tr('lp_exit_body'),
      destructive: true,
      primary: AppDialogAction(tr('lp_exit_leave'), value: true),
      secondary: AppDialogAction(tr('lp_exit_stay'), value: false),
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
        appBar: AppTopBar(
          title: _appBarTitle(
            chapterRealmIn(AppLocalizations.localeCode, widget.chapterIndex),
          ),
          bottom: _upgradeLine(),
          leading: EngramBackButton(onPressed: _onBackPressed),
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
    final intro = isTrackIntroLesson(
      widget.chapterIndex,
      widget.sectionIndex,
      widget.lessonIndex,
    );
    return _coachCompactView(intro: intro);
  }

  String _sessionInfoText(bool foundation) {
    if (foundation) return tr('lp_session_foundation', {'n': _rounds});
    if (_lag <= 0) return tr('lp_session_plain', {'n': _rounds});
    if (_lag == 1) return tr('lp_session_lag_one', {'n': _rounds});
    return tr('lp_session_lag_many', {'n': _rounds, 'lag': _lag});
  }

  Widget _sessionInfoCard(bool foundation) {
    return Container(
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
              _sessionInfoText(foundation),
              style: TextStyle(
                color: context.mutedText,
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _techniqueEssenceCard(CoachContent coach) {
    return Container(
      key: const ValueKey('lesson-technique-essence'),
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
            tr('lp_technique_title'),
            style: TextStyle(
              color: context.mutedText,
              fontWeight: FontWeight.w900,
              fontSize: 12,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 8),
          for (var i = 0; i < coach.steps.length; i++)
            Padding(
              padding: EdgeInsets.only(
                bottom: i + 1 < coach.steps.length ? 6 : 0,
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 24,
                    height: 24,
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
                        fontSize: 12,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(top: 3),
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
        ],
      ),
    );
  }

  Widget _depthChip() {
    return Container(
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
    );
  }

  Widget _detailsExpander(
    CoachContent coach,
    bool foundation, {
    bool intro = false,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: context.cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: context.faintBorder),
      ),
      clipBehavior: Clip.antiAlias,
      padding: const EdgeInsets.fromLTRB(14, 4, 14, 14),
      child: AppDisclosure(
        key: const ValueKey('lesson-details'),
        title: Text(
          tr('lp_details_title'),
          style: TextStyle(
            color: context.inkText,
            fontWeight: FontWeight.w700,
            fontSize: 14,
          ),
        ),
        children: [
          if (intro && foundation) ...[
            _techniqueEssenceCard(coach),
            const SizedBox(height: 12),
          ],
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              tr('lp_about_title'),
              style: TextStyle(
                color: context.mutedText,
                fontWeight: FontWeight.w900,
                fontSize: 12,
                letterSpacing: 1.2,
              ),
            ),
          ),
          const SizedBox(height: 6),
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              coach.intro,
              style: TextStyle(
                color: context.inkText,
                fontSize: 14,
                height: 1.5,
              ),
            ),
          ),
          const SizedBox(height: 14),
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              tr('lp_how_title'),
              style: TextStyle(
                color: context.mutedText,
                fontWeight: FontWeight.w900,
                fontSize: 12,
                letterSpacing: 1.2,
              ),
            ),
          ),
          const SizedBox(height: 6),
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              tr('lp_how_body', {'n': _rounds}),
              style: TextStyle(
                color: context.inkText,
                fontSize: 13,
                height: 1.5,
              ),
            ),
          ),
          const SizedBox(height: 14),
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              tr('lp_why_title'),
              style: TextStyle(
                color: context.mutedText,
                fontWeight: FontWeight.w900,
                fontSize: 12,
                letterSpacing: 1.2,
              ),
            ),
          ),
          const SizedBox(height: 6),
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              coach.why,
              style: TextStyle(
                color: context.inkText,
                fontSize: 13,
                height: 1.45,
              ),
            ),
          ),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              coach.source,
              style: TextStyle(
                color: context.mutedText,
                fontStyle: FontStyle.italic,
                fontSize: 12,
              ),
            ),
          ),
          const SizedBox(height: 12),
          _transferTargetsCard(),
          if (foundation && !intro) ...[
            const SizedBox(height: 12),
            _workedExampleCard(),
          ],
        ],
      ),
    );
  }

  Widget _coachCompactView({bool intro = false}) {
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
        _sessionInfoCard(foundation),
        if (widget.chapterIndex == 2) ...[
          const SizedBox(height: 12),
          _aiStatusCard(),
        ],
        if (lagIntro) ...[const SizedBox(height: 12), _lagIntroCard()],
        const SizedBox(height: 12),
        if (intro && foundation)
          _workedExampleCard()
        else
          _techniqueEssenceCard(coach),
        const SizedBox(height: 16),
        EngramButton(
          key: const ValueKey('lesson-coach-next'),
          label: tr('lp_start'),
          onPressed: () => _startDrill(),
        ),
        const SizedBox(height: 12),
        _depthChip(),
        const SizedBox(height: 12),
        _detailsExpander(coach, foundation, intro: intro),
      ],
    );
  }

  String _taskKind(int taskIndex) => lessonRoundKindFor(
    widget.chapterIndex,
    widget.lessonIndex,
    taskIndex,
    _tasks.length,
    section: widget.sectionIndex,
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
              fontSize: 12,
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
              fontSize: 12,
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
              fontSize: 12,
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
        child: AppLoader(
          key: const ValueKey('lesson-loading-progress'),
          instant: true,
          caption: _upgradeTotal > 0
              ? tr('lp_loading_n', {
                  'done': _upgradeDone,
                  'total': _upgradeTotal,
                })
              : tr('lp_loading'),
        ),
      ),
    );
  }

  PreferredSizeWidget _upgradeLine() {
    final show =
        _upgrading && (_phase == _Phase.stimulus || _phase == _Phase.question);
    return PreferredSize(
      preferredSize: const Size.fromHeight(4),
      child: SizedBox(
        height: 4,
        child: show
            ? Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Semantics(
                  label: tr('lp_upgrade', {
                    'done': _upgradeDone,
                    'total': _upgradeTotal,
                  }),
                  child: AppProgressBar(
                    key: const ValueKey('lesson-upgrade-progress'),
                    value: _upgradeTotal > 0 ? _upgradeProgress : null,
                    height: 4,
                  ),
                ),
              )
            : null,
      ),
    );
  }

  Widget _stimulusView() {
    final task = _activeTask;
    final step = _step;
    if (task == null || step == null) return const SizedBox.shrink();
    final n = _tasks.length;
    final round = step.task;
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
      children: [
        _sessionProgressBar(),
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

  /// AI picture plus the numbered SAM walk overlaid. In Palace Builder
  /// lessons a missing picture is never silent: once the background
  /// upgrade settled, the player sees why there is no painting instead of
  /// an empty gap.
  Widget _samImage(MetaTask task) {
    if (task.imageUrl.isEmpty) {
      if (widget.chapterIndex == 2 && !_upgrading) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Text(
            tr('ai_picture_offline'),
            textAlign: TextAlign.center,
            style: TextStyle(
              color: context.mutedText,
              fontStyle: FontStyle.italic,
              fontSize: 12,
            ),
          ),
        );
      }
      return const SizedBox.shrink();
    }
    return SamOverlay(
      imageUrl: task.imageUrl,
      stations: task.stations,
      samLabels: task.samLabels,
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
        _samImage(task),
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
                      fontSize: 12,
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
        _samImage(task),
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
        _samImage(task),
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
    final lit = {for (final raw in task.items) int.tryParse(raw.trim()) ?? -1}
      ..remove(-1);
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
                          ? teal
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

  Widget _starIcon(int index) {
    final filled = index < _stars.clamp(0, 3);
    final start = (150 * index) / 900;
    final end = ((150 * index) + 600) / 900;
    final curved = CurvedAnimation(
      parent: _starsIn,
      curve: Interval(start, end.clamp(0.0, 1.0), curve: Curves.elasticOut),
    );
    return ScaleTransition(
      scale: Tween<double>(begin: 0.4, end: 1.0).animate(curved),
      child: HugeIcon(
        icon: HugeIcons.strokeRoundedStar,
        color: filled ? orange : context.faintBorder,
        size: 34,
        strokeWidth: 2.2,
      ),
    );
  }

  Widget _questionView() {
    if (_phase == _Phase.done) _prefillOwnMaterial();
    final task = _phase == _Phase.done && _tasks.isNotEmpty
        ? _tasks[_plan.isNotEmpty
              ? _plan.last.task.clamp(0, _tasks.length - 1)
              : 0]
        : _activeTask;
    if (task == null) return const SizedBox.shrink();
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
    final answerKey = task.correct >= 0 && task.correct < task.options.length
        ? task.options[task.correct]
        : '';
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (!done) _sessionProgressBar(),
          if (!done && n > 1)
            Builder(
              builder: (_) {
                final answeredThis = _picked != null || _recall != null;
                final q = (answeredThis ? _answeredCount : _answeredCount + 1)
                    .clamp(1, n);
                return Text(
                  _lag > 0
                      ? tr('lp_question_count', {
                          'q': q,
                          'n': n,
                          'd': (_step?.task ?? 0) + 1,
                        })
                      : tr('lp_question_simple', {'q': q, 'n': n}),
                  style: TextStyle(
                    color: context.mutedText,
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                  ),
                );
              },
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
          if (!done)
            Text(
              recall && task.paradigm == 'story-recall'
                  ? tr('lp_retell')
                  : task.question,
              style: AppText.title.copyWith(color: context.inkText),
            ),
          if (!done) const SizedBox(height: 12),
          if (!done && recall)
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
          if (!done && !recall)
            for (var i = 0; i < task.options.length; i++)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Tappable(
                  key: ValueKey('lesson-option-$i'),
                  haptic: false,
                  onTap: () => _answer(i),
                  child: AnimatedBuilder(
                    animation: _shake,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      curve: Curves.easeOutCubic,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 13,
                      ),
                      decoration: BoxDecoration(
                        color: _picked != null && i == task.correct
                            ? success.withValues(alpha: 0.12)
                            : _picked != null && i == _picked
                            ? coral.withValues(alpha: 0.12)
                            : context.cardBg,
                        borderRadius: BorderRadius.circular(AppRadius.l),
                        border: Border.all(
                          color: _picked != null && i == task.correct
                              ? success
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
                              color: success,
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
                    builder: (context, child) {
                      final wrong =
                          _picked != null &&
                          i == _picked &&
                          _picked != task.correct;
                      if (!wrong || _shake.value == 0) return child!;
                      return Transform.translate(
                        offset: Offset(
                          math.sin(_shake.value * math.pi * 4) *
                              8 *
                              (1 - _shake.value),
                          0,
                        ),
                        child: child,
                      );
                    },
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
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      for (var i = 0; i < 3; i++) ...[
                        if (i > 0) const SizedBox(width: 8),
                        _starIcon(i),
                      ],
                    ],
                  ),
                  const SizedBox(height: 8),
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
                        tr('lp_correct_count', {'c': _correctCount, 'n': n}),
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: context.mutedText,
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  if (_streakNow > 0 || _gainEngrams > 0)
                    Padding(
                      padding: const EdgeInsets.only(top: 10),
                      child: Wrap(
                        alignment: WrapAlignment.center,
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          if (_streakNow > 0)
                            AppBadge(
                              label: tr('lp_streak_pill', {'n': _streakNow}),
                              color: coral,
                            ),
                          if (_gainEngrams > 0)
                            AppBadge(
                              label: tr('lp_engram_pill', {'n': _gainEngrams}),
                              color: orange,
                            ),
                        ],
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
            if (_results.values.any((c) => !c)) ...[
              const SizedBox(height: 16),
              _missedCard(),
            ],
            const SizedBox(height: 16),
            EngramButton(
              key: const ValueKey('lesson-continue'),
              label: tr('lp_continue'),
              onPressed: () => Navigator.of(context).pop(true),
            ),
            const SizedBox(height: 16),
            Container(
              decoration: BoxDecoration(
                color: context.cardBg,
                borderRadius: BorderRadius.circular(AppRadius.m),
                border: Border.all(color: context.faintBorder),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 14),
              child: AppDisclosure(
                key: const ValueKey('lesson-make-it-yours-toggle'),
                title: Text(
                  tr('lp_yours_title'),
                  style: AppText.body.copyWith(
                    color: context.inkText,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                children: [
                  Padding(
                    padding: const EdgeInsets.only(bottom: 14),
                    child: _makeItYoursCard(),
                  ),
                ],
              ),
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
              fontSize: 12,
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
              fontSize: 12,
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

  String _targetLabel(List<TransferTarget> targets) {
    for (final t in targets) {
      if (t.id == _effectiveTargetId) {
        return t.labelIn(AppLocalizations.localeCode);
      }
    }
    for (final g in _userGoals) {
      if (g.id == _effectiveTargetId) {
        return tr('lp_my_goal', {'title': g.title});
      }
    }
    return '';
  }

  void _openTargetPicker(List<TransferTarget> targets) {
    showAppSheet(
      context,
      builder: (sheetContext) {
        final sheetNav = Navigator.of(sheetContext);
        void pick(String id) {
          sheetNav.pop();
          if (id == _effectiveTargetId) return;
          setState(() {
            _ownTargetId = id;
            _ownPrefilled = false;
            _ownTeacherText = '';
            _ownDiagnoseText = '';
            _ownDynamic = null;
          });
          _prefillOwnMaterial();
        }

        Widget option({required String id, required String label}) {
          final selected = id == _effectiveTargetId;
          return Tappable(
            onTap: () => pick(id),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      label,
                      style: TextStyle(
                        color: selected
                            ? context.accentText(blue)
                            : context.inkText,
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (selected)
                    HugeIcon(
                      icon: HugeIcons.strokeRoundedTick02,
                      color: context.accentText(blue),
                      size: 20,
                      strokeWidth: 2.2,
                    ),
                ],
              ),
            ),
          );
        }

        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 12),
            Text(
              tr('lp_yours_title'),
              style: TextStyle(
                color: context.mutedText,
                fontWeight: FontWeight.w900,
                fontSize: 12,
                letterSpacing: 1.2,
              ),
            ),
            const SizedBox(height: 8),
            ListView(
              shrinkWrap: true,
              children: [
                for (final t in targets)
                  option(
                    id: t.id,
                    label: t.labelIn(AppLocalizations.localeCode),
                  ),
                for (final g in _userGoals)
                  option(id: g.id, label: tr('lp_my_goal', {'title': g.title})),
              ],
            ),
            const SizedBox(height: 24),
          ],
        );
      },
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
            tr('lp_yours_blurb'),
            style: TextStyle(
              color: context.inkText,
              fontSize: 13,
              height: 1.45,
            ),
          ),
          const SizedBox(height: 10),
          Tappable(
            key: const ValueKey('own-target-picker'),
            onTap: busy ? null : () => _openTargetPicker(targets),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                color: context.softBg,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: context.hairline, width: 2),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      _targetLabel(targets),
                      style: TextStyle(color: context.inkText, fontSize: 14),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  HugeIcon(
                    icon: HugeIcons.strokeRoundedArrowDown01,
                    color: context.mutedText,
                    size: 20,
                    strokeWidth: 2,
                  ),
                ],
              ),
            ),
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
                    color: busy ? context.mutedText : blue,
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          AppTextField(
            key: const ValueKey('own-material-input'),
            controller: _ownMaterialCtrl,
            maxLines: 3,
            minLines: 1,
            autocorrect: false,
            enableSuggestions: false,
            textCapitalization: TextCapitalization.none,
            label: tr('myg_label_title'),
            hint: tr('lp_hint_material'),
          ),
          const SizedBox(height: 8),
          AppTextField(
            key: const ValueKey('own-forgot-input'),
            controller: _ownForgotCtrl,
            maxLines: 2,
            minLines: 1,
            autocorrect: false,
            enableSuggestions: false,
            textCapitalization: TextCapitalization.none,
            label: tr('lp_label_forgot'),
            hint: tr('lp_hint_forgot'),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              EngramButton(
                key: const ValueKey('own-teach-button'),
                variant: EngramButtonVariant.secondary,
                height: 52,
                onPressed: busy ? null : _runOwnTeach,
                label: tr('myg_teach_btn'),
              ),
              if (_ownForgotCtrl.text.trim().isNotEmpty)
                EngramButton(
                  key: const ValueKey('own-diagnose-button'),
                  variant: EngramButtonVariant.secondary,
                  height: 52,
                  onPressed: busy ? null : _runOwnDiagnose,
                  label: tr('myg_diag_btn'),
                ),
              EngramButton(
                key: const ValueKey('own-build-button'),
                height: 52,
                onPressed: busy ? null : _runOwnBuild,
                label: tr('myg_build_btn'),
              ),
            ],
          ),
          if (busy) ...[
            const SizedBox(height: 10),
            AppProgressBar(key: const ValueKey('own-ai-progress'), height: 6),
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
