import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../services/app_feedback.dart';

import 'package:hugeicons/hugeicons.dart';

import '../l10n/app_localizations.dart';
import '../models/battle_match.dart' show battleDateLabelIn;
import '../services/bot_arena_store.dart';
import '../widgets/ai_help_button.dart';
import 'friend_profile.dart';

import 'memory_profile.dart' show violet, violetDark, teal, amber, coral, sky;

class BrainTier {
  final String name;
  final String tagline;
  final Color color;
  final List<List<dynamic>> icon;
  final int particles;
  const BrainTier(
    this.name,
    this.tagline,
    this.color,
    this.icon,
    this.particles,
  );
}

const brainTiers = [
  BrainTier(
    'Awakening Mind I',
    'The first spark',
    Color(0xFF8EC5FF),
    HugeIcons.strokeRoundedBrain01,
    0,
  ),
  BrainTier(
    'Awakening Mind II',
    'Waking attention',
    Color(0xFF57A7FF),
    HugeIcons.strokeRoundedBrain01,
    4,
  ),
  BrainTier(
    'Awakening Mind III',
    'Knowledge starts to stick',
    Color(0xFF2E9DFF),
    HugeIcons.strokeRoundedBrain01,
    6,
  ),
  BrainTier(
    'Growing Mind I',
    'The foundation you build on',
    Color(0xFF2E9DFF),
    HugeIcons.strokeRoundedBrain02,
    8,
  ),
  BrainTier(
    'Growing Mind II',
    'Strengthening connections',
    Color(0xFF1B7FE0),
    HugeIcons.strokeRoundedBrain02,
    10,
  ),
  BrainTier(
    'Growing Mind III',
    'Stable, reliable memory',
    Color(0xFF155CB8),
    HugeIcons.strokeRoundedBrain02,
    12,
  ),
  BrainTier(
    'Sage I',
    'Thoughtful and attentive',
    Color(0xFF7C5CFF),
    HugeIcons.strokeRoundedBrain03,
    14,
  ),
  BrainTier(
    'Sage II',
    'Deep, experienced mind',
    Color(0xFF9B5CF6),
    HugeIcons.strokeRoundedBrain03,
    16,
  ),
  BrainTier(
    'Sage III',
    'Masterful practice',
    Color(0xFFB14BFF),
    HugeIcons.strokeRoundedBrain03,
    18,
  ),
  BrainTier(
    'Genius I',
    'Sparkling insights',
    Color(0xFF7C3AED),
    HugeIcons.strokeRoundedBrainCircuit,
    20,
  ),
  BrainTier(
    'Genius II',
    'Master of combos',
    Color(0xFF6D28D9),
    HugeIcons.strokeRoundedBrainCircuit,
    22,
  ),
  BrainTier(
    'Genius III',
    'Unmatched league form',
    Color(0xFF4C1D95),
    HugeIcons.strokeRoundedBrainCircuit,
    24,
  ),
  BrainTier(
    'Quantum Mind',
    'Engram-fast, relentless practice',
    Color(0xFF2E4BFF),
    HugeIcons.strokeRoundedAtom01,
    26,
  ),
  BrainTier(
    'Infinite Mind',
    'Galaxy-scale, boundless knowledge',
    Color(0xFFFFC400),
    HugeIcons.strokeRoundedGalaxy,
    30,
  ),
];

String brainTierName(int index, [String locale = 'en']) =>
    trFor(locale, 'blg_tier_${index.clamp(0, brainTiers.length - 1)}_name');

String brainTierTagline(int index, [String locale = 'en']) =>
    trFor(locale, 'blg_tier_${index.clamp(0, brainTiers.length - 1)}_tag');

String get myBrainTierName => botArena.cachedTierName(
  brainTierName(0, AppLocalizations.localeCode),
);

int get myLeagueRank => botArena.cachedRank;

class _Rival {
  final String name;
  final int xp;
  final int streak;
  final bool isMe;
  final String? botId;
  const _Rival(this.name, this.xp, this.streak, {this.isMe = false, this.botId});
}

List<_Rival> _leagueRivals() {
  final season = botArena.season;
  if (season == null) return const [];
  return [
    for (final e in season.sorted)
      _Rival(e.name, e.xp, e.streak, isMe: e.isMe, botId: e.isBot ? e.id : null),
  ];
}

class BrainLeaguePage extends StatefulWidget {
  final int initialTab;
  const BrainLeaguePage({super.key, this.initialTab = 0});

  @override
  State<BrainLeaguePage> createState() => _BrainLeaguePageState();
}

