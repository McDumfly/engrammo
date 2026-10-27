import '../theme/app_theme.dart';

import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';

import '../widgets/app_buttons.dart';
import '../services/app_feedback.dart';
import '../theme/app_colors.dart'
    show violet, violetDark, teal, amber, coral, sky, trail;
import 'battle_zone.dart' show BattleZoneView;
import 'benchmark.dart' show BenchmarkHubPage;
import 'brain_league.dart' show BrainLeaguePage;
import '../models/curriculum.dart' show SectionSpec, chapters;
import 'kreeds_profile.dart' show KreedsProfilePage;
import '../services/memory_store.dart';
import '../utils/streak_restore.dart';
import '../widgets/stats_top_bar.dart';
import '../widgets/streak_restore_dialog.dart';

import '../widgets/synapse_navbar.dart';

/// Saját tanulási folyam képernyő: fehér alapon világoskék folyó,
/// állomásokkal. Nincs 3D-gomb, nincs csillagsor, nincs kabala.
class LearningPathPage extends StatefulWidget {
  const LearningPathPage({super.key});

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
    'Audio flash and attention focus',
    HugeIcons.strokeRoundedAudioWave01,
    sky,
  ),
  _Track(
    'Working memory',
    'Chunking forge',
    HugeIcons.strokeRoundedLayers01,
    violet,
  ),
  _Track('Spatial', 'Palace builder', HugeIcons.strokeRoundedCastle01, teal),
  _Track('Visual', 'Imagery lab', HugeIcons.strokeRoundedEye, amber),
  _Track(
    'Episodic',
    'Journal and loci walk',
    HugeIcons.strokeRoundedNotebook01,
    coral,
  ),
  _Track(
    'Semantic',
    'Names, faces and vocabulary',
    HugeIcons.strokeRoundedBrain01,
    violetDark,
  ),
];

class _LearningPathPageState extends State<LearningPathPage> {
  static const _navTabs = [
    SynapseTab(HugeIcons.strokeRoundedHome01, 'Home'),
    SynapseTab(HugeIcons.strokeRoundedTrophy, 'League'),
    SynapseTab(HugeIcons.strokeRoundedSwords, 'Arena'),
    SynapseTab(HugeIcons.strokeRoundedDumbbell01, 'Practice'),
    SynapseTab(HugeIcons.strokeRoundedUser02, 'Profile'),
  ];

