import 'dart:async';

import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';

import '../models/curriculum.dart';
import '../models/lesson_content.dart';
import '../models/meta_task.dart';
import '../models/validated_tasks.dart'
    show localValidatedTask, specForId;
import '../services/app_feedback.dart';
import '../services/memory_store.dart';
import '../services/meta_ai_service.dart';
import '../theme/app_theme.dart';
import '../widgets/app_buttons.dart';

/// Task kind for a lesson: every chapter trains its own track's memory
/// type, so a finished track means supermemory in that type. The two
/// historic mastery chapters (6-7) mix kinds like real competition does.
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
  return base[trackOfChapter(chapter)];
}

/// Difficulty 1..5 for a lesson: rises with depth inside the track plus
/// section and lesson index. Track finals start at 3 — they are endgames.
int lessonDifficultyFor(int chapter, int section, int lesson) {
  final depth = chapterDepth(chapter);
  final base = depth >= 4 ? 3 : depth >= 2 ? 2 : 1;
  return (base + section + lesson ~/ 2).clamp(1, 5);
}

/// How many drills one lesson station plays in a row (1..5).
///
/// Early stations stay single-task so beginners always meet one
/// stimulus → one question. Later sections chain several drills into
/// one session; deep track chapters add one, finals add two.
int lessonRoundsFor(int chapter, int section, int lesson) {
  if (chapter < 0) return 1;
  final depth = chapterDepth(chapter);
  final extra = depth >= 4 ? 2 : depth >= 2 ? 1 : 0;
  return (1 + section + lesson ~/ 2 + extra).clamp(1, 5);
}

/// How many intervening stimuli separate a stimulus from its question.
///
/// 0 = classic immediate recall (one stimulus, one question).
/// 1-2 = delayed/crossed recall: the app shows 1-2 more stimuli first
/// and only then asks the earlier question — but only in sessions
/// with 3+ rounds, i.e. once the user reached harder stations.
int lessonLagFor(int rounds, int chapter) {
  if (rounds < 3) return 0;
  if (rounds >= 5 || chapterDepth(chapter) >= 4) return 2;
  return 1;
}

/// Cross-training kind for odd rounds of a base chapter session.
///
/// Same-modality neighbours stay close (spatial ↔ visual), the rest
/// cross into sequential recall — the skill hard stations need.
String _crossKindFor(String base) {
  switch (base) {
    case 'spatial':
      return 'visual';
    case 'visual':
      return 'spatial';
    case 'sequence':
      return 'verbal';
    default:
      return 'sequence';
  }
}

/// Task kind of one round inside a lesson session.
///
/// Single-task stations keep the lesson kind. Multi-round sessions
/// alternate the base kind with a cross kind (odd rounds), so drills
/// genuinely interleave; the mastery arc (chapters 6-7) rotates its
/// mix per round instead.
String lessonRoundKindFor(int chapter, int lesson, int round, int rounds) {
  final base = lessonKindFor(chapter, lesson);
  if (rounds < 3 || chapter < 0) return base;
  if (chapter < 6) {
    if (round.isEven) return base;
    return _crossKindFor(base);
  }
  if (chapter == 6) {
    const mixed = ['number', 'verbal', 'sequence', 'spatial'];
    return mixed[(lesson + round) % mixed.length];
  }
  const hard = ['number', 'sequence', 'spatial', 'number'];
  return hard[(lesson + round) % hard.length];
}

/// Difficulty of one round: the lesson difficulty, escalating +1 in
/// the second half of the session so later drills are harder.
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

/// Stars for a finished multi-drill session.
///
/// All correct = fast 3 / slow 2 (average pace decides, same 15s
/// bar as single drills); majority correct = 2; otherwise 1 for
/// finishing. A finished lesson never scores 0. For a single round
/// this matches [starsForLesson] exactly.
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

/// One step of a lesson session plan: either show a stimulus or ask
/// the (possibly delayed) question of an earlier stimulus.
class LessonPlanStep {
  final bool stimulus;
  final int task;
  const LessonPlanStep({required this.stimulus, required this.task});
}

