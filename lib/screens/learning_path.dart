import '../theme/app_theme.dart';

import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';

import '../l10n/app_localizations.dart';
import '../models/claims_policy.dart' show foundationDoseText;
import '../models/marathon.dart'
    show
        daysUntilReviewDue,
        depthForNextSession,
        depthForReps,
        labDoseMinutesPerTrack,
        labDoseProgressLineIn,
        practiceDepths,
        practiceRoundLocked,
        reviewLockedMessageIn,
        reviewStatusLabelIn,
        sessionsDoneOnTrack,
        sessionsToFinishTrack,
        stretchDoseMinutesPerTrack,
        tierForAverageDepthIn,
        trackDepthAverage,
        trackProgramLineIn;
import '../widgets/ai_help_button.dart';
import '../widgets/app_buttons.dart';
import '../widgets/honesty_sheet.dart';
import '../widgets/missions_sheet.dart';
import '../services/app_feedback.dart';
import '../theme/app_colors.dart'
    show blue, blueDark, teal, orange, coral, sky, trail;
import 'battle_zone.dart' show BattleZoneView;
import 'benchmark.dart' show BenchmarkHubPage;
import 'brain_league.dart' show BrainLeaguePage;
import '../models/curriculum.dart'
    show
        SectionSpec,
        chapterRealmIn,
        chapterTaglineIn,
        chapters,
        chaptersForTrack,
        lessonDetailIn,
        lessonTitleIn,
        memoryTracks,
        sectionNameIn,
        sectionTechniqueIn,
        trackName,
        trackPositionOfChapter,
        trackTag;
import 'kreeds_profile.dart' show KreedsProfilePage;
import 'lesson_player.dart' show LessonPlayerPage;
import 'memory_profile.dart' show MemoryAssessmentIntroPage;
import 'my_goals.dart' show MyGoalsPage;
import '../services/memory_store.dart';
import '../utils/streak_restore.dart';
import '../widgets/stats_top_bar.dart';
import '../widgets/streak_restore_dialog.dart';

import '../widgets/synapse_navbar.dart';

class LearningPathPage extends StatefulWidget {
  final int initialTrack;
  const LearningPathPage({super.key, this.initialTrack = 0});

  @override
  State<LearningPathPage> createState() => _LearningPathPageState();
}

class _Track {
  final String name;
  final String module;
  final List<List<dynamic>> icon;
  final Color tint;
  const _Track(this.name, this.module, this.icon, this.tint);
}

const _tracks = [
  _Track(
    'Sensory',
    'From first echo to golden ear',
    HugeIcons.strokeRoundedAudioWave01,
    sky,
  ),
  _Track(
    'Working memory',
    'From 4 digits to longer numbers',
    HugeIcons.strokeRoundedLayers01,
    blue,
  ),
  _Track(
    'Spatial',
    'From one room to grand palace',
    HugeIcons.strokeRoundedCastle01,
    teal,
  ),
  _Track(
    'Visual',
    'From first image to gallery final',
    HugeIcons.strokeRoundedEye,
    orange,
  ),
  _Track(
    'Episodic',
    'From today to life archive',
    HugeIcons.strokeRoundedNotebook01,
    coral,
  ),
  _Track(
    'Semantic',
    'From 2 names to confident recall',
    HugeIcons.strokeRoundedBrain01,
    blueDark,
  ),
];

int _effectiveStars(
  Map<String, int> progress,
  int chapter,
  int section,
  int lesson,
  int base,
) {
  return progress[MemoryStore.lessonKey(chapter, section, lesson)] ?? base;
}

bool _effectiveActive(
  Map<String, int> progress,
  int chapter,
  int section,
  int lesson,
  List<SectionSpec> sections,
) {
  final lessons = sections[section].lessons;
  var hasAny = false;
  for (var i = 0; i < lessons.length; i++) {
    if (progress.containsKey(MemoryStore.lessonKey(chapter, section, i))) {
      hasAny = true;
      break;
    }
  }
  if (!hasAny) return lessons[lesson].active;
  for (var i = 0; i < lessons.length; i++) {
    final stars =
        progress[MemoryStore.lessonKey(chapter, section, i)] ??
        lessons[i].stars;
    if (stars <= 0) return i == lesson;
  }
  return false;
}

bool _sectionComplete(Map<String, int> progress, int chapter, int section) {
  final spec = chapters[chapter].sections[section];
  for (var l = 0; l < spec.lessons.length; l++) {
    if (_effectiveStars(progress, chapter, section, l, spec.lessons[l].stars) <=
        0) {
      return false;
    }
  }
  return true;
}

bool _sectionLocked(Map<String, int> progress, int chapter, int section) {
  if (section <= 0) return false;
  return !_sectionComplete(progress, chapter, section - 1);
}

bool _lessonLocked(
  Map<String, int> progress,
  int chapter,
  int section,
  int lesson,
) {
  if (lesson <= 0) return false;
  final lessons = chapters[chapter].sections[section].lessons;
  for (var i = 0; i < lesson && i < lessons.length; i++) {
    if (_effectiveStars(progress, chapter, section, i, lessons[i].stars) <= 0) {
      return true;
    }
  }
  return false;
}

bool _chapterComplete(Map<String, int> progress, int chapter) {
  final spec = chapters[chapter];
  for (var s = 0; s < spec.sections.length; s++) {
    for (var l = 0; l < spec.sections[s].lessons.length; l++) {
      if (_effectiveStars(
            progress,
            chapter,
            s,
            l,
            spec.sections[s].lessons[l].stars,
          ) <=
          0) {
        return false;
      }
    }
  }
  return true;
}

bool _chapterLocked(Map<String, int> progress, List<int> order, int pos) {
  if (pos <= 0) return false;
  return !_chapterComplete(progress, order[pos - 1]);
}

class _LearningPathPageState extends State<LearningPathPage> {
  static List<SynapseTab> get _navTabs => [
    SynapseTab(HugeIcons.strokeRoundedHome01, tr('lpt_home')),
    SynapseTab(HugeIcons.strokeRoundedTrophy, tr('lpt_league')),
    SynapseTab(HugeIcons.strokeRoundedSwords, tr('lpt_arena')),
    SynapseTab(HugeIcons.strokeRoundedDumbbell01, tr('lpt_practice')),
    SynapseTab(HugeIcons.strokeRoundedUser02, tr('lpt_profile')),
  ];

  String get _helpTopic {
    switch (_tab) {
      case 0:
        return AiHelpTopics.path;
      case 1:
        return AiHelpTopics.league;
      case 2:
        return AiHelpTopics.battle;
      case 3:
        return AiHelpTopics.benchmark;
      default:
        return AiHelpTopics.general;
    }
  }

  Widget _tabBody() {
    switch (_tab) {
      case 1:
        return const BrainLeaguePage();
      case 2:
        return const BattleZoneView();
      case 3:
        return const BenchmarkHubPage();
      case 4:
        return const KreedsProfilePage();
      default:
        return _flowView();
    }
  }

