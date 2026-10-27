import '../theme/app_theme.dart';

import 'dart:async';

import 'package:flutter/material.dart';

import '../services/app_feedback.dart';

import 'package:hugeicons/hugeicons.dart';

import '../widgets/app_buttons.dart';
import '../models/battle_invites.dart';
import '../models/battle_rating.dart';
import '../models/collectibles.dart' show engram;
import 'friend_profile.dart';
import 'memory_profile.dart' show ink, violet, teal, amber, memoryKinds;
import '../services/memory_store.dart';

enum BattleMode { duel, team }

/// Memóriaszint egyetlen típus 0–100-as pontszámából.
/// A profil `memoryLevel` képletével egyezik (`~/ 10 + 1`),
/// csak átlag helyett egy típus pontszámából számol.
int memoryLevelForScore(int score) => (score ~/ 10) + 1;

class BattleZonePage extends StatelessWidget {
  const BattleZonePage({super.key});

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
          'Battle Zone',
          style: TextStyle(
            color: Theme.of(context).colorScheme.onSurface,
            fontWeight: FontWeight.bold,
            fontSize: 20,
          ),
        ),
        centerTitle: true,
      ),
      body: const BattleZoneView(),
    );
  }
}

class BattleZoneView extends StatefulWidget {
  const BattleZoneView({super.key});

  @override
  State<BattleZoneView> createState() => _BattleZoneViewState();
}

class _BattleZoneViewState extends State<BattleZoneView> {
  BattleMode _mode = BattleMode.duel;
  int _kind = 0;
  int _rating = BattleRating.startingRating;
  List<int>? _scores;
  bool _searching = false;
  bool _found = false;
  int _elapsed = 0;
  Timer? _timer;
  final _friendSearch = TextEditingController();
  String _friendQuery = '';

  static const _pastMatches = [
    _PastMatch(
      opponent: 'Nóra',
      duel: true,
      kind: 1,
      playerScore: 86,
      foeScore: 79,
      rounds: ['Digit span 12/14', 'Recall sprint 9/10', 'Reverse span 7/10'],
      delta: 18,
      date: 'Yesterday, 19:42',
    ),
    _PastMatch(
      opponent: 'Marci',
      duel: true,
      kind: 3,
      playerScore: 71,
      foeScore: 84,
      rounds: ['Image pairs 8/12', 'Spot the change 6/10', 'Scene recall 7/10'],
      delta: -11,
      date: 'Oct 23, 20:15',
    ),
    _PastMatch(
      opponent: 'Léna + Gergő',
      duel: false,
      kind: 2,
      playerScore: 92,
      foeScore: 88,
      rounds: ['Palace route 11/12', 'Loci relay 10/12', 'Map recall 9/10'],
      delta: 22,
      date: 'Oct 21, 18:03',
    ),
    _PastMatch(
      opponent: 'Dávid',
      duel: true,
      kind: 4,
      playerScore: 77,
      foeScore: 77,
      rounds: ['Story chain 9/12', 'Journal cues 8/10', 'Walkback 7/10'],
      delta: 2,
      date: 'Oct 19, 21:27',
    ),
  ];

  @override
  void initState() {
    super.initState();
    MemoryStore.resolveBattleKind(memoryKinds.length).then((kind) {
      if (!mounted) return;
      setState(() => _kind = kind);
    });
    MemoryStore.loadBattleRating(defaultRating: BattleRating.startingRating)
        .then((rating) {
          if (!mounted) return;
          setState(() => _rating = rating);
        });
    MemoryStore.loadScores().then((scores) {
      if (!mounted) return;
      setState(() => _scores = scores);
    });
  }

  /// Memóriaszint az adott típusban, mérés nélkül null.
  int? _levelForKind(int i) {
    final s = _scores;
    if (s == null || i < 0 || i >= s.length) return null;
    return memoryLevelForScore(s[i]);
  }