/// Session plan: stimulus/question order with [lag] intervening
/// stimuli before each question.
///
/// lag=0 → S0,Q0,S1,Q1…; lag=1 → S0,S1,Q0,S2,Q1…; lag=2 →
/// S0,S1,S2,Q0,S3,Q1… Questions always stay in stimulus order.
List<LessonPlanStep> lessonSessionPlan(int rounds, int lag) {
  final plan = <LessonPlanStep>[];
  final pending = <int>[];
  for (var r = 0; r < rounds; r++) {
    plan.add(LessonPlanStep(stimulus: true, task: r));
    pending.add(r);
    if (r < rounds - 1) {
      // At most one delayed question per stimulus: keeps the pace
      // steady while earlier items wait in memory.
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

/// Egy lecke összes körének betöltése össz-időkorláttal.
///
/// A térbeli kör élő kulccsal három soros Meta-hívást is indít
/// (feladat → kép → szegmentálás), ami rossz hálózaton egyenként
/// 12 s-ig ülhet — a játékos addig csak spinnert látna. Ezért az egész
/// indítás legfeljebb [timeout] ideig vár hálózatra, utána (vagy
/// bármilyen váratlan hiba esetén) a helyi, validált tartalékfeladatokkal
/// folytatja. A lecke soha nem ragad a töltőképernyőn.
Future<List<MetaTask>> loadLessonTasks({
  required int chapter,
  required int section,
  required int lesson,
  required Future<MetaTask> Function(int round) loadRound,
  Duration timeout = const Duration(seconds: 15),
}) async {
  final rounds = lessonRoundsFor(chapter, section, lesson);
  try {
    final tasks = await Future.wait([
      for (var r = 0; r < rounds; r++) loadRound(r),
    ]).timeout(timeout);
    if (tasks.isEmpty) throw StateError('no tasks');
    return tasks;
  } catch (_) {
    return [
      for (var r = 0; r < rounds; r++)
        localValidatedTask(
          MetaTaskRequest(
            kind: lessonRoundKindFor(chapter, lesson, r, rounds),
            difficulty: lessonRoundDifficultyFor(
              chapter,
              section,
              lesson,
              r,
              rounds,
            ),
            seed: '$chapter-$section-$lesson-r$r',
            locale: 'en',
          ),
        ),
    ];
  }
}

/// Full-screen lesson: coach explanation first, then a drill session.
///
/// Flow: coach card -> stimulus/question plan -> stars -> save.
/// Early stations play a single drill; harder stations chain several
/// drills with delayed, crossed questions (a question may arrive
/// 1-2 stimuli after its own stimulus).
/// A finished lesson always stores 1-3 stars via [MemoryStore], so the
/// learning path, chapters list and streak all advance.
class LessonPlayerPage extends StatefulWidget {
  final int chapterIndex;
  final int sectionIndex;
  final int lessonIndex;
  const LessonPlayerPage({
    super.key,
    required this.chapterIndex,
    required this.sectionIndex,
    required this.lessonIndex,
  });

  @override
  State<LessonPlayerPage> createState() => _LessonPlayerPageState();
}

enum _Phase { coach, loading, stimulus, question, done }

class _LessonPlayerPageState extends State<LessonPlayerPage> {
  _Phase _phase = _Phase.coach;
  List<MetaTask> _tasks = const [];
  List<LessonPlanStep> _plan = const [];
  int _planPos = 0;
  int? _picked;
  final Map<int, bool> _results = {};
  final List<Duration> _latencies = [];
  DateTime? _questionShownAt;
  DateTime? _sessionStart;
  int _stars = 0;
  bool _saved = false;

  int get _rounds => lessonRoundsFor(
    widget.chapterIndex,
    widget.sectionIndex,
    widget.lessonIndex,
  );
  int get _lag => lessonLagFor(_rounds, widget.chapterIndex);

  LessonPlanStep? get _step =>
      _planPos < _plan.length ? _plan[_planPos] : null;
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

  Future<MetaTask> _loadRoundTask(int round) async {
    final kind = lessonRoundKindFor(
      widget.chapterIndex,
      widget.lessonIndex,
      round,
      _rounds,
    );
    final difficulty = lessonRoundDifficultyFor(
      widget.chapterIndex,
      widget.sectionIndex,
      widget.lessonIndex,
      round,
      _rounds,
    );
    final seed =
        '${widget.chapterIndex}-${widget.sectionIndex}-${widget.lessonIndex}-r$round';
    try {
      final task = await MetaAIService.generateTask(
        MetaTaskRequest(
          kind: kind,
          difficulty: difficulty,
          seed: seed,
          locale: 'en',
        ),
      );
      // Térbeli kör: SAM-állomások + Muse-palotakép (élő kulccsal);
      // vizuális kör: Muse-jelenetkép. Mindkettő best-effort, a helyi
      // tartalék ugyanazt a validált paradigmát tanítja.
      if (kind == 'spatial') {
        return await MetaAIService.enrichSpatialTask(
          task,
          difficulty: difficulty,
          seed: seed,
        );
      }
      if (kind == 'visual') {
        return await MetaAIService.enrichVisualTask(task, seed: seed);
      }
      return task;
    } catch (_) {
      // Last-resort fallback is still a validated paradigm task, never a
      // hand-written one-off: same procedure, seeded stimulus.
      return localValidatedTask(
        MetaTaskRequest(
          kind: kind,
          difficulty: difficulty,
          seed: seed,
          locale: 'en',
        ),
      );
    }
  }

  Future<void> _startDrill() async {
    setState(() {
      _phase = _Phase.loading;
      _picked = null;
      _results.clear();
      _latencies.clear();
      _saved = false;
      _stars = 0;
      _planPos = 0;
    });
    // Párhuzamos töltés: élő kulccsal egy térbeli kör 3 Meta-hívás
    // (Spark + Image + SAM), sorosan túl lassú lenne. A sorrendet a
    // Future.wait megőrzi. Össz-időkorlát + helyi tartalék: lógó
    // hálózatnál sem marad a játékos a töltőképernyőn.
    final tasks = await loadLessonTasks(
      chapter: widget.chapterIndex,
      section: widget.sectionIndex,
      lesson: widget.lessonIndex,
      loadRound: _loadRoundTask,
    );
    if (!mounted) return;
    setState(() {
      _tasks = tasks;
      _plan = lessonSessionPlan(_rounds, _lag);
      _planPos = 0;
      _picked = null;
      _sessionStart = DateTime.now();
      _phase = _plan.first.stimulus ? _Phase.stimulus : _Phase.question;
      if (_phase == _Phase.question) _questionShownAt = DateTime.now();
    });
  }

  void _advancePlan() {
    if (_planPos + 1 >= _plan.length) return;
    setState(() {
      _planPos++;
      _picked = null;
      _phase = _plan[_planPos].stimulus ? _Phase.stimulus : _Phase.question;
      if (_phase == _Phase.question) _questionShownAt = DateTime.now();
    });
  }

  void _showQuestion() {
    // A rezgést az EngramButton adja, itt már nem rezgünk duplán.
    _advancePlan();
  }

  Future<void> _answer(int option) async {
    final task = _activeTask;
    if (_picked != null || task == null || _step?.stimulus == true) return;
    final taskIndex = _step!.task;
    final correct = option == task.correct;
    final elapsed = _questionShownAt == null
        ? Duration.zero
        : DateTime.now().difference(_questionShownAt!);
    setState(() {
      _picked = option;
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
    // Otherwise the view shows feedback + a NEXT button that calls
    // _nextAfterAnswer; the final answer above finishes immediately
    // so single-drill stations keep their old one-tap flow.
  }

  void _nextAfterAnswer() {
    if (_results.length >= _tasks.length) return;
    _advancePlan();
  }

  Future<void> _finishSession() async {
    final totalElapsed = _sessionStart == null
        ? Duration.zero
        : DateTime.now().difference(_sessionStart!);
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
    unawaited(MemoryStore.recordStreakDay());
    if (!mounted) return;
    setState(() {
      _saved = true;
      _phase = _Phase.done;
    });
  }

  String _appBarTitle(String realm) {
    final base = '$realm • Step ${widget.lessonIndex + 1}';
    if (_phase == _Phase.coach || _tasks.isEmpty) return base;
    return '$base • $_answeredCount/${_tasks.length} done';
  }

  @override
  Widget build(BuildContext context) {
    final chapter = chapters[widget.chapterIndex];
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: const EngramBackButton(),
        title: Text(
          _appBarTitle(chapter.realm),
          style: TextStyle(
            color: Theme.of(context).colorScheme.onSurface,
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
      ),
      body: switch (_phase) {
        _Phase.coach => _coachView(),
        _Phase.loading => const Center(child: CircularProgressIndicator()),
        _Phase.stimulus => _stimulusView(),
        _Phase.question || _Phase.done => _questionView(),
      },
    );
  }

  Widget _coachView() {
    final coach = coachFor(widget.chapterIndex, widget.sectionIndex);
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
      children: [
        Text(
          _lesson.title,
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
                  _rounds <= 1
                      ? 'Single drill: memorize, then answer.'
                      : _lag <= 0
                      ? 'Session: $_rounds drills in a row.'
                      : 'Session: $_rounds drills, questions come $_lag later — hold each item!',
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
                'WHY IT WORKS',
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
        const SizedBox(height: 20),
        EngramButton(
          key: const ValueKey('lesson-coach-next'),
          label: 'START DRILL',
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

  Widget _stimulusView() {
    final task = _activeTask!;
    final n = _tasks.length;
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
      children: [
        if (n > 1)
          Text(
            'Drill ${_step!.task + 1}/$n — hold it!',
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
            '${specForId(task.paradigm).display} · ${task.source}',
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
          label: 'I MEMORIZED IT',
          onPressed: _showQuestion,
        ),
        const SizedBox(height: 8),
        Text(
          _lag > 0 && n > 1
              ? 'The question may come later — keep it in mind!'
              : 'The prompt disappears — answer from memory!',
          textAlign: TextAlign.center,
          style: TextStyle(color: context.mutedText, fontSize: 13),
        ),
      ],
    );
  }

  /// Local spatial/visual tasks encode lit cells as '0'-'8' indices:
  /// render those as a real 3x3 grid, everything else as text.
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

  /// Loci-inger: rendezett állomás → szó párok (SAM vagy helyi útvonal).
  bool get _isLociStimulus {
    final task = _activeTask;
    if (task == null) return false;
    return task.stations.isNotEmpty &&
        task.items.isNotEmpty &&
        task.stations.length == task.items.length;
  }

  /// Képi inger: vizuális kör, nem csempe-alakban (Shepard/Standing-paradigma).
  bool get _isPictureStimulus {
    if (_isGridStimulus || _isLociStimulus) return false;
    if (_step == null) return false;
    return _taskKind(_step!.task) == 'visual';
  }

  Widget _stimulusBox(MetaTask task) {
    // Kompakt méretezés: a 8 állomásos loci-séta és a tovább gomb
    // görgetés nélkül is elfér — a séta egyben látszik, nem kell
    // vadászni a gombra.
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

  /// Élő Muse-kép az inger fölött; offline (üres URL) nem rajzol semmit.
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
          // Placeholder while the Meta image loads (no layout jump),
          // downsampled to the displayed height.
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
          errorBuilder: (context, error, stackTrace) =>
              const SizedBox.shrink(),
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

  /// Loci-séta: számozott állomások, mindegyiken egy szó. A tanuló
  /// dolga: állomásonként EGY bizarr, mozgó képet alkotni, sorrendben.
  Widget _lociStimulus(MetaTask task) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _taskImage(task.imageUrl),
        _techniqueCue(
          'One station, one bizarre moving image — always in walking '
          'order. (Maguire et al. 2003)',
        ),
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

  /// Képi inger: jelenetkép (élő kulccsal) + megnevezendő részletek.
  /// Offline a leírásból fejben épül a kép — ez maga a kettős kódolás
  /// gyakorlása (Paivio).
  Widget _pictureStimulus(MetaTask task) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _taskImage(task.imageUrl),
        _techniqueCue(
          'Name every detail instantly — words anchor pictures. '
          '(Shepard 1967; Standing 1973)',
        ),
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
      ],
    );
  }

  Widget _textStimulus(MetaTask task) {
    return Text(
      task.items.isEmpty ? '···' : task.items.join('   '),
      textAlign: TextAlign.center,
      style: TextStyle(
        fontSize: 34,
        fontWeight: FontWeight.bold,
        color: context.inkText,
        letterSpacing: 3,
      ),
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
    // Done phase shows the summary of the last answered task.
    final task = _phase == _Phase.done && _tasks.isNotEmpty
        ? _tasks[_plan.isNotEmpty ? _plan.last.task : 0]
        : _activeTask!;
    final done = _phase == _Phase.done;
    final n = _tasks.length;
    final showNext = !done && _picked != null && _results.length < n;
    final lastCorrect = _results.isEmpty
        ? false
        : _results[_step?.task ?? _plan.last.task] ?? false;
    // Mindig felépülő nézet (nem lusta lista): a záró tanító-magyarázat
    // hosszú, de a CONTINUE gombnak akkor is a fán kell lennie.
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
        if (!done && n > 1)
          Text(
            'Question ${_answeredCount + 1}/$n — drill ${(_step?.task ?? 0) + 1}/$n',
            style: TextStyle(
              color: context.mutedText,
              fontWeight: FontWeight.w700,
              fontSize: 13,
            ),
          ),
        if (!done && n > 1) const SizedBox(height: 4),
        Text(
          task.question,
          style: TextStyle(
            color: Theme.of(context).colorScheme.onSurface,
            fontWeight: FontWeight.bold,
            fontSize: 20,
          ),
        ),
        const SizedBox(height: 12),
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
                  color: context.cardBg,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: _picked != null && i == task.correct
                        ? const Color(0xFF14B8A6)
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
                  ],
                ),
              ),
            ),
          ),
        if (showNext) ...[
          const SizedBox(height: 8),
          Text(
            lastCorrect
                ? 'Locked in — on to the next one!'
                : 'Good rep anyway — errors plus feedback still teach.',
            textAlign: TextAlign.center,
            style: TextStyle(color: context.mutedText, fontSize: 13),
          ),
          const SizedBox(height: 12),
          EngramButton(
            key: const ValueKey('lesson-next-step'),
            label: 'NEXT',
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
                  '$_stars/3 stars',
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
                      '$_correctCount/$n correct',
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
                      ? 'Locked in. Retrieval is the workout.'
                      : 'Good reps anyway — errors plus feedback still teach.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: context.mutedText, fontSize: 13),
                ),
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
          const SizedBox(height: 16),
          EngramButton(
            key: const ValueKey('lesson-continue'),
            label: 'CONTINUE',
            onPressed: () => Navigator.of(context).pop(true),
          ),
        ],
        ],
      ),
    );
  }
}