class _BrainLeaguePageState extends State<BrainLeaguePage>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;
  late final PageController _tiers;
  late final ScrollController _listScroll;

  int get _myTier => botArena.cachedTierIndex.clamp(0, brainTiers.length - 1);
  int _selected = 0;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(
      length: 2,
      vsync: this,
      initialIndex: widget.initialTab.clamp(0, 1),
    );
    _tiers = PageController(viewportFraction: 0.3, initialPage: _myTier);
    _listScroll = ScrollController();
    _selected = _myTier;
    botArena.addListener(_refreshArena);
    botArena.ensureLoaded().then((_) {
      if (!mounted) return;
      _refreshArena();
    });
  }

  void _refreshArena() {
    if (!mounted) return;
    botArena.setCachedTierName(
      brainTierName(_myTier, AppLocalizations.localeCode),
    );
    setState(() {
      if (_selected == 0 && _myTier != 0 && _tiers.hasClients) {
        _tiers.jumpToPage(_myTier);
      }
      _selected = _selected.clamp(0, brainTiers.length);
    });
  }

  @override
  void dispose() {
    botArena.removeListener(_refreshArena);
    _tabs.dispose();
    _tiers.dispose();
    _listScroll.dispose();
    super.dispose();
  }

  void _select(int i) {
    i = i.clamp(0, brainTiers.length);
    if (i == _selected) return;
    setState(() => _selected = i);
  }

  bool get _isTop => _selected == brainTiers.length - 1;
  bool get _isTournament => _selected == brainTiers.length;

  @override
  Widget build(BuildContext context) {
    final daysLeft = 8 - DateTime.now().weekday;
    final locked = _selected > _myTier && !_isTournament;
    final isTop = !locked && _isTop;
    final isTournament = !locked && _isTournament;
    final rivals = _leagueRivals();
    return Scaffold(
      primary: false,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        primary: false,
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        elevation: 0,
        scrolledUnderElevation: 0,
        automaticallyImplyLeading: false,
        title: Text(
          tr('blg_title'),
          style: TextStyle(
            color: Theme.of(context).colorScheme.onSurface,
            fontWeight: FontWeight.bold,
            fontSize: 20,
          ),
        ),
        centerTitle: true,
        actions: const [
          AiHelpButton(topic: AiHelpTopics.league),
          SizedBox(width: 12),
        ],
        bottom: TabBar(
          controller: _tabs,
          dividerColor: Colors.transparent,
          indicatorColor: violet,
          indicatorWeight: 3,
          labelColor: Theme.of(context).colorScheme.onSurface,
          unselectedLabelColor: context.mutedText,
          labelStyle: const TextStyle(fontWeight: FontWeight.w800),
          tabs: [
            Tab(text: tr('blg_tab_league')),
            Tab(text: tr('blg_tab_friends')),
          ],
        ),
      ),
      body: TabBarView(
            controller: _tabs,
            children: [
              CustomScrollView(
                controller: _listScroll,
                physics: const ClampingScrollPhysics(),
                slivers: [
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            locked
                                ? '???'
                                : (isTournament
                                      ? tr('blg_tournament')
                                      : brainTierName(
                                          _selected,
                                          AppLocalizations.localeCode,
                                        )),
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.onSurface,
                              fontWeight: FontWeight.w900,
                              fontSize: 24,
                            ),
                          ),
                          const SizedBox(height: 2),
                          if (!locked)
                            Text(
                              isTournament
                                  ? tr('blg_tournament_sub')
                                  : brainTierTagline(
                                      _selected,
                                      AppLocalizations.localeCode,
                                    ),
                              style: TextStyle(
                                color: context.mutedText,
                                fontSize: 13,
                              ),
                            ),
                          const SizedBox(height: 8),
                          _SeasonCountdownChip(
                            daysLeft: daysLeft,
                            rank: myLeagueRank,
                          ),
                        ],
                      ),
                    ),
                  ),
                  SliverToBoxAdapter(
                    child: SizedBox(
                      height: 148,
                      child: PageView.builder(
                        controller: _tiers,
                        itemCount: brainTiers.length + 1,
                        onPageChanged: _select,
                        itemBuilder: (context, i) {
                          if (i == brainTiers.length) {
                            return _TournamentTierCell(
                              selected: i == _selected,
                              onTap: () {
                                _tiers.animateToPage(
                                  i,
                                  duration: const Duration(milliseconds: 300),
                                  curve: Curves.easeOut,
                                );
                                _select(i);
                              },
                            );
                          }
                          return _TierCell(
                            index: i,
                            selected: i == _selected,
                            locked: i > _myTier,
                            onTap: () {
                              _tiers.animateToPage(
                                i,
                                duration: const Duration(milliseconds: 300),
                                curve: Curves.easeOut,
                              );
                              _select(i);
                            },
                          );
                        },
                      ),
                    ),
                  ),
                  if (locked)
                    const SliverToBoxAdapter(child: _LockedCard())
                  else if (isTournament)
                    SliverToBoxAdapter(
                      child: _TournamentCard(qualifiers: rivals),
                    )
                  else if (rivals.isEmpty)
                    const SliverToBoxAdapter(child: _EmptyBoard())
                  else if (isTop)
                    SliverList.builder(
                      itemCount: rivals.length + 1,
                      itemBuilder: (context, slot) {
                        if (slot == 20) return const _ZoneDivider(up: false);
                        final row = slot > 20 ? slot - 1 : slot;
                        final rival = rivals[row];
                        final rank = row + 1;
                        return _BoardRow(
                          key: ValueKey('league-$rank'),
                          rank: rank,
                          rival: rival,
                          isMe: rival.isMe,
                        );
                      },
                    )
                  else
                    SliverList.builder(
                      itemCount: rivals.length + 2,
                      itemBuilder: (context, slot) {
                        if (slot == 10) return const _ZoneDivider(up: true);
                        if (slot == 21) return const _ZoneDivider(up: false);
                        final row = slot > 21
                            ? slot - 2
                            : (slot > 10 ? slot - 1 : slot);
                        final rival = rivals[row];
                        final rank = row + 1;
                        return _BoardRow(
                          key: ValueKey('league-$rank'),
                          rank: rank,
                          rival: rival,
                          isMe: rival.isMe,
                        );
                      },
                    ),
                  const SliverToBoxAdapter(child: SizedBox(height: 120)),
                ],
              ),
              const _FriendsTab(),
            ],
          ),
    );
  }
}