  int _tab = 0;
  int _memory = 0;
  int? _chapterPos;
  int _goalsCount = 0;
  int _streak = 0;
  int _engrams = 0;
  List<DateTime> _streakHistory = const [];
  Map<String, int> _progress = const {};
  Map<String, int> _reps = const {};
  Map<String, int> _trackMinutes = const {};
  Map<String, DateTime> _doneDates = const {};
  bool _showBackToNow = false;
  final ScrollController _scroll = ScrollController();
  final GlobalKey _nowKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    _memory = widget.initialTrack.clamp(0, _tracks.length - 1);
    _scroll.addListener(_onScroll);
    _loadHome();
  }

  Future<void> _loadHome() async {
    Map<String, int> progress = const {};
    Map<String, int> reps = const {};
    Map<String, int> trackMinutes = const {};
    Map<String, DateTime> doneDates = const {};
    try {
      progress = await MemoryStore.loadChapterProgress();
      try {
        reps = await MemoryStore.loadLessonReps();
        trackMinutes = await MemoryStore.loadTrackMinutes();
        doneDates = await MemoryStore.loadLessonDoneDates();
      } catch (_) {
        reps = const {};
        trackMinutes = const {};
        doneDates = const {};
      }
    } catch (_) {
      progress = const {};
    }
    var goalsCount = 0;
    try {
      goalsCount = (await MemoryStore.loadUserGoals()).length;
    } catch (_) {
    }
    StreakState? streakState;
    try {
      streakState = await MemoryStore.loadStreakState();
    } catch (_) {
      streakState = null;
    }
    if (!mounted) return;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final s = streakState;
    setState(() {
      _progress = progress;
      _reps = reps;
      _trackMinutes = trackMinutes;
      _doneDates = doneDates;
      _goalsCount = goalsCount;
      if (s != null) {
        _streakHistory = s.history;
        _streak = StreakRestore.displayStreak(
          stored: s.streak,
          history: s.history,
          today: today,
        );
        _engrams = s.engrams;
      }
    });
    _maybeShowRestorePrompt();
  }

  Future<void> _loadProgress() async {
    Map<String, int> progress;
    try {
      progress = await MemoryStore.loadChapterProgress();
    } catch (_) {
      return;
    }
    if (!mounted) return;
    Map<String, int> reps;
    Map<String, int> trackMinutes;
    Map<String, DateTime> doneDates;
    try {
      reps = await MemoryStore.loadLessonReps();
      trackMinutes = await MemoryStore.loadTrackMinutes();
      doneDates = await MemoryStore.loadLessonDoneDates();
    } catch (_) {
      reps = const {};
      trackMinutes = const {};
      doneDates = const {};
    }
    if (!mounted) return;
    setState(() {
      _progress = progress;
      _reps = reps;
      _trackMinutes = trackMinutes;
      _doneDates = doneDates;
    });
  }

  Future<void> _loadGoalsCount() async {
    try {
      final goals = await MemoryStore.loadUserGoals();
      if (!mounted) return;
      setState(() => _goalsCount = goals.length);
    } catch (_) {
    }
  }

  Future<void> _loadStreak() async {
    StreakState state;
    try {
      state = await MemoryStore.loadStreakState();
    } catch (_) {
      return;
    }
    if (!mounted) return;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    setState(() {
      _streakHistory = state.history;
      _streak = StreakRestore.displayStreak(
        stored: state.streak,
        history: state.history,
        today: today,
      );
      _engrams = state.engrams;
    });
    _maybeShowRestorePrompt();
  }

  Future<void> _maybeShowRestorePrompt() async {
    if (!mounted) return;
    final lastPrompt = await MemoryStore.loadRestorePromptDay();
    final now = DateTime.now();
    if (!StreakRestore.shouldShowRestorePrompt(
      lastPromptDay: lastPrompt,
      todayKey: MemoryStore.todayKey(now),
    )) {
      return;
    }
    final today = DateTime(now.year, now.month, now.day);
    final plan = StreakRestore.planStreakRestore(
      history: _streakHistory,
      today: today,
    );
    if (plan == null || !mounted) return;
    await MemoryStore.markRestorePromptShown(now);
    if (!mounted) return;
    _openRestoreDialog(plan);
  }

  void _openRestoreDialog(RestorePlan plan) {
    showDialog<void>(
      context: context,
      builder: (ctx) => StreakRestoreDialog(
        plan: plan,
        engrams: _engrams,
        onRestore: () {
          Navigator.pop(ctx);
          _restoreStreak(plan);
        },
        onLater: () => Navigator.pop(ctx),
      ),
    );
  }

  Future<void> _restoreStreak(RestorePlan plan) async {
    final cost = StreakRestore.streakRestoreCost(plan.missedDays);
    if (_engrams < cost) {
      if (!mounted) return;
      AppFeedback.heavy();
      return;
    }
    final confirmed = await confirmStreakRestore(context, plan);
    if (confirmed != true || !mounted) return;
    final outcome = await MemoryStore.restoreStreak();
    if (!mounted) return;
    switch (outcome) {
      case StreakRestoreOutcome.restored:
        await _loadStreak();
        if (!mounted) return;
        AppFeedback.medium();
      case StreakRestoreOutcome.insufficientFunds:
        AppFeedback.heavy();
      case StreakRestoreOutcome.notEligible:
        await _loadStreak();
        if (!mounted) return;
        AppFeedback.light();
    }
  }

  bool get _streakBroken {
    final now = DateTime.now();
    return StreakRestore.planStreakRestore(
          history: _streakHistory,
          today: DateTime(now.year, now.month, now.day),
        ) !=
        null;
  }

  void _onStreakTap() {
    AppFeedback.light();
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final plan = StreakRestore.planStreakRestore(
      history: _streakHistory,
      today: today,
    );
    if (plan == null) {
      return;
    }
    _openRestoreDialog(plan);
  }

  void _onScroll() {
    final show = _scroll.offset > 500;
    if (show != _showBackToNow) setState(() => _showBackToNow = show);
  }

  @override
  void dispose() {
    _scroll.removeListener(_onScroll);
    _scroll.dispose();
    super.dispose();
  }

  void _warpToNow() {
    AppFeedback.light();
    final ctx = _nowKey.currentContext;
    if (ctx == null) return;
    Scrollable.ensureVisible(ctx, duration: const Duration(milliseconds: 500));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      extendBody: true,
      body: Stack(
        children: [
          Positioned.fill(
            child: Column(
              children: [
                if (_tab != 4)
                  SafeArea(
                    bottom: false,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                      child: StatsTopBar(
                        icon: _tracks[_memory].icon,
                        tint: _tracks[_memory].tint,
                        streak: _streak,
                        engrams: _engrams,
                        streakBroken: _streakBroken,
                        onIconTap: _openTrackPicker,
                        onStreakTap: _onStreakTap,
                        onGoalsTap: _openGoals,
                        goalsCount: _goalsCount,
                      ),
                    ),
                  ),
                Expanded(child: _tabBody()),
              ],
            ),
          ),
          Positioned(
            left: 16,
            bottom: 110,
            child: AiHelpButton(topic: _helpTopic),
          ),
          if (_tab == 0 && _showBackToNow)
            Positioned(
              right: 16,
              bottom: 110,
              child: FloatingActionButton.small(
                heroTag: 'back-to-now',
                backgroundColor: context.cardBg,
                shape: StadiumBorder(
                  side: BorderSide(color: context.washBorder),
                ),
                onPressed: _warpToNow,
                child: const HugeIcon(
                  icon: HugeIcons.strokeRoundedArrowUp01,
                  color: blue,
                  size: 22,
                  strokeWidth: 2.2,
                ),
              ),
            ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: SynapseNavBar(
              index: _tab,
              onSelect: (i) => setState(() => _tab = i),
              tabs: _navTabs,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _openGoals() async {
    AppFeedback.light();
    await Navigator.of(context)
        .push(MaterialPageRoute(builder: (_) => const MyGoalsPage()));
    if (mounted) _loadGoalsCount();
  }

  int _shownChapterPos(List<int> order) {
    final pinned = _chapterPos;
    if (pinned != null) return pinned.clamp(0, order.length - 1);
    for (var pos = 0; pos < order.length; pos++) {
      if (!_chapterComplete(_progress, order[pos])) return pos;
    }
    return order.length - 1;
  }

  void _goToChapter(int pos, List<int> order) {
    AppFeedback.light();
    setState(() => _chapterPos = pos.clamp(0, order.length - 1));
    if (_scroll.hasClients) _scroll.jumpTo(0);
  }

  Widget _flowView() {
    final order = chaptersForTrack(_memory);
    final pos = _shownChapterPos(order);
    final chapterIdx = order[pos];
    final chapter = chapters[chapterIdx];
    final chapLocked = _chapterLocked(_progress, order, pos);
    const offsets = [0.0, -64.0, 64.0, 0.0];
    final body = <Widget>[];
    var station = 0;

    for (var s = 0; s < chapter.sections.length; s++) {
      final section = chapter.sections[s];
      final secLocked = chapLocked || _sectionLocked(_progress, chapterIdx, s);
      body.add(const SizedBox(height: 20));
      body.add(_sectionHeader(chapterIdx, s, section));
      var prev = 0.0;
      var linked = false;
      for (var l = 0; l < section.lessons.length; l++) {
        final lesson = section.lessons[l];
        final offset = offsets[l % offsets.length];
        final stars = _effectiveStars(
          _progress,
          chapterIdx,
          s,
          l,
          lesson.stars,
        );
        final lessonLocked =
            !secLocked &&
            stars <= 0 &&
            _lessonLocked(_progress, chapterIdx, s, l);
        if (linked) {
          body.add(_riverLink(prev, offset, locked: secLocked || lessonLocked));
        }
        prev = offset;
        linked = true;
        if (secLocked || lessonLocked) {
          body.add(
            Container(
              key: ValueKey('path-lesson-$chapterIdx-$s-$l'),
              child: _stationLocked(
                offset: offset,
                title: lessonTitleIn(
                  AppLocalizations.localeCode,
                  chapterIdx,
                  s,
                  l,
                ),
              ),
            ),
          );
          continue;
        }
        if (stars > 0) {
          final doneKey = MemoryStore.lessonKey(chapterIdx, s, l);
          final doneReps = _reps[doneKey] ?? 0;
          final doneDepth = doneReps > 0 ? depthForReps(doneReps) : 1;
          final doneStatus = reviewStatusLabelIn(
            AppLocalizations.localeCode,
            lastDone: _doneDates[doneKey],
            depth: doneDepth,
            now: DateTime.now(),
          );
          body.add(
            GestureDetector(
              key: ValueKey('path-lesson-$chapterIdx-$s-$l'),
              onTap: () => _openLesson(chapterIdx, s, l),
              child: _stationDone(
                offset: offset,
                title: lessonTitleIn(
                  AppLocalizations.localeCode,
                  chapterIdx,
                  s,
                  l,
                ),
                sub: doneStatus,
              ),
            ),
          );
          continue;
        }
        final active = _effectiveActive(
          _progress,
          chapterIdx,
          s,
          l,
          chapter.sections,
        );
        if (active) {
          station++;
          body.add(
            Container(
              key: _nowKey,
              child: GestureDetector(
                key: ValueKey('path-lesson-$chapterIdx-$s-$l'),
                onTap: () => _openLesson(chapterIdx, s, l),
                child: _stationNow(
                  offset: offset,
                  number: station,
                  title: lessonTitleIn(
                    AppLocalizations.localeCode,
                    chapterIdx,
                    s,
                    l,
                  ),
                  lessonIcon: lesson.icon,
                ),
              ),
            ),
          );
          continue;
        }
        station++;
        body.add(
          GestureDetector(
            key: ValueKey('path-lesson-$chapterIdx-$s-$l'),
            onTap: () => _openLesson(chapterIdx, s, l),
            child: _stationTodo(
              offset: offset,
              number: station,
              title: lessonTitleIn(
                AppLocalizations.localeCode,
                chapterIdx,
                s,
                l,
              ),
            ),
          ),
        );
      }
      if (s == 0 && !secLocked) {
        body.add(_riverLink(prev, 0, locked: false));
        body.add(
          _bonusStop(
            realm: chapterRealmIn(
              AppLocalizations.localeCode,
              chapterIdx,
            ),
          ),
        );
        body.add(const SizedBox(height: 4));
      } else if (secLocked) {
        body.add(const SizedBox(height: 10));
        body.add(_lockedNote());
      } else {
        body.add(const SizedBox(height: 8));
      }
    }
    body.add(const SizedBox(height: 24));
    if (pos < order.length - 1) {
      body.add(_nextChapterButton(order, pos));
      body.add(const SizedBox(height: 16));
    }
    body.add(_trackEndCard(order));
    body.add(const SizedBox(height: 130));

    return SafeArea(
      top: false,
      child: Column(
        children: [
          const SizedBox(height: 12),
          _chapterPager(order, pos),
          Expanded(
            child: SingleChildScrollView(
              controller: _scroll,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: body,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _openTrackPicker() async {
    final picked = await Navigator.of(context).push<int>(
      MaterialPageRoute(builder: (_) => _TrackPickerPage(selected: _memory)),
    );
    if (picked != null && picked != _memory) {
      setState(() {
        _memory = picked;
        _chapterPos = null;
      });
    }
  }

  Widget _sectionHeader(int chapterIdx, int index, SectionSpec section) {
    final bool locked = _sectionLocked(_progress, chapterIdx, index);
    final Color accent = locked ? _dim(context.faintBorder, 0.6) : blue;
    final Color sub = locked ? _dim(context.mutedText, 0.6) : context.mutedText;
    final String name = sectionNameIn(
      AppLocalizations.localeCode,
      chapterIdx,
      index,
    );
    final String technique = sectionTechniqueIn(
      AppLocalizations.localeCode,
      chapterIdx,
      index,
    );
    final int total = section.lessons.length;
    var done = 0;
    for (var l = 0; l < section.lessons.length; l++) {
      if (_effectiveStars(
            _progress,
            chapterIdx,
            index,
            l,
            section.lessons[l].stars,
          ) >
          0) {
        done++;
      }
    }
    final String status = locked
        ? tr('lpt_locked')
        : done >= total && total > 0
        ? tr('lpt_completed')
        : tr('lpt_done_n', {'done': done, 'n': total});
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 4),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () {
          AppFeedback.light();
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => _ChapterListPage(initialChapterIndex: chapterIdx),
            ),
          );
        },
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Container(
              width: 4,
              height: 34,
              decoration: BoxDecoration(
                color: accent,
                borderRadius: BorderRadius.circular(999),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    tr('lpt_part_title', {'i': index + 1}),
                    style: TextStyle(
                      color: locked ? sub : blue,
                      fontWeight: FontWeight.bold,
                      fontSize: 11,
                      letterSpacing: 1.2,
                    ),
                  ),
                  Text(
                    name,
                    style: TextStyle(
                      color: locked
                          ? _dim(context.inkText, 0.6)
                          : context.inkText,
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                    ),
                  ),
                  Text(
                    '$technique • $status',
                    style: TextStyle(color: sub, fontSize: 12),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 4),
            HugeIcon(
              icon: locked
                  ? HugeIcons.strokeRoundedLock
                  : HugeIcons.strokeRoundedArrowRight01,
              color: sub,
              size: 20,
              strokeWidth: 2,
            ),
          ],
        ),
      ),
    );
  }

  Widget _riverLink(double from, double to, {bool locked = false}) {
    return SizedBox(
      height: 46,
      width: double.infinity,
      child: LayoutBuilder(
        builder: (context, c) {
          final cx = c.maxWidth / 2;
          return CustomPaint(
            painter: _RiverPainter(
              fromX: cx + from,
              toX: cx + to,
              color: locked ? context.hairline : trail,
            ),
          );
        },
      ),
    );
  }

  Color _dim(Color c, [double f = 0.7]) =>
      c.withValues(alpha: (c.a * f).clamp(0.0, 1.0));

  Widget _stationShell({
    required double offset,
    required String title,
    required Widget badge,
    bool faintTitle = false,
    bool dimmed = false,
    String? sub,
  }) {
    final labelBg = dimmed ? _dim(context.cardBg) : context.cardBg;
    final labelBorder = dimmed
        ? _dim(faintTitle ? context.faintBorder : context.washBorder)
        : (faintTitle ? context.faintBorder : context.washBorder);
    final labelText = dimmed
        ? _dim(faintTitle ? context.mutedText : context.inkText)
        : (faintTitle ? context.mutedText : context.inkText);
    final content = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        badge,
        const SizedBox(height: 8),
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 200),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
            decoration: BoxDecoration(
              color: labelBg,
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: labelBorder),
              boxShadow: [
                BoxShadow(
                  color: dimmed
                      ? _dim(context.faintBorder)
                      : context.faintBorder,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Text(
              title,
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: labelText,
                fontWeight: FontWeight.w600,
                fontSize: 12.5,
              ),
            ),
          ),
        ),
        if (sub != null) ...[
          const SizedBox(height: 4),
          Text(
            sub,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: dimmed ? _dim(context.mutedText) : context.mutedText,
              fontWeight: FontWeight.w600,
              fontSize: 11,
            ),
          ),
        ],
      ],
    );
    final centered = Center(child: content);
    if (offset == 0) return centered;
    return Transform.translate(offset: Offset(offset, 0), child: centered);
  }

  Widget _block3d({
    required double size,
    required Color top,
    required Color edge,
    required Color border,
    required Widget child,
    double depth = 7,
    double radius = 18,
  }) {
    final r = BorderRadius.circular(radius);
    return SizedBox(
      width: size,
      height: size + depth,
      child: Stack(
        children: [
          Positioned(
            left: 0,
            right: 0,
            top: depth,
            bottom: 0,
            child: Container(
              decoration: BoxDecoration(
                color: edge,
                borderRadius: r,
                border: Border.all(color: border, width: 2.5),
              ),
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            top: 0,
            height: size,
            child: Container(
              decoration: BoxDecoration(
                color: top,
                borderRadius: r,
                border: Border.all(color: border, width: 2.5),
              ),
              alignment: Alignment.center,
              child: child,
            ),
          ),
        ],
      ),
    );
  }

  Widget _stationDone({
    required double offset,
    required String title,
    String? sub,
  }) {
    return _stationShell(
      offset: offset,
      title: title,
      faintTitle: true,
      sub: sub,
      badge: _block3d(
        size: 62,
        top: context.washBg,
        edge: blue,
        border: blue,
        child: const HugeIcon(
          icon: HugeIcons.strokeRoundedCheckmarkCircle02,
          color: blue,
          size: 28,
          strokeWidth: 2.2,
        ),
      ),
    );
  }

  Widget _stationTodo({
    required double offset,
    required int number,
    required String title,
  }) {
    return _stationShell(
      offset: offset,
      title: title,
      badge: _block3d(
        size: 62,
        top: context.cardBg,
        edge: context.washBorder,
        border: context.washBorder,
        child: Text(
          '$number',
          style: const TextStyle(
            color: blue,
            fontWeight: FontWeight.bold,
            fontSize: 22,
          ),
        ),
      ),
    );
  }

  Widget _stationNow({
    required double offset,
    required int number,
    required String title,
    required List<List<dynamic>> lessonIcon,
  }) {
    final badge = _block3d(
      size: 76,
      depth: 8,
      radius: 22,
      top: blue,
      edge: blueDark,
      border: blueDark,
      child: HugeIcon(
        icon: lessonIcon,
        color: Colors.white,
        size: 32,
        strokeWidth: 2.0,
      ),
    );
    final centered = Center(child: badge);
    final shifted = offset == 0
        ? centered
        : Transform.translate(offset: Offset(offset, 0), child: centered);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        shifted,
        const SizedBox(height: 6),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
          decoration: BoxDecoration(
            color: blue,
            borderRadius: BorderRadius.circular(999),
          ),
          child: Text(
            tr('lpt_station_up', {'n': number}),
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 12,
            ),
          ),
        ),
        const SizedBox(height: 6),
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 200),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
            decoration: BoxDecoration(
              color: context.cardBg,
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: context.washBorder),
              boxShadow: [
                BoxShadow(
                  color: context.faintBorder,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Text(
              title,
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: context.inkText,
                fontWeight: FontWeight.w600,
                fontSize: 12.5,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _stationLocked({required double offset, required String title}) {
    return _stationShell(
      offset: offset,
      title: title,
      faintTitle: true,
      dimmed: true,
      badge: _block3d(
        size: 62,
        top: _dim(context.faintBg),
        edge: _dim(context.faintBorder),
        border: _dim(context.faintBorder),
        child: HugeIcon(
          icon: HugeIcons.strokeRoundedLock,
          color: _dim(context.mutedText),
          size: 24,
          strokeWidth: 2.0,
        ),
      ),
    );
  }

  Future<void> _openLesson(int chapter, int section, int lesson) async {
    final loc = trackPositionOfChapter(chapter);
    if (_chapterLocked(_progress, chaptersForTrack(loc.track), loc.pos)) return;
    if (_sectionLocked(_progress, chapter, section)) return;
    final stars = _effectiveStars(
      _progress,
      chapter,
      section,
      lesson,
      chapters[chapter].sections[section].lessons[lesson].stars,
    );
    if (stars <= 0 && _lessonLocked(_progress, chapter, section, lesson)) {
      return;
    }
    final key = MemoryStore.lessonKey(chapter, section, lesson);
    final reps = _reps[key] ?? 0;
    final nextDepth = depthForNextSession(reps: reps, stars: stars);
    final lastDone = _doneDates[key];
    final now = DateTime.now();
    if (practiceRoundLocked(
      lastDone: lastDone,
      depth: nextDepth,
      stars: stars,
      now: now,
    )) {
      final daysLeft = daysUntilReviewDue(
        lastDone: lastDone,
        depth: nextDepth,
        now: now,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            reviewLockedMessageIn(
              AppLocalizations.localeCode,
              depth: nextDepth,
              daysLeft: daysLeft,
            ),
          ),
        ),
      );
      return;
    }
    AppFeedback.light();
    final done = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => LessonPlayerPage(
          chapterIndex: chapter,
          sectionIndex: section,
          lessonIndex: lesson,
          practiceDepth: nextDepth,
        ),
      ),
    );
    if (done == true && mounted) {
      await _loadProgress();
      await _loadStreak();
    }
  }

  Widget _bonusStop({required String realm}) {
    return Center(
      child: Container(
        width: 210,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: context.cardBg,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: context.washBorder,
            width: 2,
            strokeAlign: BorderSide.strokeAlignInside,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            HugeIcon(
              icon: HugeIcons.strokeRoundedGift,
              color: blue,
              size: 24,
              strokeWidth: 2.0,
            ),
            SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    tr('lpt_bonus'),
                    style: TextStyle(
                      color: context.inkText,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                  Text(
                    tr('lpt_bonus_sub'),
                    style: TextStyle(color: context.mutedText, fontSize: 12),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _lockedNote() {
    final sub = Theme.of(context).colorScheme.onSurfaceVariant;
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        HugeIcon(
          icon: HugeIcons.strokeRoundedLock,
          color: sub,
          size: 15,
          strokeWidth: 2.2,
        ),
        const SizedBox(width: 6),
        Text(
          tr('lpt_locked_note'),
          style: TextStyle(color: sub, fontSize: 13),
        ),
      ],
    );
  }

  Widget _chapterPager(List<int> order, int pos) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        GestureDetector(
          key: const ValueKey('chapter-pager'),
          behavior: HitTestBehavior.opaque,
          onHorizontalDragEnd: (details) {
            final velocity = details.primaryVelocity ?? 0;
            if (velocity < -200 && pos < order.length - 1) {
              _goToChapter(pos + 1, order);
            } else if (velocity > 200 && pos > 0) {
              _goToChapter(pos - 1, order);
            }
          },
          child: _chapterBanner(
            pos,
            order.length,
            order[pos],
            _chapterLocked(_progress, order, pos),
          ),
        ),
        const SizedBox(height: 10),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            for (var i = 0; i < order.length; i++)
              GestureDetector(
                key: ValueKey('chapter-dot-$i'),
                behavior: HitTestBehavior.opaque,
                onTap: () => _goToChapter(i, order),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    width: i == pos ? 22 : 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: i == pos ? blue : context.faintBorder,
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 10),
      ],
    );
  }

  Widget _nextChapterButton(List<int> order, int pos) {
    final complete = _chapterComplete(_progress, order[pos]);
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 24),
      child: GestureDetector(
        key: const ValueKey('chapter-jump-next'),
        behavior: HitTestBehavior.opaque,
        onTap: () => _goToChapter(pos + 1, order),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
          decoration: BoxDecoration(
            color: complete ? blue : context.washBg,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: complete ? blueDark : context.washBorder,
              width: 2,
            ),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      complete ? tr('lpt_next_done') : tr('lpt_next'),
                      style: TextStyle(
                        color: complete ? Colors.white : blue,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                        letterSpacing: 1.2,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      tr('lpt_next_chapter', {
                        'n': pos + 2,
                        'realm': chapterRealmIn(
                          AppLocalizations.localeCode,
                          order[pos + 1],
                        ),
                      }),
                      style: TextStyle(
                        color: complete ? Colors.white : context.inkText,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
              ),
              HugeIcon(
                icon: HugeIcons.strokeRoundedArrowRight01,
                color: complete ? Colors.white : blue,
                size: 24,
                strokeWidth: 2.2,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _chapterBanner(
    int pos,
    int total,
    int chapterIdx,
    bool locked, {
    EdgeInsetsGeometry outerPadding = const EdgeInsets.fromLTRB(20, 0, 20, 0),
  }) {
    final chapter = chapters[chapterIdx];
    var all = 0;
    var done = 0;
    for (var s = 0; s < chapter.sections.length; s++) {
      for (var l = 0; l < chapter.sections[s].lessons.length; l++) {
        all++;
        if (!locked &&
            _effectiveStars(
                  _progress,
                  chapterIdx,
                  s,
                  l,
                  chapter.sections[s].lessons[l].stars,
                ) >
                0) {
          done++;
        }
      }
    }
    final progress = all == 0 || locked ? 0.0 : done / all;
    final status = locked
        ? tr('lpt_locked')
        : progress >= 1
        ? tr('lpt_completed')
        : tr('lpt_done_n', {'done': done, 'n': all});
    final sub = locked ? _dim(context.mutedText, 0.6) : context.mutedText;
    return Padding(
      padding: outerPadding,
      child: GestureDetector(
        onTap: () {
          AppFeedback.light();
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => _ChapterListPage(initialChapterIndex: chapterIdx),
            ),
          );
        },
        child: Container(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
          decoration: BoxDecoration(
            color: locked
                ? _dim(chapter.tint.withValues(alpha: 0.12), 0.6)
                : chapter.tint.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: locked ? _dim(context.faintBorder, 0.6) : chapter.tint,
              width: 1.5,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: locked ? _dim(context.faintBg, 0.6) : chapter.tint,
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: locked
                    ? HugeIcon(
                        icon: HugeIcons.strokeRoundedLock,
                        color: sub,
                        size: 22,
                        strokeWidth: 2.0,
                      )
                    : Text(
                        '${pos + 1}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 20,
                        ),
                      ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      tr('lpt_chapter_of', {'i': pos + 1, 'n': total}),
                      style: TextStyle(
                        color: locked ? sub : blue,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                        letterSpacing: 1.4,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      chapterRealmIn(
                        AppLocalizations.localeCode,
                        chapterIdx,
                      ),
                      style: TextStyle(
                        color: locked
                            ? _dim(context.inkText, 0.6)
                            : context.inkText,
                        fontWeight: FontWeight.bold,
                        fontSize: 19,
                      ),
                    ),
                    Text(
                      locked
                          ? tr('lpt_unlock_hint')
                          : '${chapterTaglineIn(AppLocalizations.localeCode, chapterIdx)} • $status',
                      style: TextStyle(color: sub, fontSize: 13),
                    ),
                    if (!locked) const SizedBox(height: 8),
                    if (!locked)
                      Container(
                        height: 8,
                        decoration: BoxDecoration(
                          color: context.faintBg,
                          borderRadius: BorderRadius.circular(999),
                        ),
                        alignment: Alignment.centerLeft,
                        child: FractionallySizedBox(
                          widthFactor: progress.clamp(0.0, 1.0),
                          child: Container(
                            height: 8,
                            decoration: BoxDecoration(
                              color: chapter.tint,
                              borderRadius: BorderRadius.circular(999),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _trackEndCard(List<int> order) {
    var doneChapters = 0;
    for (final c in order) {
      if (_chapterComplete(_progress, c)) doneChapters++;
    }
    final complete = doneChapters >= order.length;
    final upNext = complete
        ? ''
        : chapterRealmIn(AppLocalizations.localeCode, order[doneChapters]);
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 24),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: context.cardBg,
        border: Border.all(color: context.faintBorder, width: 1.5),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: complete ? blue : context.faintBg,
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: HugeIcon(
              icon: complete
                  ? HugeIcons.strokeRoundedCrown
                  : HugeIcons.strokeRoundedLock,
              color: complete ? Colors.white : context.mutedText,
              size: 24,
              strokeWidth: 2.0,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            complete ? tr('lpt_foundation_done') : upNext,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 16,
              color: context.inkText,
            ),
          ),
          Text(
            complete
                ? tr('lpt_foundation_body', {
                    'track': trackName(
                      _memory,
                      AppLocalizations.localeCode,
                    ),
                  })
                : tr('lpt_foundation_keep'),
            textAlign: TextAlign.center,
            style: TextStyle(color: context.mutedText, fontSize: 13),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 10),
            decoration: BoxDecoration(
              color: context.washBg,
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: context.washBorder),
            ),
            child: Text(
              complete
                  ? tr('lpt_foundation_pill_done')
                  : tr('lpt_foundation_pill_next', {
                      'i': doneChapters + 1,
                      'n': order.length,
                    }),
              style: const TextStyle(
                color: blue,
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
          ),
          const SizedBox(height: 14),
          _trackProgramBlock(),
        ],
      ),
    );
  }

  Widget _trackProgramBlock() {
    final track = _memory;
    final total = sessionsToFinishTrack(track);
    final done = sessionsDoneOnTrack(
      reps: _reps,
      progress: _progress,
      track: track,
    );
    final average = trackDepthAverage(
      reps: _reps,
      progress: _progress,
      track: track,
    );
    final tier = tierForAverageDepthIn(AppLocalizations.localeCode, average);
    final minutes = _trackMinutes[track.toString()] ?? 0;
    final courseValue = total <= 0 ? 0.0 : (done / total).clamp(0.0, 1.0);
    final doseValue = (minutes / stretchDoseMinutesPerTrack).clamp(0.0, 1.0);
    final labMark = (labDoseMinutesPerTrack / stretchDoseMinutesPerTrack).clamp(
      0.0,
      1.0,
    );
    return Container(
      key: const ValueKey('track-program-block'),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: context.washBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: context.washBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            tr('lpt_tier_sessions', {
              'tier': tier,
              'done': done,
              'total': total,
            }),
            style: TextStyle(
              color: context.inkText,
              fontWeight: FontWeight.bold,
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: Container(
              height: 8,
              color: context.faintBg,
              alignment: Alignment.centerLeft,
              child: FractionallySizedBox(
                widthFactor: courseValue,
                child: Container(
                  height: 8,
                  decoration: BoxDecoration(
                    color: blue,
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            labDoseProgressLineIn(AppLocalizations.localeCode, minutes),
            style: TextStyle(
              color: context.mutedText,
              fontSize: 12,
              height: 1.45,
            ),
          ),
          const SizedBox(height: 8),
          LayoutBuilder(
            builder: (context, constraints) {
              final width = constraints.maxWidth;
              return SizedBox(
                height: 8,
                child: Stack(
                  children: [
                    Container(
                      height: 8,
                      decoration: BoxDecoration(
                        color: context.faintBg,
                        borderRadius: BorderRadius.circular(999),
                      ),
                    ),
                    FractionallySizedBox(
                      widthFactor: doseValue,
                      child: Container(
                        height: 8,
                        decoration: BoxDecoration(
                          color: teal,
                          borderRadius: BorderRadius.circular(999),
                        ),
                      ),
                    ),
                    Positioned(
                      left: (width * labMark - 1).clamp(0.0, width),
                      top: 0,
                      bottom: 0,
                      child: Container(width: 2, color: context.inkText),
                    ),
                  ],
                ),
              );
            },
          ),
          const SizedBox(height: 8),
          Text(
            trackProgramLineIn(AppLocalizations.localeCode, track),
            style: TextStyle(
              color: context.mutedText,
              fontSize: 11,
              height: 1.45,
            ),
          ),
        ],
      ),
    );
  }
}

class _ChapterListPage extends StatefulWidget {
  final int initialChapterIndex;
  const _ChapterListPage({required this.initialChapterIndex});

  @override
  State<_ChapterListPage> createState() => _ChapterListPageState();
}

class _ChapterListPageState extends State<_ChapterListPage> {
  late Set<int> _expanded;
  Map<String, int> _progress = const {};

  @override
  void initState() {
    super.initState();
    _expanded = {widget.initialChapterIndex};
    _loadProgress();
  }

  Future<void> _loadProgress() async {
    Map<String, int> progress;
    try {
      progress = await MemoryStore.loadChapterProgress();
    } catch (_) {
      return;
    }
    if (!mounted) return;
    setState(() => _progress = progress);
  }

  int _chapterTotal(int i) {
    var total = 0;
    for (final s in chapters[i].sections) {
      total += s.lessons.length;
    }
    return total;
  }

  bool _chapterIsLocked(int i) {
    final loc = trackPositionOfChapter(i);
    return _chapterLocked(_progress, chaptersForTrack(loc.track), loc.pos);
  }

  int _chapterDone(int i) {
    if (_chapterIsLocked(i)) return 0;
    var done = 0;
    for (var s = 0; s < chapters[i].sections.length; s++) {
      final section = chapters[i].sections[s];
      if (_sectionLocked(_progress, i, s)) continue;
      for (var l = 0; l < section.lessons.length; l++) {
        if (_effectiveStars(_progress, i, s, l, section.lessons[l].stars) > 0) {
          done++;
        }
      }
    }
    return done;
  }

  int _partDone(int chapterIdx, int partIdx) {
    if (_chapterIsLocked(chapterIdx)) return 0;
    final section = chapters[chapterIdx].sections[partIdx];
    if (_sectionLocked(_progress, chapterIdx, partIdx)) return 0;
    var done = 0;
    for (var l = 0; l < section.lessons.length; l++) {
      if (_effectiveStars(
            _progress,
            chapterIdx,
            partIdx,
            l,
            section.lessons[l].stars,
          ) >
          0) {
        done++;
      }
    }
    return done;
  }

  @override
  Widget build(BuildContext context) {
    final track = trackPositionOfChapter(widget.initialChapterIndex).track;
    final trackOrder = chaptersForTrack(track);
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
              child: Row(
                children: [
                  EngramBackButton(
                    boxed: true,
                    onPressed: () => Navigator.pop(context),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          tr('lpt_chapters_title'),
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.onSurface,
                            fontWeight: FontWeight.bold,
                            fontSize: 22,
                          ),
                        ),
                        Text(
                          tr('lpt_chapters_sub', {
                            'n': trackOrder.length,
                            'track': trackName(
                              track,
                              AppLocalizations.localeCode,
                            ),
                          }),
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
            const SizedBox(height: 12),
            Expanded(
              child: Builder(
                builder: (context) {
                  final rows = <_ListRow>[];
                  rows.add(_ListRow.track(track));
                  for (final c in trackOrder) {
                    rows.add(_ListRow.chapter(c));
                  }
                  return ListView.builder(
                    padding: const EdgeInsets.fromLTRB(20, 4, 20, 32),
                    itemCount: rows.length,
                    itemBuilder: (context, row) {
                      final entry = rows[row];
                      if (entry.chapter == null) {
                        return _trackHeader(entry.track);
                      }
                      final i = entry.chapter!;
                      final loc = trackPositionOfChapter(i);
                      final order = chaptersForTrack(loc.track);
                      final chapter = chapters[i];
                      final chapLocked = _chapterIsLocked(i);
                      final total = _chapterTotal(i);
                      final done = _chapterDone(i);
                      final progress = total == 0 ? 0.0 : done / total;
                      final status = chapLocked
                          ? tr('lpt_locked')
                          : progress >= 1
                          ? tr('lpt_completed')
                          : tr('lpt_done_n', {'done': done, 'n': total});
                      final isOpen = _expanded.contains(i);
                      return Container(
                        key: ValueKey('chapter-$i'),
                        margin: EdgeInsets.only(
                          bottom: row == rows.length - 1 ? 0 : 10,
                        ),
                        decoration: BoxDecoration(
                          color: context.cardBg,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: context.washBorder),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.05),
                              blurRadius: 8,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Column(
                          children: [
                            GestureDetector(
                              behavior: HitTestBehavior.opaque,
                              onTap: () {
                                setState(() {
                                  if (isOpen) {
                                    _expanded.remove(i);
                                  } else {
                                    _expanded.add(i);
                                  }
                                });
                              },
                              child: Padding(
                                padding: const EdgeInsets.fromLTRB(
                                  14,
                                  12,
                                  14,
                                  12,
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                tr('lpt_chapter_of', {
                                                  'i': loc.pos + 1,
                                                  'n': order.length,
                                                }),
                                                style: const TextStyle(
                                                  color: blue,
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 12,
                                                  letterSpacing: 1.4,
                                                ),
                                              ),
                                              const SizedBox(height: 2),
                                              Text(
                                                chapterRealmIn(
                                                  AppLocalizations.localeCode,
                                                  i,
                                                ),
                                                style: TextStyle(
                                                  color: context.inkText,
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 18,
                                                ),
                                              ),
                                              Text(
                                                chapterTaglineIn(
                                                  AppLocalizations.localeCode,
                                                  i,
                                                ),
                                                style: TextStyle(
                                                  color: context.mutedText,
                                                  fontSize: 13,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        HugeIcon(
                                          icon: isOpen
                                              ? HugeIcons.strokeRoundedArrowUp01
                                              : HugeIcons
                                                    .strokeRoundedArrowDown01,
                                          color: context.mutedText,
                                          size: 24,
                                          strokeWidth: 2.2,
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 10),
                                    Row(
                                      children: [
                                        Expanded(
                                          child: Container(
                                            height: 10,
                                            decoration: BoxDecoration(
                                              color: context.faintBg,
                                              borderRadius:
                                                  BorderRadius.circular(999),
                                            ),
                                            alignment: Alignment.centerLeft,
                                            child: FractionallySizedBox(
                                              widthFactor: progress.clamp(
                                                0.0,
                                                1.0,
                                              ),
                                              child: Container(
                                                height: 10,
                                                decoration: BoxDecoration(
                                                  color: blue,
                                                  borderRadius:
                                                      BorderRadius.circular(
                                                        999,
                                                      ),
                                                ),
                                              ),
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 10),
                                        Text(
                                          status,
                                          style: TextStyle(
                                            color: context.mutedText,
                                            fontSize: 12,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            if (isOpen)
                              Padding(
                                padding: const EdgeInsets.fromLTRB(
                                  14,
                                  0,
                                  14,
                                  14,
                                ),
                                child: Column(
                                  children: [
                                    for (
                                      var p = 0;
                                      p < chapter.sections.length;
                                      p++
                                    )
                                      Builder(
                                        builder: (context) {
                                          final section = chapter.sections[p];
                                          final partTotal =
                                              section.lessons.length;
                                          final partDone = _partDone(i, p);
                                          final partLocked =
                                              chapLocked ||
                                              _sectionLocked(_progress, i, p);
                                          final trailing = partLocked
                                              ? tr('lpt_locked')
                                              : tr('lpt_done_n', {
                                                  'done': partDone,
                                                  'n': partTotal,
                                                });
                                          return GestureDetector(
                                            onTap: partLocked
                                                ? null
                                                : () {
                                                    AppFeedback.light();
                                                    Navigator.of(context)
                                                        .push(
                                                          MaterialPageRoute(
                                                            builder: (_) =>
                                                                _PartDetailPage(
                                                                  chapterIndex:
                                                                      i,
                                                                  partIndex: p,
                                                                  section:
                                                                      section,
                                                                  progress:
                                                                      _progress,
                                                                ),
                                                          ),
                                                        )
                                                        .then(
                                                          (_) =>
                                                              _loadProgress(),
                                                        );
                                                  },
                                            child: Container(
                                              key: ValueKey(
                                                'chapter-$i-part-$p',
                                              ),
                                              margin: EdgeInsets.only(
                                                top: p == 0 ? 2 : 8,
                                              ),
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    horizontal: 12,
                                                    vertical: 10,
                                                  ),
                                              decoration: BoxDecoration(
                                                color: context.washBg,
                                                borderRadius:
                                                    BorderRadius.circular(14),
                                                border: Border.all(
                                                  color: context.faintBorder,
                                                ),
                                              ),
                                              child: Row(
                                                children: [
                                                  Expanded(
                                                    child: Column(
                                                      crossAxisAlignment:
                                                          CrossAxisAlignment
                                                              .start,
                                                      children: [
                                                        Text(
                                                          tr('lpt_part_name', {
                                                            'i': p + 1,
                                                            'name':
                                                                sectionNameIn(
                                                              AppLocalizations
                                                                  .localeCode,
                                                              i,
                                                              p,
                                                            ),
                                                          }),
                                                          style: TextStyle(
                                                            color:
                                                                context.inkText,
                                                            fontWeight:
                                                                FontWeight.w600,
                                                            fontSize: 14,
                                                          ),
                                                        ),
                                                        Text(
                                                          tr('lpt_part_tech', {
                                                            'tech':
                                                                sectionTechniqueIn(
                                                              AppLocalizations
                                                                  .localeCode,
                                                              i,
                                                              p,
                                                            ),
                                                            'n': partTotal,
                                                          }),
                                                          style: TextStyle(
                                                            color: context
                                                                .mutedText,
                                                            fontSize: 12,
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                  ),
                                                  const SizedBox(width: 8),
                                                  Text(
                                                    trailing,
                                                    style: TextStyle(
                                                      color: context.mutedText,
                                                      fontSize: 12,
                                                      fontWeight:
                                                          FontWeight.w600,
                                                    ),
                                                  ),
                                                  const SizedBox(width: 2),
                                                  HugeIcon(
                                                    icon: HugeIcons
                                                        .strokeRoundedArrowRight01,
                                                    color: context.mutedText,
                                                    size: 20,
                                                    strokeWidth: 2,
                                                  ),
                                                ],
                                              ),
                                            ),
                                          );
                                        },
                                      ),
                                  ],
                                ),
                              ),
                          ],
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _trackHeader(int track) {
    final spec = memoryTracks[track];
    final order = chaptersForTrack(track);
    var all = 0;
    var done = 0;
    for (final c in order) {
      all += _chapterTotal(c);
      done += _chapterDone(c);
    }
    final progress = all == 0 ? 0.0 : done / all;
    return Container(
      key: ValueKey('track-$track'),
      margin: const EdgeInsets.only(top: 6, bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: spec.tint.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: spec.tint, width: 1.5),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: spec.tint,
              borderRadius: BorderRadius.circular(12),
            ),
            alignment: Alignment.center,
            child: HugeIcon(
              icon: spec.icon,
              color: Colors.white,
              size: 22,
              strokeWidth: 2.0,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  trackName(track, AppLocalizations.localeCode),
                  style: TextStyle(
                    color: context.inkText,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                Text(
                  '${trackTag(track, AppLocalizations.localeCode)} • ${tr('lpt_done_n', {'done': done, 'n': all})}',
                  style: TextStyle(color: context.mutedText, fontSize: 12),
                ),
                const SizedBox(height: 6),
                Container(
                  height: 8,
                  decoration: BoxDecoration(
                    color: context.faintBg,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  alignment: Alignment.centerLeft,
                  child: FractionallySizedBox(
                    widthFactor: progress.clamp(0.0, 1.0),
                    child: Container(
                      height: 8,
                      decoration: BoxDecoration(
                        color: spec.tint,
                        borderRadius: BorderRadius.circular(999),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Tooltip(
            message: tr('lpt_missions_tip'),
            child: InkWell(
              key: ValueKey('missions-$track'),
              borderRadius: BorderRadius.circular(12),
              onTap: () => showMissionsSheet(context, track),
              child: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: spec.tint.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(12),
                ),
                alignment: Alignment.center,
                child: HugeIcon(
                  icon: HugeIcons.strokeRoundedFlag01,
                  color: spec.tint,
                  size: 20,
                  strokeWidth: 2.0,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ListRow {
  final int track;
  final int? chapter;
  const _ListRow.track(this.track) : chapter = null;
  const _ListRow.chapter(this.chapter) : track = -1;
}

class _PartDetailPage extends StatefulWidget {
  final int chapterIndex;
  final int partIndex;
  final SectionSpec section;
  final Map<String, int> progress;
  const _PartDetailPage({
    required this.chapterIndex,
    required this.partIndex,
    required this.section,
    this.progress = const {},
  });

  @override
  State<_PartDetailPage> createState() => _PartDetailPageState();
}

class _PartDetailPageState extends State<_PartDetailPage> {
  late Map<String, int> _progress;
  Map<String, int> _reps = const {};
  Map<String, DateTime> _doneDates = const {};

  @override
  void initState() {
    super.initState();
    _progress = Map.of(widget.progress);
    _reload();
  }

  Future<void> _reload() async {
    try {
      final loaded = await MemoryStore.loadChapterProgress();
      if (!mounted) return;
      Map<String, int> reps;
      Map<String, DateTime> doneDates;
      try {
        reps = await MemoryStore.loadLessonReps();
      } catch (_) {
        reps = const {};
      }
      try {
        doneDates = await MemoryStore.loadLessonDoneDates();
      } catch (_) {
        doneDates = const {};
      }
      if (!mounted) return;
      setState(() {
        _progress = loaded;
        _reps = reps;
        _doneDates = doneDates;
      });
    } catch (_) {
    }
  }

  int _depthFor(int lessonIdx) {
    final key = MemoryStore.lessonKey(
      widget.chapterIndex,
      widget.partIndex,
      lessonIdx,
    );
    final reps = _reps[key] ?? 0;
    if (reps > 0) return depthForReps(reps);
    return (_progress[key] ?? widget.section.lessons[lessonIdx].stars) > 0
        ? 1
        : 0;
  }

  String _reviewStatus(int lessonIdx) {
    final key = MemoryStore.lessonKey(
      widget.chapterIndex,
      widget.partIndex,
      lessonIdx,
    );
    return reviewStatusLabelIn(
      AppLocalizations.localeCode,
      lastDone: _doneDates[key],
      depth: _depthFor(lessonIdx),
      now: DateTime.now(),
    );
  }

  int _starsFor(int lessonIdx) {
    return _progress[MemoryStore.lessonKey(
          widget.chapterIndex,
          widget.partIndex,
          lessonIdx,
        )] ??
        widget.section.lessons[lessonIdx].stars;
  }

  bool _activeFor(int lessonIdx) {
    var hasAny = false;
    for (var i = 0; i < widget.section.lessons.length; i++) {
      if (_progress.containsKey(
        MemoryStore.lessonKey(widget.chapterIndex, widget.partIndex, i),
      )) {
        hasAny = true;
        break;
      }
    }
    if (!hasAny) return widget.section.lessons[lessonIdx].active;
    for (var i = 0; i < widget.section.lessons.length; i++) {
      if (_starsFor(i) <= 0) return i == lessonIdx;
    }
    return false;
  }

  bool get _chapterLockedHere {
    final loc = trackPositionOfChapter(widget.chapterIndex);
    return _chapterLocked(_progress, chaptersForTrack(loc.track), loc.pos);
  }

  bool _lessonLockedFor(int lessonIdx) {
    if (lessonIdx <= 0) return false;
    for (var i = 0; i < lessonIdx; i++) {
      if (_starsFor(i) <= 0) return true;
    }
    return false;
  }

  Future<void> _openLesson(int lessonIdx) async {
    if (_chapterLockedHere) return;
    if (_sectionLocked(_progress, widget.chapterIndex, widget.partIndex)) {
      return;
    }
    if (_starsFor(lessonIdx) <= 0 && _lessonLockedFor(lessonIdx)) return;
    final key = MemoryStore.lessonKey(
      widget.chapterIndex,
      widget.partIndex,
      lessonIdx,
    );
    final stars = _starsFor(lessonIdx);
    final nextDepth = depthForNextSession(
      reps: _reps[key] ?? 0,
      stars: stars,
    );
    final lastDone = _doneDates[key];
    final now = DateTime.now();
    if (practiceRoundLocked(
      lastDone: lastDone,
      depth: nextDepth,
      stars: stars,
      now: now,
    )) {
      final daysLeft = daysUntilReviewDue(
        lastDone: lastDone,
        depth: nextDepth,
        now: now,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            reviewLockedMessageIn(
              AppLocalizations.localeCode,
              depth: nextDepth,
              daysLeft: daysLeft,
            ),
          ),
        ),
      );
      return;
    }
    AppFeedback.light();
    final done = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => LessonPlayerPage(
          chapterIndex: widget.chapterIndex,
          sectionIndex: widget.partIndex,
          lessonIndex: lessonIdx,
          practiceDepth: nextDepth,
        ),
      ),
    );
    if (done == true && mounted) await _reload();
  }

  @override
  Widget build(BuildContext context) {
    final section = widget.section;
    final locked =
        _chapterLockedHere ||
        _sectionLocked(_progress, widget.chapterIndex, widget.partIndex);
    final total = section.lessons.length;
    var done = 0;
    for (var l = 0; l < section.lessons.length; l++) {
      if (_starsFor(l) > 0) done++;
    }
    final progressValue = total == 0 || locked ? 0.0 : done / total;
    final status = locked
        ? tr('lpt_locked')
        : progressValue >= 1
        ? tr('lpt_completed')
        : tr('lpt_done_n', {'done': done, 'n': total});
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
              child: Row(
                children: [
                  EngramBackButton(
                    boxed: true,
                    onPressed: () => Navigator.pop(context),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          tr('lpt_part_title', {
                            'i': widget.partIndex + 1,
                          }),
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.onSurface,
                            fontWeight: FontWeight.bold,
                            fontSize: 22,
                          ),
                        ),
                        Text(
                          sectionNameIn(
                            AppLocalizations.localeCode,
                            widget.chapterIndex,
                            widget.partIndex,
                          ),
                          style: TextStyle(
                            color: context.mutedText,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: context.washBg,
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(color: context.washBorder),
                    ),
                    child: Text(
                      tr('lpt_lessons_n', {'n': total}),
                      style: const TextStyle(
                        color: blue,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: context.cardBg,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: context.washBorder),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.05),
                      blurRadius: 8,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      sectionTechniqueIn(
                        AppLocalizations.localeCode,
                        widget.chapterIndex,
                        widget.partIndex,
                      ),
                      style: TextStyle(
                        color: context.inkText,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      tr('lpt_lessons_done', {'n': total, 'd': done}),
                      style: TextStyle(
                        color: context.mutedText,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: Container(
                            height: 10,
                            decoration: BoxDecoration(
                              color: context.faintBg,
                              borderRadius: BorderRadius.circular(999),
                            ),
                            alignment: Alignment.centerLeft,
                            child: FractionallySizedBox(
                              widthFactor: progressValue.clamp(0.0, 1.0),
                              child: Container(
                                height: 10,
                                decoration: BoxDecoration(
                                  color: blue,
                                  borderRadius: BorderRadius.circular(999),
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Text(
                          status,
                          style: TextStyle(
                            color: context.mutedText,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 32),
                itemCount: total,
                itemBuilder: (context, i) {
                  final stars = _starsFor(i);
                  final active = _activeFor(i);
                  final depth = _depthFor(i);
                  final lessonLocked =
                      !locked && stars <= 0 && _lessonLockedFor(i);
                  final trailing = locked || lessonLocked
                      ? tr('lpt_locked')
                      : stars > 0
                      ? '$stars/3'
                      : active
                      ? tr('lpt_up_now')
                      : tr('lpt_todo');
                  return GestureDetector(
                    onTap: locked || lessonLocked ? null : () => _openLesson(i),
                    child: Container(
                      key: ValueKey('part-lesson-${i + 1}'),
                      margin: EdgeInsets.only(bottom: i == total - 1 ? 0 : 8),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 12,
                      ),
                      decoration: BoxDecoration(
                        color: context.cardBg,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: context.faintBorder),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 36,
                            height: 36,
                            decoration: BoxDecoration(
                              color: locked || lessonLocked
                                  ? context.faintBg
                                  : context.washBg,
                              shape: BoxShape.circle,
                            ),
                            alignment: Alignment.center,
                            child: Text(
                              '${i + 1}',
                              style: TextStyle(
                                color: locked || lessonLocked
                                    ? context.mutedText
                                    : blue,
                                fontWeight: FontWeight.bold,
                                fontSize: 15,
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  tr('lpt_step_of', {
                                    'i': i + 1,
                                    'n': total,
                                  }),
                                  style: TextStyle(
                                    color: context.mutedText,
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: 0.8,
                                  ),
                                ),
                                Text(
                                  lessonTitleIn(
                                    AppLocalizations.localeCode,
                                    widget.chapterIndex,
                                    widget.partIndex,
                                    i,
                                  ),
                                  style: TextStyle(
                                    color: context.inkText,
                                    fontWeight: FontWeight.w600,
                                    fontSize: 15,
                                  ),
                                ),
                                Text(
                                  lessonDetailIn(
                                    AppLocalizations.localeCode,
                                    widget.chapterIndex,
                                    widget.partIndex,
                                    i,
                                  ),
                                  style: TextStyle(
                                    color: context.mutedText,
                                    fontSize: 12,
                                  ),
                                ),
                                if (depth > 0 && !locked && !lessonLocked)
                                  Text(
                                    tr('lpt_depth_line', {
                                      'd': depth,
                                      'total': practiceDepths,
                                      'status': _reviewStatus(i),
                                    }),
                                    style: TextStyle(
                                      color: blue,
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            trailing,
                            style: TextStyle(
                              color: context.mutedText,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TrackPickerPage extends StatelessWidget {
  final int selected;
  const _TrackPickerPage({required this.selected});

  Widget _squareIcon({
    required double size,
    required Color top,
    required Color edge,
    required Widget child,
  }) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: top,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: edge, width: 2),
      ),
      alignment: Alignment.center,
      child: child,
    );
  }

  Widget _retakeCard(BuildContext context) {
    return GestureDetector(
      key: const ValueKey('track-retake-assessment'),
      onTap: () {
        AppFeedback.light();
        Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const MemoryAssessmentIntroPage()),
        );
      },
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: context.washBg,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: blue, width: 2),
        ),
        child: Row(
          children: [
            _squareIcon(
              size: 52,
              top: context.cardBg,
              edge: blue,
              child: const HugeIcon(
                icon: HugeIcons.strokeRoundedRefresh,
                color: blue,
                size: 26,
                strokeWidth: 2.0,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    tr('lpt_retake'),
                    style: TextStyle(
                      color: context.inkText,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  Text(
                    tr('lpt_retake_sub'),
                    style: TextStyle(color: context.mutedText, fontSize: 13),
                  ),
                ],
              ),
            ),
            const HugeIcon(
              icon: HugeIcons.strokeRoundedArrowRight01,
              color: blue,
              size: 22,
              strokeWidth: 2.2,
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
              child: Row(
                children: [
                  EngramBackButton(
                    boxed: true,
                    onPressed: () => Navigator.pop(context),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          tr('lpt_track_title'),
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.onSurface,
                            fontWeight: FontWeight.bold,
                            fontSize: 22,
                            height: 1.2,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          tr('lpt_six_tracks'),
                          style: TextStyle(
                            color: context.mutedText,
                            fontSize: 13,
                            height: 1.4,
                          ),
                        ),
                        Text(
                          tr('lpt_foundation_review'),
                          style: TextStyle(
                            color: context.mutedText,
                            fontSize: 13,
                            height: 1.4,
                          ),
                        ),
                        const SizedBox(height: 8),
                        GestureDetector(
                          onTap: () => showHonestySheet(context),
                          child: Text(
                            tr('lpt_honesty'),
                            style: TextStyle(
                              color: blue,
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                              height: 1.4,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 32),
                itemCount: _tracks.length + 2,
                itemBuilder: (context, i) {
                  if (i == 0) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: _retakeCard(context),
                    );
                  }
                  final trackIndex = i - 1;
                  if (trackIndex >= _tracks.length) {
                    return Padding(
                      padding: const EdgeInsets.fromLTRB(4, 12, 4, 8),
                      child: Text(
                        foundationDoseText,
                        style: TextStyle(
                          color: context.mutedText,
                          fontSize: 12,
                          height: 1.5,
                        ),
                      ),
                    );
                  }
                  final track = _tracks[trackIndex];
                  final isSel = trackIndex == selected;
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: GestureDetector(
                      onTap: () {
                        Navigator.pop(context, trackIndex);
                      },
                      child: Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: isSel ? context.washBg : context.cardBg,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: isSel ? blue : context.faintBorder,
                            width: isSel ? 2 : 1.5,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.05),
                              blurRadius: 8,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Row(
                          children: [
                            _squareIcon(
                              size: 52,
                              top: isSel ? context.cardBg : context.faintBg,
                              edge: isSel ? blue : context.faintBorder,
                              child: HugeIcon(
                                icon: track.icon,
                                color: track.tint,
                                size: 26,
                                strokeWidth: 2.0,
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    trackName(
                                      trackIndex,
                                      AppLocalizations.localeCode,
                                    ),
                                    style: TextStyle(
                                      color: context.inkText,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                    ),
                                  ),
                                  Text(
                                    trackTag(
                                      trackIndex,
                                      AppLocalizations.localeCode,
                                    ),
                                    style: TextStyle(
                                      color: context.mutedText,
                                      fontSize: 13,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Container(
                              width: 24,
                              height: 24,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: isSel ? blue : Colors.transparent,
                                border: Border.all(
                                  color: isSel ? blue : context.faintBorder,
                                  width: 2,
                                ),
                              ),
                              child: isSel
                                  ? const HugeIcon(
                                      icon: HugeIcons.strokeRoundedTick02,
                                      color: Colors.white,
                                      size: 14,
                                      strokeWidth: 2.2,
                                    )
                                  : null,
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RiverPainter extends CustomPainter {
  final double fromX;
  final double toX;
  final Color color;

  const _RiverPainter({
    required this.fromX,
    required this.toX,
    required this.color,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final h = size.height;
    canvas.save();
    canvas.clipRect(Offset.zero & size);
    final path = Path()
      ..moveTo(fromX, 0)
      ..cubicTo(fromX, h * 0.45, toX, h * 0.55, toX, h);

    final glow = Paint()
      ..color = color.withValues(alpha: 0.35)
      ..strokeWidth = 18
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    canvas.drawPath(path, glow);

    final core = Paint()
      ..color = color
      ..strokeWidth = 10
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    canvas.drawPath(path, core);

    final shine = Paint()
      ..color = Colors.white.withValues(alpha: 0.45)
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    canvas.drawPath(path, shine);

    Offset cubic(double t) {
      final a = Offset(fromX, 0);
      final b = Offset(fromX, h * 0.45);
      final c = Offset(toX, h * 0.55);
      final d = Offset(toX, h);
      final mt = 1 - t;
      return Offset(
        mt * mt * mt * a.dx +
            3 * mt * mt * t * b.dx +
            3 * mt * t * t * c.dx +
            t * t * t * d.dx,
        mt * mt * mt * a.dy +
            3 * mt * mt * t * b.dy +
            3 * mt * t * t * c.dy +
            t * t * t * d.dy,
      );
    }

    for (final t in [0.32, 0.68]) {
      final p = cubic(t);
      canvas.drawCircle(p, 9, Paint()..color = Colors.white);
      canvas.drawCircle(p, 6.5, Paint()..color = color);
      canvas.drawCircle(p, 2.4, Paint()..color = Colors.white);
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(_RiverPainter old) =>
      old.fromX != fromX || old.toX != toX || old.color != color;
}