  Widget _tabBody() {
    // A navbar lebeg a tartalom folott (Stack + Positioned az
    // extendBody miatt), ezert nincs kulso also hely: minden
    // beagyazott lap a sajat gorgetheto tartalman belul hagy
    // elegendo also helyet, igy semmilyen fulon nincs feher sav.
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
  int _memory = 2;
  int _streak = 0;
  int _engrams = 0;
  List<DateTime> _streakHistory = const [];
  bool _showBackToNow = false;
  final ScrollController _scroll = ScrollController();
  final GlobalKey _nowKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_onScroll);
    _loadStreak();
  }

  Future<void> _loadStreak() async {
    StreakState state;
    try {
      state = await MemoryStore.loadStreakState();
    } catch (_) {
      // Teszt-környezetben (plugin nélküli widget-teszt) nincs
      // tároló: maradnak az alapértelmezett kijelzett értékek.
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

  /// Törött széria -> napi egyszeri emlékeztető az első megnyitáskor.
  /// Csak akkor ugrik fel, ha van visszaállítható szakadás, és ma
  /// még nem látta a user (az elvetés is számít, holnap újra jön).
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
                // A profil fül saját fejléccel megy, a többi fül
                // tetején ez a közös sáv ül.
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
                      ),
                    ),
                  ),
                Expanded(child: _tabBody()),
              ],
            ),
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
                  color: violet,
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

  Widget _flowView() {
    final chapter = chapters[_memory];
    final next = chapters[(_memory + 1) % chapters.length];
    const offsets = [0.0, -64.0, 64.0, 0.0];
    final body = <Widget>[];
    var station = 0;

    for (var s = 0; s < chapter.sections.length; s++) {
      final section = chapter.sections[s];
      body.add(const SizedBox(height: 20));
      body.add(_sectionHeader(s, section));
      var prev = 0.0;
      var linked = false;
      for (var l = 0; l < section.lessons.length; l++) {
        final lesson = section.lessons[l];
        final offset = offsets[l % offsets.length];
        if (linked) {
          body.add(_riverLink(prev, offset, locked: section.locked));
        }
        prev = offset;
        linked = true;
        if (section.locked) {
          body.add(_stationLocked(offset: offset, title: lesson.title));
          continue;
        }
        if (lesson.stars > 0) {
          body.add(_stationDone(offset: offset, title: lesson.title));
          continue;
        }
        if (lesson.active) {
          station++;
          body.add(
            Container(
              key: _nowKey,
              child: _stationNow(
                offset: offset,
                number: station,
                lessonIcon: lesson.icon,
              ),
            ),
          );
          body.add(const SizedBox(height: 12));
          body.add(
            _nowCard(
              title: lesson.title,
              detail: lesson.detail,
              station: station,
            ),
          );
          body.add(const SizedBox(height: 4));
          continue;
        }
        station++;
        body.add(
          _stationTodo(offset: offset, number: station, title: lesson.title),
        );
      }
      if (s == 0 && !section.locked) {
        body.add(_riverLink(prev, 0, locked: false));
        body.add(_bonusStop(realm: chapter.realm));
        body.add(const SizedBox(height: 4));
      } else if (section.locked) {
        body.add(const SizedBox(height: 10));
        body.add(_lockedNote());
      } else {
        body.add(const SizedBox(height: 8));
      }
    }
    body.add(const SizedBox(height: 24));
    body.add(_nextRealmCard(nextRealm: next.realm));
    body.add(const SizedBox(height: 130));

    return SafeArea(
      top: false,
      child: SingleChildScrollView(
        controller: _scroll,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: body,
        ),
      ),
    );
  }

  Future<void> _openTrackPicker() async {
    AppFeedback.light();
    final picked = await Navigator.of(context).push<int>(
      MaterialPageRoute(builder: (_) => _TrackPickerPage(selected: _memory)),
    );
    if (picked != null && picked != _memory) {
      setState(() => _memory = picked);
    }
  }

  Widget _sectionHeader(int index, SectionSpec section) {
    final bool locked = section.locked;
    final Color accent = locked ? context.faintBorder : violet;
    final String name = section.name;
    final String technique = section.technique;
    final List<List<dynamic>> icon = section.icon;
    final int total = section.lessons.length;
    final int done = section.lessons.where((l) => l.stars > 0).length;
    final double progress = total == 0 || locked ? 0 : done / total;
    final String status = locked
        ? 'Locked'
        : progress >= 1
        ? 'Completed'
        : '$done/$total done';
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 14),
      // Blur és áttetszőség nélkül: a BackdropFilter görgetés közben
      // Androidon külön offscreen-réteget kényszerít ki minden kártyára.
      // Tömör kártyaszínnel vizuálisan gyakorlatilag azonos.
      child: _Dimmed(
        dimmed: locked,
        child: GestureDetector(
              onTap: () {
                AppFeedback.light();
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) =>
                        _ChapterListPage(initialChapterIndex: _memory),
                  ),
                );
              },
              child: Container(
                padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                decoration: BoxDecoration(
                  color: context.cardBg,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: locked ? context.faintBorder : context.washBorder,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.05),
                      blurRadius: 16,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Container(
                          width: 5,
                          height: 52,
                          decoration: BoxDecoration(
                            color: accent,
                            borderRadius: BorderRadius.circular(999),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Part ${index + 1}',
                                style: TextStyle(
                                  color: locked ? context.mutedText : violet,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                  letterSpacing: 1.4,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                name,
                                style: TextStyle(
                                  color: context.inkText,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 19,
                                ),
                              ),
                              Text(
                                '$technique • $total lessons',
                                style: TextStyle(
                                  color: context.mutedText,
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          width: 46,
                          height: 46,
                          decoration: BoxDecoration(
                            color: locked ? context.faintBg : context.washBg,
                            shape: BoxShape.circle,
                          ),
                          alignment: Alignment.center,
                          child: HugeIcon(
                            icon: locked ? HugeIcons.strokeRoundedLock : icon,
                            color: locked ? context.mutedText : violet,
                            size: 23,
                            strokeWidth: 2.0,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Icon(
                          Icons.chevron_right,
                          color: context.mutedText,
                          size: 24,
                        ),
                      ],
                    ),
                    if (!locked) const SizedBox(height: 10),
                    if (!locked)
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
                                widthFactor: progress.clamp(0.0, 1.0),
                                child: Container(
                                  height: 10,
                                  decoration: BoxDecoration(
                                    color: violet,
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
                    if (locked) const SizedBox(height: 8),
                    if (locked)
                      Row(
                        children: [
                          HugeIcon(
                            icon: HugeIcons.strokeRoundedLock,
                            color: context.mutedText,
                            size: 14,
                            strokeWidth: 2.2,
                          ),
                          SizedBox(width: 4),
                          Text(
                            'Locked',
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

  Widget _stationShell({
    required double offset,
    required String title,
    required Widget badge,
    bool faintTitle = false,
  }) {
    // A felirat mindig a trail fölött: a badge + label egyben mozog,
    // a label tömör fehér háttérrel, így a folyó alatta marad.
    final content = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        badge,
        const SizedBox(height: 8),
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 200),
          child: Material(
            color: context.cardBg,
            borderRadius: BorderRadius.circular(999),
            elevation: 0,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
              decoration: BoxDecoration(
                color: context.cardBg,
                borderRadius: BorderRadius.circular(999),
                border: Border.all(
                  color: faintTitle ? context.faintBorder : context.washBorder,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 10,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Text(
                title,
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: faintTitle ? context.mutedText : context.inkText,
                  fontWeight: FontWeight.w600,
                  fontSize: 12.5,
                ),
              ),
            ),
          ),
        ),
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

  Widget _stationDone({required double offset, required String title}) {
    return _stationShell(
      offset: offset,
      title: title,
      faintTitle: true,
      badge: _block3d(
        size: 62,
        top: context.washBg,
        edge: violet,
        border: violet,
        child: const HugeIcon(
          icon: HugeIcons.strokeRoundedCheckmarkCircle02,
          color: violet,
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
            color: violet,
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
    required List<List<dynamic>> lessonIcon,
  }) {
    final badge = _block3d(
      size: 76,
      depth: 8,
      radius: 22,
      top: violet,
      edge: violetDark,
      border: violetDark,
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
            color: violet,
            borderRadius: BorderRadius.circular(999),
          ),
          child: Text(
            'Station $number • up now',
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 12,
            ),
          ),
        ),
      ],
    );
  }

  Widget _stationLocked({required double offset, required String title}) {
    return Opacity(
      opacity: 0.7,
      child: _stationShell(
        offset: offset,
        title: title,
        faintTitle: true,
        badge: _block3d(
          size: 62,
          top: context.faintBg,
          edge: context.faintBorder,
          border: context.faintBorder,
          child: HugeIcon(
            icon: HugeIcons.strokeRoundedLock,
            color: context.mutedText,
            size: 24,
            strokeWidth: 2.0,
          ),
        ),
      ),
    );
  }

  Widget _nowCard({
    required String title,
    required String detail,
    required int station,
  }) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 24),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.washBg,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: context.washBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'UP NEXT',
            style: TextStyle(
              color: violet,
              fontWeight: FontWeight.bold,
              fontSize: 11,
              letterSpacing: 1.6,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            title,
            style: TextStyle(
              color: context.inkText,
              fontWeight: FontWeight.bold,
              fontSize: 17,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            '$detail • about 5 min',
            style: TextStyle(color: context.mutedText, fontSize: 13),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(vertical: 14),
            decoration: BoxDecoration(
              color: violet,
              borderRadius: BorderRadius.circular(999),
            ),
            alignment: Alignment.center,
            child: const Text(
              'Continue',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
          ),
        ],
      ),
    );
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
              color: violet,
              size: 24,
              strokeWidth: 2.0,
            ),
            SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Rest bonus',
                    style: TextStyle(
                      color: context.inkText,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                  Text(
                    '+20–40 engrams',
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
          'Locked — finish the part above first',
          style: TextStyle(color: sub, fontSize: 13),
        ),
      ],
    );
  }

  Widget _nextRealmCard({required String nextRealm}) {
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
              color: context.faintBg,
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: HugeIcon(
              icon: HugeIcons.strokeRoundedLock,
              color: context.mutedText,
              size: 24,
              strokeWidth: 2.0,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            nextRealm,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 16,
              color: context.inkText,
            ),
          ),
          Text(
            'Finish this chapter to keep flowing',
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
            child: const Text(
              'Placement test',
              style: TextStyle(
                color: violet,
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Fejezetlista képernyő (Duolingo-minta): a fejezetek egymás alatt,
/// mindegyiken progressbarral, hogy mennyire van kész. A fejezetek
/// lenyithatók, bennük a partokkal; a partokon látszik, hány feladat
/// van. A jelenlegi fejezet megnyitáskor automatikusan lenyitva.
class _ChapterListPage extends StatefulWidget {
  final int initialChapterIndex;
  const _ChapterListPage({required this.initialChapterIndex});

  @override
  State<_ChapterListPage> createState() => _ChapterListPageState();
}

class _ChapterListPageState extends State<_ChapterListPage> {
  late Set<int> _expanded;

  @override
  void initState() {
    super.initState();
    _expanded = {widget.initialChapterIndex};
  }

  int _chapterTotal(int i) {
    var total = 0;
    for (final s in chapters[i].sections) {
      total += s.lessons.length;
    }
    return total;
  }

  int _chapterDone(int i) {
    var done = 0;
    for (final s in chapters[i].sections) {
      if (s.locked) continue;
      done += s.lessons.where((l) => l.stars > 0).length;
    }
    return done;
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
                          'Chapters',
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.onSurface,
                            fontWeight: FontWeight.bold,
                            fontSize: 22,
                          ),
                        ),
                        Text(
                          '${chapters.length} chapters',
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
              child: ListView.builder(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 32),
                itemCount: chapters.length,
                itemBuilder: (context, i) {
                  final chapter = chapters[i];
                  final total = _chapterTotal(i);
                  final done = _chapterDone(i);
                  final progress = total == 0 ? 0.0 : done / total;
                  final status = progress >= 1
                      ? 'Completed'
                      : '$done/$total done';
                  final isOpen = _expanded.contains(i);
                  return Container(
                    key: ValueKey('chapter-$i'),
                    margin: EdgeInsets.only(
                      bottom: i == chapters.length - 1 ? 0 : 10,
                    ),
                    decoration: BoxDecoration(
                      color: context.cardBg,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: context.washBorder),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.05),
                          blurRadius: 16,
                          offset: const Offset(0, 6),
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
                            padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
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
                                            'Chapter ${i + 1}',
                                            style: const TextStyle(
                                              color: violet,
                                              fontWeight: FontWeight.bold,
                                              fontSize: 12,
                                              letterSpacing: 1.4,
                                            ),
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            chapter.realm,
                                            style: TextStyle(
                                              color: context.inkText,
                                              fontWeight: FontWeight.bold,
                                              fontSize: 18,
                                            ),
                                          ),
                                          Text(
                                            chapter.tagline,
                                            style: TextStyle(
                                              color: context.mutedText,
                                              fontSize: 13,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Icon(
                                      isOpen
                                          ? Icons.expand_less
                                          : Icons.expand_more,
                                      color: context.mutedText,
                                      size: 24,
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
                                          borderRadius: BorderRadius.circular(
                                            999,
                                          ),
                                        ),
                                        alignment: Alignment.centerLeft,
                                        child: FractionallySizedBox(
                                          widthFactor: progress.clamp(0.0, 1.0),
                                          child: Container(
                                            height: 10,
                                            decoration: BoxDecoration(
                                              color: violet,
                                              borderRadius:
                                                  BorderRadius.circular(999),
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
                            padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
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
                                      final partTotal = section.lessons.length;
                                      final partDone = section.lessons
                                          .where((l) => l.stars > 0)
                                          .length;
                                      final trailing = section.locked
                                          ? 'Locked'
                                          : '$partDone/$partTotal done';
                                      return GestureDetector(
                                        onTap: () {
                                          AppFeedback.light();
                                          Navigator.of(context).push(
                                            MaterialPageRoute(
                                              builder: (_) => _PartDetailPage(
                                                partIndex: p,
                                                section: section,
                                              ),
                                            ),
                                          );
                                        },
                                        child: Container(
                                          key: ValueKey('chapter-$i-part-$p'),
                                          margin: EdgeInsets.only(
                                            top: p == 0 ? 2 : 8,
                                          ),
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 12,
                                            vertical: 10,
                                          ),
                                          decoration: BoxDecoration(
                                            color: context.washBg,
                                            borderRadius: BorderRadius.circular(
                                              14,
                                            ),
                                            border: Border.all(
                                              color: context.faintBorder,
                                            ),
                                          ),
                                          child: Row(
                                            children: [
                                              Expanded(
                                                child: Column(
                                                  crossAxisAlignment:
                                                      CrossAxisAlignment.start,
                                                  children: [
                                                    Text(
                                                      'Part ${p + 1} • ${section.name}',
                                                      style: TextStyle(
                                                        color: context.inkText,
                                                        fontWeight:
                                                            FontWeight.w600,
                                                        fontSize: 14,
                                                      ),
                                                    ),
                                                    Text(
                                                      '${section.technique} • $partTotal tasks',
                                                      style: TextStyle(
                                                        color:
                                                            context.mutedText,
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
                                                  fontWeight: FontWeight.w600,
                                                ),
                                              ),
                                              const SizedBox(width: 2),
                                              Icon(
                                                Icons.chevron_right,
                                                color: context.mutedText,
                                                size: 20,
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
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Egy Part leckéit soroló képernyő: Duolingo-szerűen egymás
/// alatt sorolja a leckéket, felül a darabszámmal és haladással.
/// A sorok sorszáma egyre nő (1-től N-ig), a státusz egyre nehezedik:
///
/// kész (csillagos) -> aktív (Up now) -> várakozó (Todo) -> zárolt.
/// A fejezetlistából nyílik, egy partra koppintva.
class _PartDetailPage extends StatelessWidget {
  final int partIndex;
  final SectionSpec section;
  const _PartDetailPage({required this.partIndex, required this.section});

  @override
  Widget build(BuildContext context) {
    final total = section.lessons.length;
    final done = section.lessons.where((l) => l.stars > 0).length;
    final progress = total == 0 || section.locked ? 0.0 : done / total;
    final status = section.locked
        ? 'Locked'
        : progress >= 1
        ? 'Completed'
        : '$done/$total done';
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
                          'Part ${partIndex + 1}',
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.onSurface,
                            fontWeight: FontWeight.bold,
                            fontSize: 22,
                          ),
                        ),
                        Text(
                          section.name,
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
                      '$total lessons',
                      style: const TextStyle(
                        color: violet,
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
                      blurRadius: 16,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      section.technique,
                      style: TextStyle(
                        color: context.inkText,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '$total lessons • $done done',
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
                              widthFactor: progress.clamp(0.0, 1.0),
                              child: Container(
                                height: 10,
                                decoration: BoxDecoration(
                                  color: violet,
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
                  final lesson = section.lessons[i];
                  final trailing = section.locked
                      ? 'Locked'
                      : lesson.stars > 0
                      ? '${lesson.stars}/3'
                      : lesson.active
                      ? 'Up now'
                      : 'Todo';
                  return Container(
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
                            color: section.locked
                                ? context.faintBg
                                : context.washBg,
                            shape: BoxShape.circle,
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            '${i + 1}',
                            style: TextStyle(
                              color: section.locked
                                  ? context.mutedText
                                  : violet,
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
                                'Step ${i + 1} of $total',
                                style: TextStyle(
                                  color: context.mutedText,
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 0.8,
                                ),
                              ),
                              Text(
                                lesson.title,
                                style: TextStyle(
                                  color: context.inkText,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 15,
                                ),
                              ),
                              Text(
                                lesson.detail,
                                style: TextStyle(
                                  color: context.mutedText,
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
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
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

/// Teljes képernyős, az app stílusához illő memóriatípus-választó.
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
                          'Learning track',
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.onSurface,
                            fontWeight: FontWeight.bold,
                            fontSize: 22,
                          ),
                        ),
                        Text(
                          'Six tracks, one for each memory type.',
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
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 32),
                itemCount: _tracks.length,
                itemBuilder: (context, i) {
                  final track = _tracks[i];
                  final isSel = i == selected;
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: GestureDetector(
                      onTap: () {
                        Navigator.pop(context, i);
                      },
                      child: Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: isSel ? context.washBg : context.cardBg,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: isSel ? violet : context.faintBorder,
                            width: isSel ? 2 : 1.5,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.05),
                              blurRadius: 16,
                              offset: const Offset(0, 6),
                            ),
                          ],
                        ),
                        child: Row(
                          children: [
                            _squareIcon(
                              size: 52,
                              top: isSel ? context.cardBg : context.faintBg,
                              edge: isSel ? violet : context.faintBorder,
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
                                    track.name,
                                    style: TextStyle(
                                      color: context.inkText,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                    ),
                                  ),
                                  Text(
                                    track.module,
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
                                color: isSel ? violet : Colors.transparent,
                                border: Border.all(
                                  color: isSel ? violet : context.faintBorder,
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

/// Csak zárolt állapotban tesz rá áttetszőséget; máskor a gyereket
/// réteg nélkül adja vissza, így görgetéskor nincs felesleges
/// Opacity-réteg az Androidos raster-szál útjában.
class _Dimmed extends StatelessWidget {
  final bool dimmed;
  final Widget child;
  const _Dimmed({required this.dimmed, required this.child});

  @override
  Widget build(BuildContext context) {
    if (!dimmed) return child;
    return Opacity(opacity: 0.6, child: child);
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
    // Szigorúan a saját sávon belül marad, nem lóg rá a feliratokra.
    final path = Path()
      ..moveTo(fromX, 0)
      ..cubicTo(fromX, h * 0.45, toX, h * 0.55, toX, h);

    // Külső derengés: ettől "idegrost" a csík, nem sima vonal.
    final glow = Paint()
      ..color = color.withValues(alpha: 0.35)
      ..strokeWidth = 18
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    canvas.drawPath(path, glow);

    // Fő összekötött szál: végig folytonos, átfed az állomások alá.
    final core = Paint()
      ..color = color
      ..strokeWidth = 10
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    canvas.drawPath(path, core);

    // Belső fénycsík a plasztikusságért.
    final shine = Paint()
      ..color = Colors.white.withValues(alpha: 0.45)
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    canvas.drawPath(path, shine);

    // Szinapszis-gombok a szál mentén: ettől lesz "brain" érzet.
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
  }

  @override
  bool shouldRepaint(_RiverPainter old) =>
      old.fromX != fromX || old.toX != toX || old.color != color;
}