class _FriendsTab extends StatelessWidget {
  const _FriendsTab();

  void _openBot(BuildContext context, String botId) {
    final bot = botArena.botById(botId);
    if (bot == null) return;
    AppFeedback.light();
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => FriendProfilePage(
          friend: botArena.botToFriend(bot),
          botId: bot.id,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: botArena,
      builder: (context, _) {
        final friends = botArena.friendBots();
        final suggestions = botArena.suggestions();
        final feed = botArena.feed;
        if (!botArena.hasSeason && friends.isEmpty) {
          return const Center(child: _EmptyBoard());
        }
        return ListView(
          padding: const EdgeInsets.fromLTRB(0, 16, 0, 120),
          children: [
            _FriendsSectionTitle(
              title: tr('blg_suggest_title'),
              subtitle: tr('blg_suggest_sub'),
            ),
            for (var i = 0; i < suggestions.length; i++)
              GestureDetector(
                onTap: () => _openBot(context, suggestions[i].id),
                child: _BoardRow(
                  key: ValueKey('suggest-${suggestions[i].id}'),
                  rank: i + 1,
                  rival: _Rival(
                    suggestions[i].name,
                    suggestions[i].xp,
                    suggestions[i].streak,
                  ),
                  isMe: false,
                ),
              ),
            _FriendsSectionTitle(
              title: tr('blg_friends_n', {'n': friends.length}),
              subtitle: friends.isEmpty
                  ? tr('blg_friends_empty_sub')
                  : tr('blg_friends_sub'),
            ),
            if (friends.isEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
                child: Text(
                  tr('blg_no_friends'),
                  style: TextStyle(color: context.mutedText, fontSize: 13),
                ),
              ),
            for (var i = 0; i < friends.length; i++)
              GestureDetector(
                onTap: () => _openBot(context, friends[i].id),
                child: _BoardRow(
                  key: ValueKey('friend-${friends[i].id}'),
                  rank: i + 1,
                  rival: _Rival(
                    friends[i].name,
                    friends[i].xp,
                    friends[i].streak,
                  ),
                  isMe: false,
                ),
              ),
            _FriendsSectionTitle(
              title: tr('blg_activity'),
              subtitle: tr('blg_activity_sub'),
            ),
            if (feed.isEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
                child: Text(
                  tr('blg_no_feed'),
                  style: TextStyle(color: context.mutedText, fontSize: 13),
                ),
              ),
            for (final event in feed.take(20))
              Container(
                margin: const EdgeInsets.fromLTRB(20, 4, 20, 4),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: context.cardBg,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: context.hairline, width: 1.5),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      event.text,
                      style: TextStyle(
                        color: context.inkText,
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      battleDateLabelIn(
                        AppLocalizations.localeCode,
                        event.at,
                      ),
                      style: TextStyle(
                        color: context.mutedText,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        );
      },
    );
  }
}

class _FriendsSectionTitle extends StatelessWidget {
  final String title;
  final String subtitle;
  const _FriendsSectionTitle({required this.title, required this.subtitle});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurface,
              fontWeight: FontWeight.w900,
              fontSize: 16,
            ),
          ),
          Text(
            subtitle,
            style: TextStyle(color: context.mutedText, fontSize: 12),
          ),
        ],
      ),
    );
  }
}

