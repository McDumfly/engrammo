import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../services/app_feedback.dart';

import 'package:flutter_svg/flutter_svg.dart';
import 'package:hugeicons/hugeicons.dart';

import '../widgets/app_buttons.dart';
import 'avatar_selection_screen.dart';
import '../models/avatar_traits.dart';
import '../models/battle_rating.dart';
import 'brain_league.dart' show myBrainTierName, myLeagueRank;
import '../services/auth_service.dart';
import '../services/dicebear_generator.dart';
import '../services/memory_store.dart';
import 'settings_screen.dart';

import '../models/collectibles.dart' show engram;
import 'memory_profile.dart' show ink, violet, teal, amber, coral, memoryKinds;

class KreedsProfilePage extends StatefulWidget {
  const KreedsProfilePage({super.key});

  @override
  State<KreedsProfilePage> createState() => _KreedsProfilePageState();
}

class _KreedsProfilePageState extends State<KreedsProfilePage> {
  // Friss fiók nulláról indul: nincs mock név, pont vagy széria.
  // A mentett értékek (ha vannak) az initState-ben töltődnek vissza.
  String displayName = '';
  String username = '';
  int streak = 0;
  int xp = 0;
  // Egyetlen fizetoeszkoz, mint a gyemant: engramok.
  int engrams = 0;
  String get leagueName => myBrainTierName;
  int get leagueRank => myLeagueRank;
  int battleRating = BattleRating.startingRating;
  Map<String, String> avatarOpts = AvatarTraits.defaults();
  List<int> scores = const [0, 0, 0, 0, 0, 0];
  List<bool> weekDone = const [false, false, false, false, false, false, false];

  @override
  void initState() {
    super.initState();
    MemoryStore.loadBattleRating(defaultRating: BattleRating.startingRating)
        .then((rating) {
          if (!mounted) return;
          setState(() => battleRating = rating);
        });
    MemoryStore.loadScores().then((saved) {
      if (!mounted || saved == null || saved.isEmpty) return;
      final fixed = List<int>.generate(
        memoryKinds.length,
        (i) => i < saved.length ? saved[i].clamp(0, 100) : 0,
      );
      setState(() => scores = fixed);
    });
    MemoryStore.loadStreakState()
        .then((s) {
          if (!mounted) return;
          final now = DateTime.now();
          final today = DateTime(now.year, now.month, now.day);
          // A hét-nézet a legutóbbi 7 nap előzményéből épül fel.
          final done = List<bool>.generate(7, (i) {
            final day = today.subtract(Duration(days: 6 - i));
            return s.history.any(
              (h) => h.year == day.year && h.month == day.month && h.day == day.day,
            );
          });
          setState(() {
            streak = s.streak;
            engrams = s.engrams;
            weekDone = done;
          });
        })
        .catchError((_) {});
    // A mentett profil-azonosítók visszakerülnek (belépéskor a
    // felhőből is frissülhetnek).
    MemoryStore.loadProfile().then((p) {
      if (!mounted) return;
      setState(() {
        displayName = p.displayName;
        username = p.username;
      });
    });
    // A mentett avatar visszaker, es elomelegitjuk a cache-t,
    // hogy az elso kepkockan se kelljen ujrageneralni.
    MemoryStore.loadAvatarOpts(AvatarTraits.defaults()).then((saved) {
      if (!mounted) return;
      setState(() => avatarOpts = saved);
      DicebearGenerator.generateAvatarSvgAsync(
        DicebearGenerator.withoutBackground(saved),
      );
    });
  }

  int get bestIndex {
    var best = 0;
    for (var i = 1; i < scores.length; i++) {
      if (scores[i] > scores[best]) best = i;
    }
    return best;
  }

  int get memoryLevel {
    final avg = scores.reduce((a, b) => a + b) ~/ scores.length;
    return (avg ~/ 10) + 1;
  }