  void _pickKind(int kind) {
    if (_searching) return;
    setState(() => _kind = kind);
    unawaited(MemoryStore.saveBattleKind(kind));
  }

  @override
  void dispose() {
    _timer?.cancel();
    _friendSearch.dispose();
    super.dispose();
  }

  void _startSearch() {
    AppFeedback.medium();
    setState(() {
      _searching = true;
      _found = false;
      _elapsed = 0;
    });
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) return;
      setState(() => _elapsed++);
      if (_elapsed >= 4) {
        t.cancel();
        if (!mounted) return;
        AppFeedback.heavy();
        setState(() => _found = true);
      }
    });
  }

  void _cancelSearch() {
    AppFeedback.light();
    _timer?.cancel();
    setState(() {
      _searching = false;
      _found = false;
      _elapsed = 0;
    });
  }

  String get _elapsedLabel {
    final m = _elapsed ~/ 60;
    final s = (_elapsed % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
          top: false,
          bottom: false,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 120),
            children: [
              const SizedBox(height: 20),
              _ratingHero(),
              const SizedBox(height: 16),
              _modeCards(),
              const SizedBox(height: 16),
              _gameModeSection(),
              const SizedBox(height: 12),
              _matchCard(),
              const SizedBox(height: 12),
              _friendBattleCard(),
              const SizedBox(height: 12),
              _statsRow(),
              const SizedBox(height: 20),
              _sectionTitle(
                'Previous matches',
                'Tap a match to see every round',
              ),
              const SizedBox(height: 10),
              for (var i = 0; i < _pastMatches.length; i++) ...[
                _PastMatchRow(
                  match: _pastMatches[i],
                  onTap: () => _showMatchDetail(_pastMatches[i]),
                ),
                if (i < _pastMatches.length - 1) const SizedBox(height: 8),
              ],
              const SizedBox(height: 20),
              _sectionTitle('Live duels', 'Watch and learn from the best'),
              const SizedBox(height: 10),
              const _LiveBattleRow(
                mode: '1v1',
                title: 'Zsófi vs Marci',
                task: 'Digit-span duel · round 2',
                viewers: 86,
              ),
              const SizedBox(height: 8),
              const _LiveBattleRow(
                mode: '2v2',
                title: 'Nóra + Levi vs Dávid + Petra',
                task: 'Image-pair relay · final round',
                viewers: 132,
              ),
              const SizedBox(height: 8),
              const _LiveBattleRow(
                mode: '1v1',
                title: 'Léna vs Gergő',
                task: 'Loci sprint · round 1',
                viewers: 41,
              ),
              const SizedBox(height: 20),
              _sectionTitle(
                'How it works',
                'Three steps, measured every round',
              ),
              const SizedBox(height: 10),
              _StepRow(
                index: '01',
                title: 'Matched opponents',
                body:
                    'Matchmaking looks within ±${BattleRating.matchWindow} points. In squads, the two players\' average counts.',
              ),
              const SizedBox(height: 8),
              const _StepRow(
                index: '02',
                title: 'Three short tasks',
                body: 'Digit span, image pairs, loci excerpt. Both sides get the same tasks at the same time, on the clock.',
              ),
              const SizedBox(height: 8),
              const _StepRow(
                index: '03',
                title: 'Winner takes points',
                body: 'Win and your score goes up, lose and it goes down — never below 0. Draws split the difference.',
              ),
              const SizedBox(height: 12),
              _fairPlayCard(),
            ],
          ),
        );
  }

  Widget _ratingHero() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF45A3FF), Color(0xFF1F6FC4)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: const [
          BoxShadow(color: Color(0xFF1F6FC4), offset: Offset(0, 4)),
        ],
      ),
      child: Column(
        children: [
          const Text(
            'BATTLE SCORE',
            style: TextStyle(
              color: Colors.white70,
              fontWeight: FontWeight.w800,
              fontSize: 12,
              letterSpacing: 2,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '$_rating',
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w900,
              fontSize: 56,
              height: 1.1,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: Color(0xFF4ADE80),
                ),
              ),
              const SizedBox(width: 6),
              const Text(
                '1,284 online',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _modeCards() {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: _ModeCard(
              selected: _mode == BattleMode.duel,
              icon: engram.icon,
              tint: violet,
              title: '1v1 Duel',
              body: 'You against one opponent with a similar score.',
              onTap: () {
                if (_searching) return;
                setState(() => _mode = BattleMode.duel);
              },
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _ModeCard(
              selected: _mode == BattleMode.team,
              icon: HugeIcons.strokeRoundedUserGroup,
              tint: teal,
              title: '2v2 Squad',
              body: 'Two-player squads, alternating tasks.',
              onTap: () {
                if (_searching) return;
                setState(() => _mode = BattleMode.team);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _gameModeSection() {
    final kind = memoryKinds[_kind];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionTitle('Game mode', 'The memory type you battle in'),
        const SizedBox(height: 10),
        GestureDetector(
          onTap: _searching ? null : _openKindPicker,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: context.cardBg,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: context.hairline, width: 2),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(7),
                  decoration: BoxDecoration(
                    color: kind.tint.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: HugeIcon(
                    icon: kind.icon,
                    color: kind.tint,
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
                        kind.name,
                        style: TextStyle(
                          color: context.inkText,
                          fontWeight: FontWeight.w800,
                          fontSize: 14,
                        ),
                      ),
                      Text(
                        () {
                          final level = _levelForKind(_kind);
                          return level == null
                              ? 'Not tested yet'
                              : 'Memory level $level';
                        }(),
                        style: TextStyle(
                          color: context.mutedText,
                          fontSize: 11,
                        ),
                      ),
                    ],
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
      ],
    );
  }

  void _openKindPicker() {
    showModalBottomSheet<void>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: context.hairline,
                    borderRadius: BorderRadius.circular(99),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Game mode',
                style: TextStyle(
                  color: Theme.of(sheetContext).colorScheme.onSurface,
                  fontWeight: FontWeight.w900,
                  fontSize: 17,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                'Pick the memory type you battle in',
                style: TextStyle(color: context.mutedText, fontSize: 12),
              ),
              const SizedBox(height: 12),
              Flexible(
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: memoryKinds.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 8),
                  itemBuilder: (_, i) {
                    final option = memoryKinds[i];
                    final selected = i == _kind;
                    return GestureDetector(
                      onTap: () {
                        Navigator.of(sheetContext).pop();
                        _pickKind(i);
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          color: selected
                              ? option.tint.withValues(alpha: 0.14)
                              : context.cardBg,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: selected ? option.tint : context.hairline,
                            width: selected ? 2.5 : 2,
                          ),
                        ),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(7),
                              decoration: BoxDecoration(
                                color: option.tint.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: HugeIcon(
                                icon: option.icon,
                                color: option.tint,
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
                                    option.name,
                                    style: TextStyle(
                                      color: context.inkText,
                                      fontWeight: FontWeight.w800,
                                      fontSize: 14,
                                    ),
                                  ),
                                  Text(
                                    option.module,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      color: context.mutedText,
                                      fontSize: 11,
                                    ),
                                  ),
                                  Builder(
                                    builder: (_) {
                                      final level = _levelForKind(i);
                                      return Text(
                                        level == null
                                            ? 'Not tested yet'
                                            : 'Memory level $level',
                                        style: TextStyle(
                                          color: level == null
                                              ? context.mutedText
                                              : option.tint,
                                          fontWeight: FontWeight.w700,
                                          fontSize: 11,
                                        ),
                                      );
                                    },
                                  ),
                                ],
                              ),
                            ),
                            if (selected)
                              HugeIcon(
                                icon: HugeIcons.strokeRoundedCheckmarkCircle02,
                                color: option.tint,
                                size: 22,
                                strokeWidth: 2,
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
      ),
    );
  }

  Widget _matchCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.cardBg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: context.hairline, width: 2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(9),
                decoration: BoxDecoration(
                  color: memoryKinds[_kind].tint.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: HugeIcon(
                  icon: memoryKinds[_kind].icon,
                  color: memoryKinds[_kind].tint,
                  size: 22,
                  strokeWidth: 2,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _mode == BattleMode.duel
                          ? '1v1 · ${memoryKinds[_kind].name}'
                          : '2v2 · ${memoryKinds[_kind].name}',
                      style: TextStyle(
                        color: context.inkText,
                        fontWeight: FontWeight.w900,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Matches within ±${BattleRating.matchWindow} points',
                      style: TextStyle(color: context.mutedText, fontSize: 12),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (!_searching) _searchButton(),
          if (_searching && !_found) _searchingState(),
          if (_searching && _found) _foundState(),
        ],
      ),
    );
  }

  Widget _friendBattleCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.cardBg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: context.hairline, width: 2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              HugeIcon(
                icon: HugeIcons.strokeRoundedUserGroup,
                color: violet,
                size: 22,
                strokeWidth: 2,
              ),
              SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Battle with friends',
                      style: TextStyle(
                        color: context.inkText,
                        fontWeight: FontWeight.w900,
                        fontSize: 16,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'Search a friend and send a 1v1 invite',
                      style: TextStyle(color: context.mutedText, fontSize: 12),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _friendSearch,
            onChanged: (v) => setState(() => _friendQuery = v),
            textInputAction: TextInputAction.search,
            decoration: InputDecoration(
              hintText: 'Search friends by name…',
              hintStyle: TextStyle(color: context.mutedText, fontSize: 13),
              prefixIconConstraints: const BoxConstraints(
                minWidth: 44,
                minHeight: 44,
              ),
              prefixIcon: Padding(
                padding: const EdgeInsets.all(12),
                child: HugeIcon(
                  icon: HugeIcons.strokeRoundedSearch01,
                  color: context.mutedText,
                  size: 20,
                  strokeWidth: 2,
                ),
              ),
              suffixIconConstraints: const BoxConstraints(
                minWidth: 44,
                minHeight: 44,
              ),
              suffixIcon: _friendQuery.isEmpty
                  ? null
                  : GestureDetector(
                      onTap: () {
                        AppFeedback.light();
                        _friendSearch.clear();
                        setState(() => _friendQuery = '');
                      },
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: HugeIcon(
                          icon: HugeIcons.strokeRoundedCancel01,
                          color: context.mutedText,
                          size: 20,
                          strokeWidth: 2,
                        ),
                      ),
                    ),
              filled: true,
              fillColor: context.softBg,
              contentPadding: const EdgeInsets.symmetric(vertical: 12),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(color: context.hairline, width: 2),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(color: context.hairline, width: 2),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(color: violet, width: 2),
              ),
            ),
          ),
          const SizedBox(height: 8),
          ListenableBuilder(
            listenable: battleInvites,
            builder: (context, _) {
              final results = filterBattleFriends(_friendQuery);
              if (results.isEmpty) {
                return Padding(
                  padding: EdgeInsets.symmetric(vertical: 12),
                  child: Text(
                    'No friend matches that name yet.',
                    style: TextStyle(color: context.mutedText, fontSize: 13),
                  ),
                );
              }
              return Column(
                children: [
                  for (var i = 0; i < results.length; i++) ...[
                    _FriendInviteRow(
                      friend: results[i],
                      onOpenProfile: () {
                        AppFeedback.light();
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) =>
                                FriendProfilePage(friend: results[i]),
                          ),
                        );
                      },
                    ),
                    if (i < results.length - 1) const SizedBox(height: 8),
                  ],
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _searchButton() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: _startSearch,
        style: ElevatedButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 14),
        ),
        child: Text(
          _mode == BattleMode.duel ? 'FIND OPPONENT' : 'FIND SQUAD + OPPONENTS',
        ),
      ),
    );
  }

  Widget _searchingState() {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(99),
                child: LinearProgressIndicator(
                  minHeight: 8,
                  backgroundColor: context.hairline,
                  valueColor: AlwaysStoppedAnimation<Color>(violet),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Text(
              'Searching… $_elapsedLabel',
              style: TextStyle(
                color: context.inkText,
                fontWeight: FontWeight.w800,
                fontSize: 13,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton(
            onPressed: _cancelSearch,
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 12),
            ),
            child: const Text('CANCEL'),
          ),
        ),
      ],
    );
  }

  Widget _foundState() {
    final foe = _mode == BattleMode.duel
        ? 'Nóra (1,512)'
        : 'Nóra + Levi (1,505)';
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: context.washBg,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: violet.withValues(alpha: 0.4)),
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  'You ($_rating)',
                  textAlign: TextAlign.right,
                  style: TextStyle(
                    color: context.inkText,
                    fontWeight: FontWeight.w900,
                    fontSize: 13,
                  ),
                ),
              ),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 10),
                child: Text(
                  'VS',
                  style: TextStyle(
                    color: violet,
                    fontWeight: FontWeight.w900,
                    fontSize: 13,
                  ),
                ),
              ),
              Expanded(
                child: Text(
                  foe,
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
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: _cancelSearch,
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
                child: const Text('WITHDRAW'),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: ElevatedButton(
                onPressed: () {
                  AppFeedback.heavy();
                },
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
                child: const Text('ENTER'),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _statsRow() {
    return const Row(
      children: [
        Expanded(
          child: _StatCard(value: '34', label: 'Matches'),
        ),
        SizedBox(width: 10),
        Expanded(
          child: _StatCard(value: '62%', label: 'Win rate'),
        ),
        SizedBox(width: 10),
        Expanded(
          child: _StatCard(value: '9', label: 'Best streak'),
        ),
      ],
    );
  }

  void _showMatchDetail(_PastMatch match) {
    AppFeedback.light();
    final won = match.playerScore > match.foeScore;
    final drawn = match.playerScore == match.foeScore;
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          'You vs ${match.opponent}',
          style: TextStyle(
            color: context.inkText,
            fontWeight: FontWeight.w900,
            fontSize: 17,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${match.duel ? '1v1' : '2v2'} · ${memoryKinds[match.kind].name} · ${match.date}',
              style: TextStyle(color: context.mutedText, fontSize: 12),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: context.hairline.withValues(alpha: 0.4),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    '${match.playerScore}',
                    style: TextStyle(
                      color: context.inkText,
                      fontWeight: FontWeight.w900,
                      fontSize: 26,
                    ),
                  ),
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: 8),
                    child: Text(
                      ':',
                      style: TextStyle(
                        color: context.mutedText,
                        fontWeight: FontWeight.w900,
                        fontSize: 22,
                      ),
                    ),
                  ),
                  Text(
                    '${match.foeScore}',
                    style: TextStyle(
                      color: context.inkText,
                      fontWeight: FontWeight.w900,
                      fontSize: 26,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            for (var i = 0; i < match.rounds.length; i++)
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  children: [
                    Text(
                      'R${i + 1}',
                      style: TextStyle(
                        color: context.mutedText,
                        fontWeight: FontWeight.w800,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        match.rounds[i],
                        style: TextStyle(color: context.inkText, fontSize: 13),
                      ),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 4),
            Text(
              won
                  ? 'Won · +${match.delta} points'
                  : drawn
                  ? 'Draw · +${match.delta} points'
                  : 'Lost · ${match.delta} points',
              style: TextStyle(
                color: won
                    ? const Color(0xFF16A34A)
                    : drawn
                    ? context.mutedText
                    : const Color(0xFFDC2626),
                fontWeight: FontWeight.w800,
                fontSize: 13,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              AppFeedback.light();
              Navigator.of(context).pop();
            },
            child: const Text('CLOSE'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              if (_searching) return;
              setState(() {
                _mode = match.duel ? BattleMode.duel : BattleMode.team;
                _kind = match.kind;
              });
              unawaited(MemoryStore.saveBattleKind(match.kind));
              _startSearch();
            },
            child: const Text('REMATCH'),
          ),
        ],
      ),
    );
  }

  Widget _sectionTitle(String title, String subtitle) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
            color: Theme.of(context).colorScheme.onSurface,
            fontWeight: FontWeight.w900,
            fontSize: 17,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          subtitle,
          style: TextStyle(color: context.mutedText, fontSize: 12),
        ),
      ],
    );
  }

  Widget _fairPlayCard() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: teal.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: teal.withValues(alpha: 0.35), width: 2),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          HugeIcon(
            icon: HugeIcons.strokeRoundedShield01,
            color: teal,
            size: 24,
            strokeWidth: 2,
          ),
          SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Protected against farming',
                  style: TextStyle(
                    color: context.inkText,
                    fontWeight: FontWeight.w900,
                    fontSize: 14,
                  ),
                ),
                SizedBox(height: 3),
                Text(
                  'Score only moves in duels. The practice ground gives XP, not score — grinding easy tasks won\'t move you up here.',
                  style: TextStyle(
                    color: context.mutedText,
                    fontSize: 12,
                    height: 1.45,
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

class _ModeCard extends StatelessWidget {
  final bool selected;
  final List<List<dynamic>> icon;
  final Color tint;
  final String title;
  final String body;
  final VoidCallback onTap;

  const _ModeCard({
    required this.selected,
    required this.icon,
    required this.tint,
    required this.title,
    required this.body,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: selected ? tint.withValues(alpha: 0.12) : context.cardBg,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected ? tint : context.hairline,
            width: selected ? 2.5 : 2,
          ),
          boxShadow: selected
              ? [BoxShadow(color: tint.withValues(alpha: 0.25), blurRadius: 14)]
              : null,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(9),
              decoration: BoxDecoration(
                color: tint.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(14),
              ),
              child: HugeIcon(
                icon: icon,
                color: tint,
                size: 24,
                strokeWidth: 2,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              title,
              style: TextStyle(
                color: context.inkText,
                fontWeight: FontWeight.w900,
                fontSize: 15,
              ),
            ),
            const SizedBox(height: 3),
            Text(
              body,
              style: TextStyle(
                color: context.mutedText,
                fontSize: 11,
                height: 1.4,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String value;
  final String label;
  const _StatCard({required this.value, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        color: context.cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: context.hairline, width: 2),
      ),
      child: Column(
        children: [
          Text(
            value,
            style: TextStyle(
              color: context.inkText,
              fontWeight: FontWeight.w900,
              fontSize: 18,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(color: context.mutedText, fontSize: 10),
          ),
        ],
      ),
    );
  }
}

class _LiveBattleRow extends StatelessWidget {
  final String mode;
  final String title;
  final String task;
  final int viewers;
  const _LiveBattleRow({
    required this.mode,
    required this.title,
    required this.task,
    required this.viewers,
  });

  @override
  Widget build(BuildContext context) {
    final isDuel = mode == '1v1';
    final badge = isDuel ? violet : teal;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: context.cardBg,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: context.hairline, width: 2),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
            decoration: BoxDecoration(
              color: badge.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              mode,
              style: TextStyle(
                color: badge,
                fontWeight: FontWeight.w900,
                fontSize: 12,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: context.inkText,
                    fontWeight: FontWeight.w800,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        task,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: context.mutedText,
                          fontSize: 11,
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    HugeIcon(
                      icon: HugeIcons.strokeRoundedEye,
                      color: context.mutedText,
                      size: 13,
                      strokeWidth: 2,
                    ),
                    const SizedBox(width: 3),
                    Text(
                      '$viewers',
                      style: TextStyle(color: context.mutedText, fontSize: 11),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          EngramMiniButton(
            label: 'Watch',
            background: ink,
            onTap: () {
              AppFeedback.light();
            },
          ),
        ],
      ),
    );
  }
}

class _StepRow extends StatelessWidget {
  final String index;
  final String title;
  final String body;
  const _StepRow({
    required this.index,
    required this.title,
    required this.body,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: context.cardBg,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: context.hairline, width: 2),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            index,
            style: const TextStyle(
              color: amber,
              fontWeight: FontWeight.w900,
              fontSize: 16,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: context.inkText,
                    fontWeight: FontWeight.w900,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  body,
                  style: TextStyle(
                    color: context.mutedText,
                    fontSize: 12,
                    height: 1.45,
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

class _PastMatch {
  final String opponent;
  final bool duel;
  final int kind;
  final int playerScore;
  final int foeScore;
  final List<String> rounds;
  final int delta;
  final String date;
  const _PastMatch({
    required this.opponent,
    required this.duel,
    required this.kind,
    required this.playerScore,
    required this.foeScore,
    required this.rounds,
    required this.delta,
    required this.date,
  });
}

class _PastMatchRow extends StatelessWidget {
  final _PastMatch match;
  final VoidCallback onTap;
  const _PastMatchRow({required this.match, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final won = match.playerScore > match.foeScore;
    final drawn = match.playerScore == match.foeScore;
    final accent = won
        ? const Color(0xFF16A34A)
        : drawn
        ? context.mutedText
        : const Color(0xFFDC2626);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: context.cardBg,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: context.hairline, width: 2),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
              decoration: BoxDecoration(
                color: accent.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                won
                    ? 'W'
                    : drawn
                    ? 'D'
                    : 'L',
                style: TextStyle(
                  color: accent,
                  fontWeight: FontWeight.w900,
                  fontSize: 13,
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'vs ${match.opponent}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: context.inkText,
                      fontWeight: FontWeight.w800,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${match.duel ? '1v1' : '2v2'} · ${memoryKinds[match.kind].name} · ${match.date}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: context.mutedText, fontSize: 11),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '${match.playerScore}:${match.foeScore}',
                  style: TextStyle(
                    color: context.inkText,
                    fontWeight: FontWeight.w900,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${match.delta > 0 ? '+' : ''}${match.delta}',
                  style: TextStyle(
                    color: accent,
                    fontWeight: FontWeight.w800,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _FriendInviteRow extends StatelessWidget {
  final BattleFriend friend;
  final VoidCallback onOpenProfile;
  const _FriendInviteRow({required this.friend, required this.onOpenProfile});

  void _toggle() {
    if (battleInvites.isInvited(friend.name)) {
      AppFeedback.light();
      battleInvites.withdraw(friend.name);
    } else {
      AppFeedback.medium();
      battleInvites.invite(friend.name);
    }
  }

  @override
  Widget build(BuildContext context) {
    final invited = battleInvites.isInvited(friend.name);
    return GestureDetector(
      onTap: onOpenProfile,
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: invited ? context.washBg : context.softBg,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: invited ? violet.withValues(alpha: 0.5) : context.hairline,
            width: invited ? 2 : 1.5,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: violet.withValues(alpha: 0.14),
              ),
              child: Text(
                friend.name.characters.first,
                style: const TextStyle(
                  color: violet,
                  fontWeight: FontWeight.w900,
                  fontSize: 16,
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
                          friend.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: context.inkText,
                            fontWeight: FontWeight.w800,
                            fontSize: 14,
                          ),
                        ),
                      ),
                      if (friend.online) ...[
                        const SizedBox(width: 6),
                        Container(
                          width: 8,
                          height: 8,
                          decoration: const BoxDecoration(
                            shape: BoxShape.circle,
                            color: Color(0xFF22C55E),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${friend.xp} XP · ${friend.streak}-day streak',
                    style: TextStyle(color: context.mutedText, fontSize: 11),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            EngramMiniButton(
              label: invited ? 'INVITED' : 'INVITE',
              background: invited ? violet : ink,
              onTap: _toggle,
            ),
          ],
        ),
      ),
    );
  }
}