class _SeasonCountdownChip extends StatelessWidget {
  final int daysLeft;
  final int rank;
  const _SeasonCountdownChip({required this.daysLeft, required this.rank});

  @override
  Widget build(BuildContext context) {
    final label = rank > 0
        ? tr('blg_days_rank', {'d': daysLeft, 'r': rank})
        : tr('blg_days_left', {'d': daysLeft});
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: violet.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(99),
        border: Border.all(color: violet.withValues(alpha: 0.45)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const HugeIcon(
            icon: HugeIcons.strokeRoundedClock01,
            color: violetDark,
            size: 14,
            strokeWidth: 2.2,
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(
              color: violetDark,
              fontWeight: FontWeight.w800,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyBoard extends StatelessWidget {
  const _EmptyBoard();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            tr('blg_empty_title'),
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurface,
              fontWeight: FontWeight.w900,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            tr('blg_empty_body'),
            textAlign: TextAlign.center,
            style: TextStyle(color: context.mutedText, fontSize: 13),
          ),
        ],
      ),
    );
  }
}

class _TournamentTierCell extends StatefulWidget {
  final bool selected;
  final VoidCallback onTap;
  const _TournamentTierCell({required this.selected, required this.onTap});

  @override
  State<_TournamentTierCell> createState() => _TournamentTierCellState();
}

class _TournamentTierCellState extends State<_TournamentTierCell>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 6000),
    )..repeat();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const gold = Color(0xFFFFC400);
    const deep = Color(0xFF0B1026);
    final size = widget.selected ? 76.0 : 64.0;
    return GestureDetector(
      onTap: widget.onTap,
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 200),
        opacity: widget.selected ? 1 : 0.75,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(
              width: size + 24,
              height: size + 24,
              child: AnimatedBuilder(
              animation: _ctrl,
              child: Container(
                width: size,
                height: size,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: const LinearGradient(
                    colors: [Color(0xFF1B2451), deep],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  border: Border.all(
                    color: gold,
                    width: widget.selected ? 3 : 2,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: gold.withValues(alpha: 0.4),
                      blurRadius: widget.selected ? 22 : 14,
                      spreadRadius: 1,
                    ),
                  ],
                ),
                alignment: Alignment.center,
                child: const HugeIcon(
                  icon: HugeIcons.strokeRoundedTrophy,
                  color: gold,
                  size: 30,
                  strokeWidth: 2.2,
                ),
              ),
              builder: (context, child) {
                return Stack(
                  alignment: Alignment.center,
                  children: [
                    RepaintBoundary(
                      child: CustomPaint(
                        size: Size(size + 24, size + 24),
                        painter: _InfiniteOrbitPainter(progress: _ctrl.value),
                      ),
                    ),
                    child!,
                  ],
                );
              },
            ),
            ),
            const SizedBox(height: 6),
            Text(
              tr('blg_tournament'),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: widget.selected ? context.inkText : context.mutedText,
                fontWeight: widget.selected ? FontWeight.w900 : FontWeight.w700,
                fontSize: 11,
              ),
            ),
          ],
        ),
      ),
    );
  }

}