  void _openAvatarEditor() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => AvatarSelectionScreen(
          initialOpts: avatarOpts,
          onSaved: (opts) {
            setState(() => avatarOpts = opts);
            MemoryStore.saveAvatarOpts(opts);
          },
        ),
      ),
    );
  }

  void _openSettings() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => SettingsScreen(
          isGoogleUser: authService.isGoogleUser,
          initialDisplayName: displayName,
          initialUsername: username,
          initialEmail: authService.email,
        ),
      ),
    );
  }

  // A rezgést az EngramIconButton / EngramButton adja belülről
  // ([app_buttons.dart]), ezért itt már nem rezgünk duplán.
  void _share() {}

  void _addFriend() {}

  @override
  Widget build(BuildContext context) {
    final best = bestIndex;
    final level = memoryLevel;
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: CustomScrollView(
            physics: const ClampingScrollPhysics(),
            slivers: [
              SliverToBoxAdapter(
                child: SafeArea(
                  bottom: false,
                  child: _TopBar(
                    onSettingsTap: () {
                      AppFeedback.light();
                      _openSettings();
                    },
                  ),
                ),
              ),
              SliverToBoxAdapter(
                child: _Hero(
                  displayName: displayName.isEmpty ? 'New learner' : displayName,
                  username: username.isEmpty ? 'new_learner' : username,
                  streak: streak,
                  following: 0,
                  followers: 0,
                  avatarOpts: avatarOpts,
                  onAvatarTap: _openAvatarEditor,
                  onShareTap: _share,
                  onAddFriendTap: _addFriend,
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
                sliver: SliverToBoxAdapter(
                  child: _MemoryIdentityCard(
                    kindName: memoryKinds[best].name,
                    kindModule: memoryKinds[best].module,
                    kindIcon: memoryKinds[best].icon,
                    kindTint: memoryKinds[best].tint,
                    score: scores[best],
                    level: level,
                  ),
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
                sliver: SliverToBoxAdapter(child: _TypeBars(scores: scores)),
              ),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
                sliver: SliverToBoxAdapter(
                  child: _QuickPills(
                    streak: streak,
                    xp: xp,
                    battleRating: battleRating,
                    leagueName: leagueName,
                    leagueRank: leagueRank,
                  ),
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
                sliver: SliverToBoxAdapter(
                  child: _WeekCard(weekDone: weekDone, streak: streak),
                ),
              ),
              const SliverPadding(
                padding: EdgeInsets.fromLTRB(20, 12, 20, 0),
                sliver: SliverToBoxAdapter(child: _MemoryBadges()),
              ),
              const SliverToBoxAdapter(child: SizedBox(height: 120)),
            ],
          ),
    );
  }
}

String compactNumber(int n) {
  if (n >= 1000) return '${(n / 1000).toStringAsFixed(1)}K';
  return '$n';
}

class _TopBar extends StatelessWidget {
  final VoidCallback onSettingsTap;
  const _TopBar({required this.onSettingsTap});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
      child: Row(
        children: [
          Expanded(
            child: Text(
              'Profile',
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurface,
                fontWeight: FontWeight.w900,
                fontSize: 22,
              ),
            ),
          ),
          _CircleBtn(
            icon: HugeIcons.strokeRoundedSettings01,
            onTap: onSettingsTap,
          ),
        ],
      ),
    );
  }
}

class _CircleBtn extends StatelessWidget {
  final List<List<dynamic>> icon;
  final VoidCallback onTap;
  const _CircleBtn({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: context.cardBg,
          shape: BoxShape.circle,
          border: Border.all(color: context.hairline, width: 2),
        ),
        alignment: Alignment.center,
        child: HugeIcon(
          icon: icon,
          color: context.inkText,
          size: 20,
          strokeWidth: 2,
        ),
      ),
    );
  }
}

class _Hero extends StatelessWidget {
  final String displayName;
  final String username;
  final int streak;
  final int following;
  final int followers;
  final Map<String, String> avatarOpts;
  final VoidCallback onAvatarTap;
  final VoidCallback onShareTap;
  final VoidCallback onAddFriendTap;