class _TierCell extends StatelessWidget {
  final int index;
  final bool selected;
  final bool locked;
  final VoidCallback onTap;
  const _TierCell({
    required this.index,
    required this.selected,
    required this.locked,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 200),
        opacity: locked ? 0.55 : (selected ? 1 : 0.75),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            RepaintBoundary(
              child: _BrainEmblem(tier: index, locked: locked, big: selected),
            ),
            const SizedBox(height: 6),
            Text(
              locked
                  ? '???'
                  : brainTierName(index, AppLocalizations.localeCode),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: selected ? context.inkText : context.mutedText,
                fontWeight: selected ? FontWeight.w900 : FontWeight.w700,
                fontSize: 11,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BrainEmblem extends StatelessWidget {
  final int tier;
  final bool locked;
  final bool big;
  const _BrainEmblem({
    required this.tier,
    required this.locked,
    this.big = false,
  });

  @override
  Widget build(BuildContext context) {
    final meta = brainTiers[tier.clamp(0, brainTiers.length - 1)];
    final size = big ? 76.0 : 64.0;
    final base = locked ? context.mutedText : meta.color;
    final epic = tier >= 11 && !locked;
    return SizedBox(
      width: size + 24,
      height: size + 24,
      child: Stack(
        alignment: Alignment.center,
        children: [
          CustomPaint(
            size: Size(size + 24, size + 24),
            painter: _ParticlePainter(
              count: locked ? 0 : meta.particles,
              color: base,
              seed: tier * 97 + 13,
            ),
          ),
          Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: locked
                  ? (context.isDark ? context.faintBg : const Color(0xFFE7DFD2))
                  : base.withValues(alpha: 0.14),
              border: Border.all(
                color: locked ? context.mutedText.withValues(alpha: 0.5) : base,
                width: epic ? 3 : 2,
              ),
              boxShadow: locked
                  ? null
                  : [
                      BoxShadow(
                        color: base.withValues(alpha: epic ? 0.45 : 0.25),
                        blurRadius: epic ? 22 : 12,
                        spreadRadius: epic ? 2 : 0,
                      ),
                    ],
            ),
            alignment: Alignment.center,
            child: locked
                ? HugeIcon(
                    icon: HugeIcons.strokeRoundedLock,
                    color: context.mutedText,
                    size: 26,
                    strokeWidth: 2,
                  )
                : HugeIcon(
                    icon: meta.icon,
                    color: base,
                    size: 30,
                    strokeWidth: 2.2,
                  ),
          ),
        ],
      ),
    );
  }
}

class _InfiniteOrbitPainter extends CustomPainter {
  final double progress;
  const _InfiniteOrbitPainter({required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    const gold = Color(0xFFFFC400);
    final c = size.center(Offset.zero);
    final base = size.width / 2 - 3;
    for (final rr in [base, base - 7]) {
      canvas.drawCircle(
        c,
        rr * 0.94,
        Paint()
          ..color = gold.withValues(alpha: 0.28)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.2,
      );
    }
    _ring(canvas, c, base * 0.94, 18, progress * 6.283185307, gold, 1.1, 0.65);
    _ring(
      canvas,
      c,
      (base - 7) * 0.94,
      12,
      -progress * 6.283185307 + 0.5,
      Colors.white,
      0.9,
      0.6,
    );
  }

  void _ring(
    Canvas canvas,
    Offset c,
    double r,
    int n,
    double phase,
    Color color,
    double minRad,
    double maxAlpha,
  ) {
    for (var i = 0; i < n; i++) {
      final a = phase + i * 6.283185307 / n;
      final p = Offset(c.dx + r * _cos(a), c.dy + r * _sin(a));
      final rad = minRad + ((i * 7) % 3) * 0.4;
      final bright = 0.5 + 0.5 * _sin(a - 1.570796327);
      final alpha = (0.3 + maxAlpha * bright).clamp(0.0, 1.0);
      canvas.drawCircle(
        p,
        rad,
        Paint()..color = color.withValues(alpha: alpha),
      );
    }
  }

  double _sin(double x) {
    var v = x % 6.283185307;
    if (v < 0) v += 6.283185307;
    const pi = 3.14159265;
    final s = v > pi ? v - pi : v;
    final sign = v > pi ? -1.0 : 1.0;
    return sign * 16 * s * (pi - s) / (5 * pi * pi - 4 * s * (pi - s));
  }

  double _cos(double x) => _sin(x + 1.570796327);

  @override
  bool shouldRepaint(covariant _InfiniteOrbitPainter old) =>
      old.progress != progress;
}

class _ParticlePainter extends CustomPainter {
  final int count;
  final Color color;
  final int seed;
  const _ParticlePainter({
    required this.count,
    required this.color,
    required this.seed,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (count == 0) return;
    final c = size.center(Offset.zero);
    final r = size.width / 2 - 4;
    for (var i = 0; i < count; i++) {
      final a = (seed * 37 + i * 137) % 360 * 3.14159265 / 180;
      final rr = r - ((seed + i * 29) % 10);
      final p = Offset(c.dx + rr * 0.92 * _cos(a), c.dy + rr * 0.92 * _sin(a));
      final rad = 1.2 + ((seed + i * 7) % 3) * 0.8;
      canvas.drawCircle(p, rad, Paint()..color = color.withValues(alpha: 0.75));
    }
  }

  double _sin(double x) {
    return _trig(x, false);
  }

  double _cos(double x) => _trig(x, true);

  double _trig(double x, bool cos) {
    var v = x % 6.283185307;
    if (v < 0) v += 6.283185307;
    if (cos) v += 1.570796327;
    const pi = 3.14159265;
    final s = v > pi ? v - pi : v;
    final sign = v > pi ? -1.0 : 1.0;
    return sign * 16 * s * (pi - s) / (5 * pi * pi - 4 * s * (pi - s));
  }

  @override
  bool shouldRepaint(covariant _ParticlePainter old) =>
      old.count != count || old.color != color || old.seed != seed;
}

class _ZoneDivider extends StatelessWidget {
  final bool up;
  const _ZoneDivider({required this.up});

  @override
  Widget build(BuildContext context) {
    final color = up ? teal : coral;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      child: Row(
        children: [
          Expanded(
            child: Container(height: 2, color: color.withValues(alpha: 0.5)),
          ),
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 8),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(99),
              border: Border.all(color: color.withValues(alpha: 0.5)),
            ),
            child: Text(
              up ? tr('blg_promo') : tr('blg_releg'),
              style: TextStyle(
                color: up ? const Color(0xFF0B7E72) : const Color(0xFFB3261E),
                fontWeight: FontWeight.w800,
                fontSize: 11,
              ),
            ),
          ),
          Expanded(
            child: Container(height: 2, color: color.withValues(alpha: 0.5)),
          ),
        ],
      ),
    );
  }
}

class _BoardRow extends StatelessWidget {
  final int rank;
  final _Rival rival;
  final bool isMe;
  const _BoardRow({
    super.key,
    required this.rank,
    required this.rival,
    required this.isMe,
  });

  @override
  Widget build(BuildContext context) {
    final medal = rank == 1
        ? const Color(0xFFFFC400)
        : rank == 2
        ? const Color(0xFFB0B7C3)
        : rank == 3
        ? const Color(0xFFE09A5A)
        : null;
    return Container(
      margin: const EdgeInsets.fromLTRB(20, 4, 20, 4),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: isMe ? context.washBg : context.cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isMe ? violet : context.hairline,
          width: isMe ? 2 : 1.5,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 30,
            height: 30,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: medal?.withValues(alpha: 0.2) ?? Colors.transparent,
              border: medal == null ? null : Border.all(color: medal, width: 2),
            ),
            child: Text(
              '$rank',
              style: TextStyle(
                color: medal ?? context.mutedText,
                fontWeight: FontWeight.w900,
                fontSize: 14,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Container(
            width: 40,
            height: 40,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: (isMe ? violet : sky).withValues(alpha: 0.16),
            ),
            child: Text(
              rival.name.characters.first,
              style: TextStyle(
                color: isMe ? violetDark : context.inkText,
                fontWeight: FontWeight.w900,
                fontSize: 17,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        rival.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: context.inkText,
                          fontWeight: FontWeight.w800,
                          fontSize: 14,
                        ),
                      ),
                    ),
                    if (isMe)
                      Container(
                        margin: const EdgeInsets.only(left: 6),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: violet,
                          borderRadius: BorderRadius.circular(99),
                        ),
                        child: Text(
                          tr('blg_you'),
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w900,
                            fontSize: 10,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    HugeIcon(
                      icon: HugeIcons.strokeRoundedFire02,
                      color: amber,
                      size: 13,
                      strokeWidth: 2.2,
                    ),
                    const SizedBox(width: 3),
                    Text(
                      tr('blg_streak', {'n': rival.streak}),
                      style: TextStyle(color: context.mutedText, fontSize: 11),
                    ),
                  ],
                ),
                if (isMe && botArena.rewards.totalBonusXp > 0)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(
                      tr('blg_bonus', {
                        'n': botArena.rewards.totalBonusXp,
                      }),
                      style: const TextStyle(
                        color: Color(0xFF16A34A),
                        fontWeight: FontWeight.w800,
                        fontSize: 11,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: violet.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(99),
            ),
            child: Text(
              '${rival.xp} XP',
              style: const TextStyle(
                color: violetDark,
                fontWeight: FontWeight.w900,
                fontSize: 12,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TournamentCard extends StatelessWidget {
  final List<_Rival> qualifiers;
  const _TournamentCard({this.qualifiers = const []});

  @override
  Widget build(BuildContext context) {
    const gold = Color(0xFFFFC400);
    const deep = Color(0xFF0B1026);
    final eight = qualifiers.take(8).toList();
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF1B2451), deep],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: gold.withValues(alpha: 0.7), width: 1.5),
          boxShadow: [
            BoxShadow(
              color: gold.withValues(alpha: 0.22),
              blurRadius: 18,
              spreadRadius: 0,
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: gold.withValues(alpha: 0.16),
                  ),
                  child: const HugeIcon(
                    icon: HugeIcons.strokeRoundedTrophy,
                    color: gold,
                    size: 20,
                    strokeWidth: 2,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        tr('blg_tournament'),
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w900,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        tr('blg_tourn_sub'),
                        style: const TextStyle(
                          color: Color(0xFFB9C0D8),
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: gold,
                    borderRadius: BorderRadius.circular(99),
                  ),
                  child: Text(
                    tr('blg_top8'),
                    style: TextStyle(
                      color: deep,
                      fontWeight: FontWeight.w900,
                      fontSize: 11,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              tr('blg_tourn_body'),
              style: TextStyle(
                color: Color(0xFFD6DBEC),
                fontSize: 12,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 12),
            _TournamentBracket(qualifiers: eight),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: gold.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: gold.withValues(alpha: 0.5)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const HugeIcon(
                    icon: HugeIcons.strokeRoundedTrophy,
                    color: gold,
                    size: 20,
                    strokeWidth: 2,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          tr('blg_reward'),
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w900,
                            fontSize: 13,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          tr('blg_reward_body'),
                          style: const TextStyle(
                            color: Color(0xFFD6DBEC),
                            fontSize: 12,
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
        ),
      ),
    );
  }
}

class _TournamentBracket extends StatelessWidget {
  final List<_Rival> qualifiers;
  const _TournamentBracket({required this.qualifiers});

  static const double matchH = 64;
  static const double smallGap = 8;
  static const double bigGap = 32;
  static const double totalH = 4 * matchH + 2 * smallGap + bigGap;
  static const double cardW = 148;
  static const double linkW = 20;

  @override
  Widget build(BuildContext context) {
    if (qualifiers.length < 8) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Text(
          tr('blg_no_field'),
          style: const TextStyle(color: Color(0xFFB9C0D8), fontSize: 12),
        ),
      );
    }
    final qf = [
      [qualifiers[0], qualifiers[7]],
      [qualifiers[3], qualifiers[4]],
      [qualifiers[1], qualifiers[6]],
      [qualifiers[2], qualifiers[5]],
    ];
    const qfCenters = [32.0, 104.0, 200.0, 272.0];
    const sfCenters = [68.0, 236.0];
    const finalCenter = 152.0;
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _BracketRoundColumn(
            title: tr('blg_qf'),
            children: [
              for (var i = 0; i < 4; i++) ...[
                _BracketMatch(
                  seedA: i * 2 + 1,
                  seedB: i * 2 + 2,
                  teamA: qf[i][0],
                  teamB: qf[i][1],
                ),
                if (i == 0 || i == 2) const SizedBox(height: smallGap),
                if (i == 1) const SizedBox(height: bigGap),
              ],
            ],
          ),
          _BracketLinks(left: qfCenters, right: sfCenters),
          _BracketRoundColumn(
            title: tr('blg_sf'),
            children: [
              const SizedBox(height: 36),
              _BracketMatch.tbd(label: tr('blg_sf1')),
              const SizedBox(height: 104),
              _BracketMatch.tbd(label: tr('blg_sf2')),
              const SizedBox(height: 36),
            ],
          ),
          _BracketLinks(left: sfCenters, right: [finalCenter]),
          _BracketRoundColumn(
            title: tr('blg_final'),
            children: [
              const SizedBox(height: 120),
              _BracketMatch.tbd(label: tr('blg_final')),
              const SizedBox(height: 8),
              const _ChampionCard(),
              const SizedBox(height: 56),
            ],
          ),
        ],
      ),
    );
  }
}