  const _Hero({
    required this.displayName,
    required this.username,
    required this.streak,
    this.following = 0,
    this.followers = 0,
    required this.avatarOpts,
    required this.onAvatarTap,
    required this.onShareTap,
    required this.onAddFriendTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 0),
      child: Column(
        children: [
          Stack(
            clipBehavior: Clip.none,
            children: [
              GestureDetector(
                onTap: () {
                  AppFeedback.light();
                  onAvatarTap();
                },
                child: RepaintBoundary(
                  child: _StaticRing(
                    child: _AvatarFace(opts: avatarOpts, size: 108),
                  ),
                ),
              ),
              Positioned(
                top: 2,
                right: -2,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 9,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: context.cardBg,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: context.hairline, width: 2),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const HugeIcon(
                        icon: HugeIcons.strokeRoundedFire,
                        color: coral,
                        size: 15,
                        strokeWidth: 2.2,
                      ),
                      const SizedBox(width: 3),
                      Text(
                        '$streak',
                        style: const TextStyle(
                          color: coral,
                          fontWeight: FontWeight.w900,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              Positioned(
                bottom: 4,
                right: 0,
                child: GestureDetector(
                  onTap: () {
                    AppFeedback.light();
                    onAvatarTap();
                  },
                  child: Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: context.cardBg,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 2),
                      boxShadow: [
                        BoxShadow(
                          color: context.isDark
                              ? Colors.black.withValues(alpha: 0.4)
                              : const Color(0xFF22314A).withValues(alpha: 0.16),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                        BoxShadow(
                          color: violet.withValues(alpha: 0.18),
                          blurRadius: 16,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    alignment: Alignment.center,
                    child: Container(
                      width: 30,
                      height: 30,
                      decoration: BoxDecoration(
                        color: context.softBg,
                        shape: BoxShape.circle,
                      ),
                      alignment: Alignment.center,
                      child: HugeIcon(
                        icon: HugeIcons.strokeRoundedPencilEdit02,
                        size: 16,
                        color: context.inkText,
                        strokeWidth: 2.0,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            displayName,
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurface,
              fontWeight: FontWeight.w900,
              fontSize: 22,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 4),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: context.inkText.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              '@$username',
              style: TextStyle(
                color: context.mutedText,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          const SizedBox(height: 14),
          _FollowStats(following: following, followers: followers),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(child: _AddFriendsBtn(onTap: onAddFriendTap)),
              const SizedBox(width: 12),
              _ShareSquareBtn(onTap: onShareTap),
            ],
          ),
        ],
      ),
    );
  }
}

class _FollowStats extends StatelessWidget {
  final int following;
  final int followers;
  const _FollowStats({required this.following, required this.followers});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: context.cardBg,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: context.hairline, width: 2),
      ),
      child: Row(
        children: [
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                color: context.softBg,
                borderRadius: BorderRadius.circular(18),
              ),
              child: Column(
                children: [
                  Text(
                    '$following',
                    style: TextStyle(
                      color: violet,
                      fontWeight: FontWeight.w900,
                      fontSize: 26,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Following',
                    style: TextStyle(
                      color: context.mutedText,
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                color: Color(0xFF9B7BFF).withValues(alpha: 0.16),

                borderRadius: BorderRadius.circular(18),
              ),
              child: Column(
                children: [
                  Text(
                    '$followers',
                    style: TextStyle(
                      color: Color(0xFF9B7BFF),
                      fontWeight: FontWeight.w900,
                      fontSize: 26,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Followers',
                    style: TextStyle(
                      color: context.mutedText,
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
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

class _AddFriendsBtn extends StatelessWidget {
  final VoidCallback onTap;
  const _AddFriendsBtn({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return EngramButton(
      label: 'ADD FRIENDS',
      icon: HugeIcons.strokeRoundedUserAdd01,
      onPressed: onTap,
    );
  }
}

class _ShareSquareBtn extends StatelessWidget {
  final VoidCallback onTap;
  const _ShareSquareBtn({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return EngramIconButton(icon: HugeIcons.strokeRoundedShare01, onTap: onTap);
  }
}

/// A profilavatar cache-bolt rajzol: a [Future] az [State]-ben el,
/// nem a `build`-ben keszul, ezert uj latogatasnal es barmely
/// szuloi `setState`-nel sem indul ujrageneralas.
///
/// Amig az SVG megerkezik, az elozo avatar latszik tovabb —
/// csak az elso, meg sosem latott avatarnal van helykitolto ikon.
class _AvatarFace extends StatefulWidget {
  final Map<String, String> opts;
  final double size;
  const _AvatarFace({required this.opts, required this.size});

  @override
  State<_AvatarFace> createState() => _AvatarFaceState();
}

class _AvatarFaceState extends State<_AvatarFace> {
  String _key = '';
  String? _syncSvg;
  String? _lastSvg;
  Future<String>? _future;

  @override
  void initState() {
    super.initState();
    _resolve();
  }

  @override
  void didUpdateWidget(covariant _AvatarFace oldWidget) {
    super.didUpdateWidget(oldWidget);
    final key = DicebearGenerator.cacheKey(
      DicebearGenerator.withoutBackground(widget.opts),
    );
    if (key != _key) _resolve();
  }

  void _resolve() {
    final display = DicebearGenerator.withoutBackground(widget.opts);
    _key = DicebearGenerator.cacheKey(display);
    _lastSvg = _syncSvg ?? _lastSvg;
    _syncSvg = DicebearGenerator.cachedSvg(display);
    _future = _syncSvg != null
        ? null
        : DicebearGenerator.generateAvatarSvgAsync(display);
  }

  Color _bg() {
    final hex = (widget.opts['backgroundColor'] ?? 'ffffff').trim();
    if (hex.isEmpty || hex == 'transparent') {
      return Colors.white;
    }
    final argb = int.tryParse('FF$hex', radix: 16);
    if (argb == null) return Colors.white;
    return Color(argb);
  }

  Widget _placeholder(BuildContext context) {
    return Center(
      child: HugeIcon(
        icon: HugeIcons.strokeRoundedUserCircle,
        size: 56,
        color: context.inkText,
        strokeWidth: 2.0,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final sync = _syncSvg;
    final Widget face;
    if (sync != null && sync.isNotEmpty) {
      face = SvgPicture.string(sync, fit: BoxFit.contain);
    } else {
      face = FutureBuilder<String>(
        future: _future,
        builder: (context, snapshot) {
          var svg = snapshot.data;
          if (svg == null || svg.isEmpty) {
            final last = _lastSvg;
            if (last != null && last.isNotEmpty) {
              return SvgPicture.string(last, fit: BoxFit.contain);
            }
            return _placeholder(context);
          }
          return SvgPicture.string(svg, fit: BoxFit.contain);
        },
      );
    }
    return Container(
      width: widget.size,
      height: widget.size,
      decoration: BoxDecoration(color: _bg(), shape: BoxShape.circle),
      child: ClipOval(child: face),
    );
  }
}

class _StaticRing extends StatelessWidget {
  final Widget child;
  const _StaticRing({required this.child});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 126,
      height: 126,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Container(
            width: 126,
            height: 126,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              gradient: SweepGradient(
                colors: [
                  Color(0xFF4FA8FF),
                  Color(0xFFCE82FF),
                  Color(0xFFFFAA2B),
                  Color(0xFF4FA8FF),
                ],
              ),
            ),
          ),
          Container(
            width: 116,
            height: 116,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: context.cardBg,
            ),
            alignment: Alignment.center,
            child: child,
          ),
        ],
      ),
    );
  }
}

class _MemoryIdentityCard extends StatelessWidget {
  final String kindName;
  final String kindModule;
  final List<List<dynamic>> kindIcon;
  final Color kindTint;
  final int score;
  final int level;
  const _MemoryIdentityCard({
    required this.kindName,
    required this.kindModule,
    required this.kindIcon,
    required this.kindTint,
    required this.score,
    required this.level,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.cardBg,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: context.hairline, width: 2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: kindTint.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(14),
                ),
                alignment: Alignment.center,
                child: HugeIcon(
                  icon: kindIcon,
                  color: kindTint,
                  size: 26,
                  strokeWidth: 2,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'STRONGEST TYPE',
                      style: TextStyle(
                        color: context.mutedText,
                        fontWeight: FontWeight.w900,
                        fontSize: 11,
                        letterSpacing: 1.1,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      kindName,
                      style: TextStyle(
                        color: context.inkText,
                        fontWeight: FontWeight.w900,
                        fontSize: 20,
                      ),
                    ),
                    Text(
                      kindModule,
                      style: TextStyle(color: context.mutedText, fontSize: 13),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: amber,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '$score%',
                  style: const TextStyle(
                    color: Color(0xFF6B4E00),
                    fontWeight: FontWeight.w900,
                    fontSize: 14,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              HugeIcon(
                icon: engram.icon,
                color: engram.color,
                size: 18,
                strokeWidth: 2.2,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  'Memory level $level',
                  style: TextStyle(
                    color: context.inkText,
                    fontWeight: FontWeight.w800,
                    fontSize: 14,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _TypeBars extends StatelessWidget {
  final List<int> scores;
  const _TypeBars({required this.scores});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: context.hairline, width: 2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Memory map',
            style: TextStyle(
              color: context.inkText,
              fontWeight: FontWeight.w900,
              fontSize: 15,
            ),
          ),
          const SizedBox(height: 10),
          for (var i = 0; i < memoryKinds.length; i++)
            Padding(
              padding: EdgeInsets.only(
                bottom: i == memoryKinds.length - 1 ? 0 : 10,
              ),
              child: Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: memoryKinds[i].tint.withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    alignment: Alignment.center,
                    child: HugeIcon(
                      icon: memoryKinds[i].icon,
                      color: memoryKinds[i].tint,
                      size: 19,
                      strokeWidth: 2.2,
                    ),
                  ),
                  const SizedBox(width: 10),
                  SizedBox(
                    width: 92,
                    child: Text(
                      memoryKinds[i].name,
                      style: TextStyle(
                        color: context.inkText,
                        fontWeight: FontWeight.w800,
                        fontSize: 13,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(99),
                      child: Container(
                        height: 10,
                        color: context.inkText.withValues(alpha: 0.08),
                        child: FractionallySizedBox(
                          alignment: Alignment.centerLeft,
                          widthFactor: (scores[i] / 100).clamp(0.03, 1.0),
                          child: Container(
                            decoration: BoxDecoration(
                              color: memoryKinds[i].tint,
                              borderRadius: BorderRadius.circular(99),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  SizedBox(
                    width: 44,
                    child: Text(
                      '${scores[i]}%',
                      textAlign: TextAlign.right,
                      style: TextStyle(
                        color: context.inkText,
                        fontWeight: FontWeight.w900,
                        fontSize: 13,
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
}

class _QuickPills extends StatelessWidget {
  final int streak;
  final int xp;
  final int battleRating;
  final String leagueName;
  final int leagueRank;
  const _QuickPills({
    required this.streak,
    required this.xp,
    required this.battleRating,
    required this.leagueName,
    required this.leagueRank,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _Pill(
            icon: HugeIcons.strokeRoundedFire,
            color: coral,
            value: '$streak',
            label: 'streak',
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _Pill(
            icon: HugeIcons.strokeRoundedStar,
            color: violet,
            value: compactNumber(xp),
            label: 'XP',
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _Pill(
            icon: HugeIcons.strokeRoundedSwords,
            color: teal,
            value: '$battleRating',
            label: 'battle',
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _Pill(
            icon: HugeIcons.strokeRoundedTrophy,
            color: amber,
            value: leagueRank <= 0 ? '—' : '#$leagueRank',
            label: leagueName,
          ),
        ),
      ],
    );
  }
}

class _Pill extends StatelessWidget {
  final List<List<dynamic>> icon;
  final Color color;
  final String value;
  final String label;
  const _Pill({
    required this.icon,
    required this.color,
    required this.value,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(
        color: context.cardBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: context.hairline, width: 2),
      ),
      child: Column(
        children: [
          HugeIcon(icon: icon, color: color, size: 20, strokeWidth: 2.2),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              color: context.inkText,
              fontWeight: FontWeight.w900,
              fontSize: 14,
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: TextStyle(color: context.mutedText, fontSize: 11),
            ),
          ),
        ],
      ),
    );
  }
}

class _WeekCard extends StatelessWidget {
  final List<bool> weekDone;
  final int streak;
  const _WeekCard({required this.weekDone, required this.streak});

  static const _days = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: context.hairline, width: 2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              HugeIcon(
                icon: HugeIcons.strokeRoundedCalendar01,
                color: teal,
                size: 20,
                strokeWidth: 2.2,
              ),
              SizedBox(width: 8),
              Text(
                'Weekly training',
                style: TextStyle(
                  color: context.inkText,
                  fontWeight: FontWeight.w900,
                  fontSize: 15,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          RepaintBoundary(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: List.generate(7, (i) {
                final done = weekDone[i];
                return Column(
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: done
                            ? teal
                            : context.inkText.withValues(alpha: 0.07),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: done ? teal : context.hairline,
                          width: 2,
                        ),
                      ),
                      alignment: Alignment.center,
                      child: done
                          ? HugeIcon(
                              icon: HugeIcons.strokeRoundedTick02,
                              color: Colors.white,
                              size: 18,
                              strokeWidth: 2.2,
                            )
                          : Text(
                              _days[i],
                              style: TextStyle(
                                color: context.mutedText,
                                fontWeight: FontWeight.w800,
                                fontSize: 12,
                              ),
                            ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _days[i],
                      style: TextStyle(color: context.mutedText, fontSize: 11),
                    ),
                  ],
                );
              }),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '$streak-day streak — keep it up!',
            style: TextStyle(color: context.mutedText, fontSize: 13),
          ),
        ],
      ),
    );
  }
}

/// Tournament wins: one badge per year. A repeat win doesn't add
/// a badge — the multiplier grows instead, e.g. (2026, 2) means
/// "2x 2026 tournament winner".
class _TournamentTitle {
  final int year;
  final int wins;
  const _TournamentTitle(this.year, this.wins);
}

class _MemoryBadges extends StatelessWidget {
  const _MemoryBadges();

  @override
  Widget build(BuildContext context) {
    // Sample data. TODO: Firebase wiring pending — the real win list comes from here.
    const tournamentTitles = [_TournamentTitle(2026, 4)];
    final badges = [
      (HugeIcons.strokeRoundedFire, coral, '7-day\nstreak'),
      (HugeIcons.strokeRoundedEye, amber, 'Sharp eye'),
      (HugeIcons.strokeRoundedCastle01, teal, 'Palace builder'),
      (HugeIcons.strokeRoundedBrain01, violet, 'Brain gym'),
      (engram.icon, engram.color, 'Engram'),
    ];
    void openTournament(_TournamentTitle t) {
      AppFeedback.light();
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => _BadgeDetailPage(
            title: '${t.year}',
            subtitle: t.wins > 1
                ? '${t.wins}x tournament winner'
                : 'tournament winner',
            medal: _TournamentMedal(
              year: t.year,
              wins: t.wins,
              showLabel: false,
            ),
          ),
        ),
      );
    }

    void openSkill((List<List<dynamic>>, Color, String) b) {
      AppFeedback.light();
      final label = b.$3.replaceAll('\n', ' ');
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => _BadgeDetailPage(
            title: label,
            subtitle: 'skill badge',
            medal: _SkillMedal(
              icon: b.$1,
              tint: b.$2,
              label: b.$3,
              showLabel: false,
            ),
          ),
        ),
      );
    }

    void openAll() {
      AppFeedback.light();
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => _AllBadgesPage(
            tournamentTitles: tournamentTitles,
            badges: badges,
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: context.hairline, width: 2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Badges',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurface,
                    fontWeight: FontWeight.w900,
                    fontSize: 15,
                  ),
                ),
              ),
              GestureDetector(
                onTap: openAll,
                behavior: HitTestBehavior.opaque,
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                  child: Text(
                    'see all',
                    style: TextStyle(
                      color: context.mutedText,
                      fontWeight: FontWeight.w800,
                      fontSize: 13,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          SizedBox(
            height: 156,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              physics: const ClampingScrollPhysics(),
              itemCount: tournamentTitles.length + badges.length,
              separatorBuilder: (_, _) => const SizedBox(width: 12),
              itemBuilder: (_, i) {
                if (i < tournamentTitles.length) {
                  final t = tournamentTitles[i];
                  return GestureDetector(
                    onTap: () => openTournament(t),
                    child: _TournamentMedal(year: t.year, wins: t.wins),
                  );
                }
                final b = badges[i - tournamentTitles.length];
                return GestureDetector(
                  onTap: () => openSkill(b),
                  child: _SkillMedal(icon: b.$1, tint: b.$2, label: b.$3),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

/// Full grid of every badge. Tapping one opens the large centered detail.
class _AllBadgesPage extends StatelessWidget {
  final List<_TournamentTitle> tournamentTitles;
  final List<(List<List<dynamic>>, Color, String)> badges;
  const _AllBadgesPage({required this.tournamentTitles, required this.badges});

  void _open(
    BuildContext context,
    Widget medal,
    String title,
    String subtitle,
  ) {
    AppFeedback.light();
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) =>
            _BadgeDetailPage(title: title, subtitle: subtitle, medal: medal),
      ),
    );
  }

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
          'Badges',
          style: TextStyle(
            color: Theme.of(context).colorScheme.onSurface,
            fontWeight: FontWeight.w900,
            fontSize: 20,
          ),
        ),
      ),
      body: GridView.builder(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3,
          mainAxisSpacing: 14,
          crossAxisSpacing: 14,
          mainAxisExtent: 168,
        ),
        itemCount: tournamentTitles.length + badges.length,
        itemBuilder: (_, i) {
          if (i < tournamentTitles.length) {
            final t = tournamentTitles[i];
            return GestureDetector(
              onTap: () => _open(
                context,
                _TournamentMedal(year: t.year, wins: t.wins, showLabel: false),
                '${t.year}',
                t.wins > 1
                    ? '${t.wins}x tournament winner'
                    : 'tournament winner',
              ),
              child: Container(
                decoration: BoxDecoration(
                  color: context.cardBg,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: context.hairline, width: 2),
                ),
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: _TournamentMedal(year: t.year, wins: t.wins),
                ),
              ),
            );
          }
          final b = badges[i - tournamentTitles.length];
          final label = b.$3.replaceAll('\n', ' ');
          return GestureDetector(
            onTap: () => _open(
              context,
              _SkillMedal(
                icon: b.$1,
                tint: b.$2,
                label: b.$3,
                showLabel: false,
              ),
              label,
              'skill badge',
            ),
            child: Container(
              decoration: BoxDecoration(
                color: context.cardBg,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: context.hairline, width: 2),
              ),
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: _SkillMedal(icon: b.$1, tint: b.$2, label: b.$3),
              ),
            ),
          );
        },
      ),
    );
  }
}

/// Large centered badge view. Static, no rotation, no hologram,
/// no description — just the medal with its title, centered on screen.
class _BadgeDetailPage extends StatelessWidget {
  final Widget medal;
  final String title;
  final String subtitle;
  const _BadgeDetailPage({
    required this.medal,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: const EngramBackButton(),
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              SizedBox(
                width: 280,
                height: 280,
                child: FittedBox(fit: BoxFit.contain, child: medal),
              ),
              const SizedBox(height: 20),
              Text(
                title,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurface,
                  fontWeight: FontWeight.w900,
                  fontSize: 28,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 6),
              Text(
                subtitle,
                style: TextStyle(
                  color: context.mutedText,
                  fontWeight: FontWeight.w800,
                  fontSize: 15,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Real, medallion-style tournament badge. Static: every tournament
/// badge looks exactly the same, no tilt, no hologram, no rotation.
class _TournamentMedal extends StatelessWidget {
  final int year;
  final int wins;
  final bool showLabel;
  const _TournamentMedal({
    required this.year,
    required this.wins,
    this.showLabel = true,
  });

  @override
  Widget build(BuildContext context) {
    final disc = _TournamentDisc(year: year, wins: wins);
    if (!showLabel) return disc;
    return SizedBox(
      width: 104,
      child: Column(
        children: [
          disc,
          const SizedBox(height: 6),
          Text(
            '$year',
            style: TextStyle(
              color: context.inkText,
              fontWeight: FontWeight.w900,
              fontSize: 13,
            ),
          ),
          Text(
            'tournament winner',
            style: TextStyle(color: context.mutedText, fontSize: 10),
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

/// Static tournament disc. One gold finish for every year —
/// no hologram, no tilt, no moving layers.
class _TournamentDisc extends StatelessWidget {
  final int year;
  final int wins;
  const _TournamentDisc({required this.year, required this.wins});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 92,
      height: 92,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Container(
            width: 88,
            height: 88,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: const LinearGradient(
                begin: Alignment(-0.7, -0.7),
                end: Alignment(0.7, 0.7),
                colors: [
                  Color(0xFFFFF6D8),
                  Color(0xFFFFC400),
                  Color(0xFFB8860B),
                  Color(0xFFFFE27A),
                ],
                stops: [0.0, 0.45, 0.75, 1.0],
              ),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFFB8860B).withValues(alpha: 0.35),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
          ),
          Container(
            width: 66,
            height: 66,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: const Color(0xFFFFFBEB),
              border: Border.all(
                color: const Color(0xFFB8860B).withValues(alpha: 0.5),
                width: 1.5,
              ),
            ),
            alignment: Alignment.center,
            child: const HugeIcon(
              icon: HugeIcons.strokeRoundedTrophy,
              color: Color(0xFFB8860B),
              size: 30,
              strokeWidth: 2,
            ),
          ),
          if (wins > 1)
            Positioned(
              top: 0,
              right: 0,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                decoration: BoxDecoration(
                  color: ink,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.white, width: 1.5),
                ),
                child: Text(
                  '${wins}x',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                    fontSize: 11,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Medallion-style skill badge with a metallic tinted ring. Static,
/// no gyroscope, no moving light.
class _SkillMedal extends StatelessWidget {
  final List<List<dynamic>> icon;
  final Color tint;
  final String label;
  final bool showLabel;
  const _SkillMedal({
    required this.icon,
    required this.tint,
    required this.label,
    this.showLabel = true,
  });

  @override
  Widget build(BuildContext context) {
    final disc = SizedBox(
      width: 84,
      height: 84,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  context.cardBg,
                  tint.withValues(alpha: 0.35),
                  tint,
                  tint.withValues(alpha: 0.55),
                ],
                stops: const [0.0, 0.45, 0.78, 1.0],
              ),
              boxShadow: [
                BoxShadow(
                  color: tint.withValues(alpha: 0.3),
                  blurRadius: 8,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
          ),
          Container(
            width: 58,
            height: 58,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: context.cardBg,
            ),
            alignment: Alignment.center,
            child: HugeIcon(icon: icon, color: tint, size: 28, strokeWidth: 2),
          ),
        ],
      ),
    );
    if (!showLabel) return disc;
    return SizedBox(
      width: 88,
      child: Column(
        children: [
          disc,
          const SizedBox(height: 6),
          Text(
            label.replaceAll('\n', ' '),
            style: TextStyle(
              color: context.inkText,
              fontSize: 10,
              fontWeight: FontWeight.w700,
            ),
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}