class _BracketRoundColumn extends StatelessWidget {
  final String title;
  final List<Widget> children;
  const _BracketRoundColumn({required this.title, required this.children});

  @override
  Widget build(BuildContext context) {
    const gold = Color(0xFFFFC400);
    return SizedBox(
      width: _TournamentBracket.cardW,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(vertical: 6),
            decoration: BoxDecoration(
              color: gold.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(99),
              border: Border.all(color: gold.withValues(alpha: 0.6)),
            ),
            child: Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: gold,
                fontWeight: FontWeight.w800,
                fontSize: 11,
              ),
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: _TournamentBracket.totalH,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: children,
            ),
          ),
        ],
      ),
    );
  }
}

class _BracketLinks extends StatelessWidget {
  final List<double> left;
  final List<double> right;
  const _BracketLinks({required this.left, required this.right});

  @override
  Widget build(BuildContext context) {
    const headerOffset = 22.0 + 8;
    return Padding(
      padding: const EdgeInsets.only(top: headerOffset),
      child: CustomPaint(
        size: const Size(_TournamentBracket.linkW, _TournamentBracket.totalH),
        painter: _BracketLinksPainter(left: left, right: right),
      ),
    );
  }
}

class _BracketLinksPainter extends CustomPainter {
  final List<double> left;
  final List<double> right;
  const _BracketLinksPainter({required this.left, required this.right});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFFFFC400).withValues(alpha: 0.7)
      ..strokeWidth = 1.6
      ..style = PaintingStyle.stroke;
    final midX = size.width / 2;
    for (var k = 0; k < right.length; k++) {
      final yR = right[k];
      final yA = left[2 * k];
      final yB = left[2 * k + 1];
      final path = Path()
        ..moveTo(0, yA)
        ..lineTo(midX, yA)
        ..lineTo(midX, yB)
        ..lineTo(0, yB);
      canvas.drawPath(path, paint);
      canvas.drawLine(Offset(midX, yR), Offset(size.width, yR), paint);
    }
  }

  @override
  bool shouldRepaint(covariant _BracketLinksPainter old) => false;
}

class _BracketMatch extends StatelessWidget {
  final int? seedA;
  final int? seedB;
  final _Rival? teamA;
  final _Rival? teamB;
  final String? label;
  const _BracketMatch({
    required this.seedA,
    required this.seedB,
    required this.teamA,
    required this.teamB,
  }) : label = null;
  const _BracketMatch.tbd({required this.label})
    : seedA = null,
      seedB = null,
      teamA = null,
      teamB = null;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: _TournamentBracket.matchH,
      decoration: BoxDecoration(
        color: context.cardBg.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.16)),
      ),
      child: Column(
        children: [
          Expanded(
            child: _BracketSeed(seed: seedA, team: teamA, label: label),
          ),
          Container(height: 1, color: context.cardBg.withValues(alpha: 0.16)),
          Expanded(
            child: _BracketSeed(seed: seedB, team: teamB, label: label),
          ),
        ],
      ),
    );
  }
}

class _BracketSeed extends StatelessWidget {
  final int? seed;
  final _Rival? team;
  final String? label;
  const _BracketSeed({required this.seed, required this.team, this.label});

  @override
  Widget build(BuildContext context) {
    const gold = Color(0xFFFFC400);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          if (seed != null)
            Text(
              '$seed',
              style: const TextStyle(
                color: gold,
                fontWeight: FontWeight.w900,
                fontSize: 10,
              ),
            ),
          if (seed != null) const SizedBox(width: 6),
          Expanded(
            child: Text(
              team?.name ?? (label ?? tr('blg_tbd')),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: team == null ? const Color(0xFFB9C0D8) : Colors.white,
                fontWeight: FontWeight.w800,
                fontSize: 12,
                fontStyle: team == null ? FontStyle.italic : FontStyle.normal,
              ),
            ),
          ),
          if (team != null)
            Text(
              '${team!.xp}',
              style: const TextStyle(
                color: gold,
                fontWeight: FontWeight.w800,
                fontSize: 10,
              ),
            ),
        ],
      ),
    );
  }
}

class _ChampionCard extends StatelessWidget {
  const _ChampionCard();

  @override
  Widget build(BuildContext context) {
    const gold = Color(0xFFFFC400);
    return Container(
      height: 56,
      decoration: BoxDecoration(
        color: gold.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: gold.withValues(alpha: 0.7)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const HugeIcon(
            icon: HugeIcons.strokeRoundedTrophy,
            color: gold,
            size: 18,
            strokeWidth: 2,
          ),
          const SizedBox(width: 6),
          Text(
            tr('blg_champion'),
            style: const TextStyle(
              color: gold,
              fontWeight: FontWeight.w900,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}

class _LockedCard extends StatelessWidget {
  const _LockedCard();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 180),
      child: Column(
        children: [
          Container(
            width: 96,
            height: 96,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Color(0xFFE7DFD2),
            ),
            alignment: Alignment.center,
            child: HugeIcon(
              icon: HugeIcons.strokeRoundedLock,
              color: context.mutedText,
              size: 34,
              strokeWidth: 2,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            tr('blg_locked_title'),
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurface,
              fontWeight: FontWeight.w900,
              fontSize: 17,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            tr('blg_locked_body'),
            textAlign: TextAlign.center,
            style: TextStyle(color: context.mutedText, fontSize: 13),
          ),
        ],
      ),
    );
  }
}
