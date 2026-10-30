import '../theme/app_theme.dart';

import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../services/app_feedback.dart';

import 'package:hugeicons/hugeicons.dart';

import '../widgets/ai_help_button.dart';
import '../widgets/app_buttons.dart';
import '../models/battle_invites.dart';
import '../models/battle_match.dart';
import '../models/battle_rating.dart';
import '../models/battle_round.dart' show battleRequestKindFor;
import '../models/collectibles.dart' show engram;
import '../models/meta_task.dart';
import '../services/bot_arena_store.dart';
import 'battle_duel_page.dart';
import 'brain_league.dart';
import 'friend_profile.dart';
import 'memory_profile.dart'
    show
        ink,
        violet,
        violetDark,
        teal,
        amber,
        memoryKinds,
        MemoryAssessmentIntroPage;
import '../services/memory_store.dart';
import '../services/meta_ai_service.dart';

enum BattleMode { duel, team }

int memoryLevelForScore(int score) => (score.clamp(0, 100) ~/ 10) + 1;

Future<MetaTask> aiDuelTask(int kind, {int difficulty = 2}) {
  return MetaAIService.generateTask(
    MetaTaskRequest(
      kind: battleRequestKindFor(kind),
      difficulty: difficulty,
      locale: AppLocalizations.localeCode,
    ),
  );
}

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
          tr('btz_title'),
          style: TextStyle(
            color: Theme.of(context).colorScheme.onSurface,
            fontWeight: FontWeight.bold,
            fontSize: 20,
          ),
        ),
        centerTitle: true,
        actions: const [
          AiHelpButton(topic: AiHelpTopics.battle),
          SizedBox(width: 12),
        ],
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
  final _friendSearch = TextEditingController();
  String _friendQuery = '';
  BattleStats _arenaStats = const BattleStats();
  List<BattleRecord> _arenaHistory = const [];
  List<LiveDuel> _liveDuels = const [];
  final List<String> _recentOpponents = [];

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
    botArena.addListener(_onArena);
    botArena.ensureLoaded().then((_) {
      if (!mounted) return;
      _onArena();
    });
  }

  void _onArena() {
    MemoryStore.loadBattleRating(defaultRating: BattleRating.startingRating)
        .then((rating) {
          if (!mounted) return;
          setState(() {
            _rating = rating;
            _arenaStats = botArena.stats;
            _arenaHistory = botArena.history;
            _liveDuels = botArena.liveDuels(
              locale: AppLocalizations.localeCode,
            );
          });
        });
  }

  int? _levelForKind(int i) {
    final s = _scores;
    if (s == null || i < 0 || i >= s.length) return null;
    return memoryLevelForScore(s[i]);
  }

  _PastMatch _displayMatch(BattleRecord record) {
    return _PastMatch(
      opponent: record.opponent,
      duel: record.duel,
      kind: record.kind.clamp(0, memoryKinds.length - 1),
      playerScore: record.playerScore,
      foeScore: record.foeScore,
      rounds: record.roundLines.isEmpty
          ? [tr('btz_no_rounds')]
          : record.roundLines,
      delta: record.delta,
      date: battleDateLabelIn(AppLocalizations.localeCode, record.at),
      outcome: record.outcome,
      forfeit: record.forfeit,
    );
  }

  void _pickKind(int kind) {
    setState(() => _kind = kind);
    unawaited(MemoryStore.saveBattleKind(kind));
  }

  void _openPractice() {
    AppFeedback.medium();
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const MemoryAssessmentIntroPage()),
    );
  }

  void _openFriendsTab() {
    AppFeedback.light();
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => const BrainLeaguePage(initialTab: 1),
      ),
    );
  }

  void _rememberOpponent(String id) {
    _recentOpponents.remove(id);
    _recentOpponents.add(id);
    while (_recentOpponents.length > 8) {
      _recentOpponents.removeAt(0);
    }
  }

  void _findMatch() {
    AppFeedback.medium();
    if (_mode == BattleMode.team) {
      final squad = botArena.matchSquad();
      if (squad == null || !mounted) return;
      _rememberOpponent(squad.foe1.id);
      _rememberOpponent(squad.foe2.id);
      Navigator.of(context)
          .push(
            MaterialPageRoute(
              builder: (_) => BattleDuelPage.team(squad: squad, kind: _kind),
            ),
          )
          .then((result) {
            if (result == 'new' && mounted) _findMatch();
          });
      return;
    }
    final opponent = botArena.matchOpponent(
      excludeIds: _recentOpponents.toSet(),
    );
    if (opponent == null || !mounted) return;
    _rememberOpponent(opponent.id);
    Navigator.of(context)
        .push(
          MaterialPageRoute(
            builder: (_) =>
                BattleDuelPage.duel(opponent: opponent, kind: _kind),
          ),
        )
        .then((result) {
          if (result == 'new' && mounted) _findMatch();
        });
  }

  void _duelWithBot(String name) {
    final bot = botArena.botByName(name);
    if (bot == null || !mounted) return;
    AppFeedback.medium();
    _rememberOpponent(bot.id);
    Navigator.of(context)
        .push(
          MaterialPageRoute(
            builder: (_) => BattleDuelPage.duel(opponent: bot, kind: _kind),
          ),
        )
        .then((result) {
          if (result == 'new' && mounted) _findMatch();
        });
  }

  void _watchLive(LiveDuel duel) {
    AppFeedback.light();
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => BattleDuelPage.spectate(
          home: duel.home,
          away: duel.away,
          kind: _kind,
        ),
      ),
    );
  }

  void _onInviteChanged(BattleFriend friend, bool invited) {
    if (!invited) return;
    final bot = botArena.botByName(friend.name);
    if (bot == null || !friend.online) return;
    final delay = Duration(seconds: 3 + Random().nextInt(6));
    Future<void>.delayed(delay).then((_) {
      if (!mounted) return;
      if (!battleInvites.isInvited(friend.name)) return;
      battleInvites.withdraw(friend.name);
      if (!mounted) return;
      showDialog<void>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: Text(
            tr('btz_accepted', {'name': friend.name}),
            style: TextStyle(
              color: dialogContext.inkText,
              fontWeight: FontWeight.w900,
              fontSize: 17,
            ),
          ),
          content: Text(
            tr('btz_accepted_body'),
            style: TextStyle(color: dialogContext.mutedText, fontSize: 13),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: Text(tr('btz_later')),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(dialogContext).pop();
                _duelWithBot(friend.name);
              },
              child: Text(tr('btz_start_duel')),
            ),
          ],
        ),
      );
    });
  }

  @override
  void dispose() {
    botArena.removeListener(_onArena);
    _friendSearch.dispose();
    super.dispose();
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
          _ScoutCard(
            key: ValueKey('scout-$_kind-${_arenaStats.matches}'),
            kindLabel: tr(memoryKinds[_kind.clamp(0, memoryKinds.length - 1)].nameKey),
            rating: _rating,
            wins: _arenaStats.wins,
            matches: _arenaStats.matches,
          ),
          const SizedBox(height: 12),
          _friendBattleCard(),
          const SizedBox(height: 12),
          _statsRow(),
          const SizedBox(height: 20),
          _sectionTitle(
            tr('btz_past'),
            _arenaHistory.isEmpty
                ? tr('btz_past_empty_sub')
                : tr('btz_past_n', {'n': _arenaHistory.length}),
          ),
          const SizedBox(height: 10),
          if (_arenaHistory.isEmpty)
            Text(
              tr('btz_no_battles'),
              style: TextStyle(color: context.mutedText, fontSize: 13),
            ),
          for (var i = 0; i < _arenaHistory.length; i++) ...[
            _PastMatchRow(
              match: _displayMatch(_arenaHistory[i]),
              onTap: () => _showMatchDetail(_displayMatch(_arenaHistory[i])),
            ),
            if (i < _arenaHistory.length - 1) const SizedBox(height: 8),
          ],
          const SizedBox(height: 20),
          _sectionTitle(tr('btz_showcases'), tr('btz_showcases_sub')),
          const SizedBox(height: 10),
          if (_liveDuels.isEmpty)
            Text(
              tr('btz_no_show'),
              style: TextStyle(color: context.mutedText, fontSize: 13),
            ),
          for (var i = 0; i < _liveDuels.length; i++) ...[
            _LiveBattleRow(
              mode: _liveDuels[i].mode,
              title: _liveDuels[i].title,
              task: _liveDuels[i].task,
              onWatch: () => _watchLive(_liveDuels[i]),
            ),
            if (i < _liveDuels.length - 1) const SizedBox(height: 8),
          ],
          const SizedBox(height: 20),
          _sectionTitle(tr('btz_how'), tr('btz_how_sub')),
          const SizedBox(height: 10),
          _StepRow(
            index: '01',
            title: tr('btz_step1_title'),
            body: tr('btz_step1_body', {'w': BattleRating.matchWindow}),
          ),
          const SizedBox(height: 8),
          _StepRow(
            index: '02',
            title: tr('btz_step2_title'),
            body: tr('btz_step2_body'),
          ),
          const SizedBox(height: 8),
          _StepRow(
            index: '03',
            title: tr('btz_step3_title'),
            body: tr('btz_step3_body'),
          ),
          const SizedBox(height: 12),
          _fairPlayCard(),
        ],
      ),
    );
  }

  String _arenaPresenceLabel() {
    final friends = botArena.friendCount;
    final partners = botArena.roster.length;
    if (friends > 0) {
      return tr('btz_presence_friends', {'f': friends, 'p': partners});
    }
    return tr('btz_presence', {'p': partners});
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
          Text(
            tr('btz_score'),
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
          Text(
            _arenaPresenceLabel(),
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w700,
              fontSize: 12,
            ),
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
              title: tr('btz_duel_title'),
              body: tr('btz_duel_body'),
              onTap: () {
                if (_mode == BattleMode.duel) return;
                AppFeedback.light();
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
              title: tr('btz_squad_title'),
              body: tr('btz_squad_body'),
              onTap: () {
                if (_mode == BattleMode.team) return;
                AppFeedback.light();
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
        _sectionTitle(tr('btz_gamemode'), tr('btz_gamemode_sub')),
        const SizedBox(height: 10),
        GestureDetector(
          onTap: _openKindPicker,
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
                        kind.displayName,
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
                              ? tr('btz_not_assessed')
                              : tr('btz_mem_level', {'n': level});
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
                tr('btz_gamemode'),
                style: TextStyle(
                  color: Theme.of(sheetContext).colorScheme.onSurface,
                  fontWeight: FontWeight.w900,
                  fontSize: 17,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                tr('btz_pick_sub'),
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
                                    option.displayName,
                                    style: TextStyle(
                                      color: context.inkText,
                                      fontWeight: FontWeight.w800,
                                      fontSize: 14,
                                    ),
                                  ),
                                  Text(
                                    option.displayModule,
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
                                            ? tr('btz_not_assessed')
                                            : tr('btz_mem_level', {
                                                'n': level,
                                              }),
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
                          ? tr('btz_match_duel', {
                              'name': memoryKinds[_kind].displayName,
                            })
                          : tr('btz_match_squad', {
                              'name': memoryKinds[_kind].displayName,
                            }),
                      style: TextStyle(
                        color: context.inkText,
                        fontWeight: FontWeight.w900,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      tr('btz_matched_within', {
                        'w': BattleRating.matchWindow,
                      }),
                      style: TextStyle(color: context.mutedText, fontSize: 12),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            _mode == BattleMode.duel
                ? tr('btz_match_duel_body')
                : tr('btz_match_squad_body'),
            style: TextStyle(color: context.mutedText, fontSize: 13),
          ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: teal.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: teal.withValues(alpha: 0.35)),
            ),
            child: Row(
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    color: teal,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    tr('btz_range', {
                      'lo': _rating - BattleRating.matchWindow,
                      'hi': _rating + BattleRating.matchWindow,
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
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _findMatch,
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              child: Text(tr('btz_find')),
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: _openPractice,
              child: Text(tr('btz_practice')),
            ),
          ),
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
                      tr('btz_friends_title'),
                      style: TextStyle(
                        color: context.inkText,
                        fontWeight: FontWeight.w900,
                        fontSize: 16,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      tr('btz_friends_sub'),
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
              hintText: tr('btz_search_hint'),
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
              return ListenableBuilder(
                listenable: botArena,
                builder: (context, _) {
                  final results = filterBattleFriends(
                    _friendQuery,
                    botArena.friendsDirectory(),
                  );
                  if (results.isEmpty) {
                    if (_friendQuery.isNotEmpty) {
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        child: Text(
                          tr('btz_no_friend', {'q': _friendQuery}),
                          style: TextStyle(
                            color: context.mutedText,
                            fontSize: 13,
                          ),
                        ),
                      );
                    }
                    if (botArena.roster.isEmpty) {
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        child: Text(
                          tr('btz_loading'),
                          style: TextStyle(
                            color: context.mutedText,
                            fontSize: 13,
                          ),
                        ),
                      );
                    }
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            tr('btz_no_friends'),
                            style: TextStyle(
                              color: context.mutedText,
                              fontSize: 13,
                            ),
                          ),
                          const SizedBox(height: 10),
                          SizedBox(
                            width: double.infinity,
                            child: OutlinedButton(
                              onPressed: _openFriendsTab,
                              child: Text(tr('btz_find_friends')),
                            ),
                          ),
                        ],
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
                            final bot = botArena.botByName(results[i].name);
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => FriendProfilePage(
                                  friend: results[i],
                                  botId: bot?.id,
                                ),
                              ),
                            );
                          },
                          onInviteChanged: _onInviteChanged,
                        ),
                        if (i < results.length - 1) const SizedBox(height: 8),
                      ],
                    ],
                  );
                },
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _statsRow() {
    return Row(
      children: [
        Expanded(
          child: _StatCard(
            value: '${_arenaStats.matches}',
            label: tr('btz_matches'),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _StatCard(
            value: _arenaStats.winRateLabel,
            label: tr('btz_winrate'),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _StatCard(
            value: _arenaStats.bestStreakLabel,
            label: tr('btz_streak'),
          ),
        ),
      ],
    );
  }

  void _showMatchDetail(_PastMatch match) {
    AppFeedback.light();
    final won = match.outcome == BattleOutcome.win;
    final drawn = match.outcome == BattleOutcome.draw;
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          tr('btz_you_vs', {'name': match.opponent}),
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
              tr('btz_meta', {
                'mode': match.duel ? '1v1' : '2v2',
                'name': memoryKinds[match.kind].displayName,
                'date': match.date,
              }),
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
                      tr('btl_round', {'round': '${i + 1}'}),
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
              match.forfeit
                  ? tr('btz_forfeit', {'d': match.delta})
                  : won
                  ? tr('btz_win', {'d': match.delta})
                  : drawn
                  ? tr('btz_draw', {'d': match.delta})
                  : tr('btz_loss', {'d': match.delta}),
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
            child: Text(tr('btz_close')),
          ),
          if (match.duel && botArena.botByName(match.opponent) != null)
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop();
                setState(() {
                  _mode = BattleMode.duel;
                  _kind = match.kind;
                });
                unawaited(MemoryStore.saveBattleKind(match.kind));
                _duelWithBot(match.opponent);
              },
              child: Text(tr('btz_rematch')),
            ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              setState(() {
                _mode = match.duel ? BattleMode.duel : BattleMode.team;
                _kind = match.kind;
              });
              unawaited(MemoryStore.saveBattleKind(match.kind));
              _openPractice();
            },
            child: Text(tr('btz_practice_btn')),
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
                  tr('btz_fair_title'),
                  style: TextStyle(
                    color: context.inkText,
                    fontWeight: FontWeight.w900,
                    fontSize: 14,
                  ),
                ),
                SizedBox(height: 3),
                Text(
                  tr('btz_fair_body'),
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

/// AI scout briefing for the queued duel: one technique cue for the chosen
/// memory kind plus a nudge from the player's arena record. Renders nothing
/// until the text arrives, so slow networks never shift the lobby layout.
class _ScoutCard extends StatefulWidget {
  final String kindLabel;
  final int rating;
  final int wins;
  final int matches;
  const _ScoutCard({
    super.key,
    required this.kindLabel,
    required this.rating,
    required this.wins,
    required this.matches,
  });

  @override
  State<_ScoutCard> createState() => _ScoutCardState();
}

class _ScoutCardState extends State<_ScoutCard> {
  late final Future<CoachAnswer> _future = MetaAIService.duelScout(
    kindLabel: widget.kindLabel,
    rating: widget.rating,
    wins: widget.wins,
    matches: widget.matches,
    locale: AppLocalizations.localeCode,
  );

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<CoachAnswer>(
      future: _future,
      builder: (context, snap) {
        final text = snap.data?.text ?? '';
        if (text.isEmpty) return const SizedBox.shrink();
        return Container(
          width: double.infinity,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: context.cardBg,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: context.hairline, width: 2),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 34,
                height: 34,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: violet.withValues(alpha: 0.14),
                ),
                child: const HugeIcon(
                  icon: HugeIcons.strokeRoundedTelescope02,
                  color: violetDark,
                  size: 18,
                  strokeWidth: 2.2,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      tr('duel_scout_title'),
                      style: TextStyle(
                        color: context.mutedText,
                        fontWeight: FontWeight.w900,
                        fontSize: 11,
                        letterSpacing: 1.2,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      text,
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
        );
      },
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
            Row(
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
                const Spacer(),
                if (selected)
                  HugeIcon(
                    icon: HugeIcons.strokeRoundedCheckmarkCircle02,
                    color: tint,
                    size: 22,
                    strokeWidth: 2.2,
                  ),
              ],
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
  final VoidCallback onWatch;
  const _LiveBattleRow({
    required this.mode,
    required this.title,
    required this.task,
    required this.onWatch,
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
                Text(
                  task,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: context.mutedText,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          EngramMiniButton(
            label: tr('btz_watch'),
            background: ink,
            onTap: onWatch,
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
  final BattleOutcome outcome;
  final bool forfeit;
  const _PastMatch({
    required this.opponent,
    required this.duel,
    required this.kind,
    required this.playerScore,
    required this.foeScore,
    required this.rounds,
    required this.delta,
    required this.date,
    required this.outcome,
    this.forfeit = false,
  });
}

class _PastMatchRow extends StatelessWidget {
  final _PastMatch match;
  final VoidCallback onTap;
  const _PastMatchRow({required this.match, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final won = match.outcome == BattleOutcome.win;
    final drawn = match.outcome == BattleOutcome.draw;
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
                    ? tr('btz_w')
                    : drawn
                    ? tr('btz_d')
                    : tr('btz_l'),
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
                    tr('btz_vs', {'name': match.opponent}),
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
                    tr('btz_meta', {
                      'mode': match.duel ? '1v1' : '2v2',
                      'name': memoryKinds[match.kind].displayName,
                      'date': match.date,
                    }),
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
  final void Function(BattleFriend friend, bool invited)? onInviteChanged;
  const _FriendInviteRow({
    required this.friend,
    required this.onOpenProfile,
    this.onInviteChanged,
  });

  void _toggle() {
    if (battleInvites.isInvited(friend.name)) {
      AppFeedback.light();
      battleInvites.withdraw(friend.name);
      onInviteChanged?.call(friend, false);
    } else {
      AppFeedback.medium();
      battleInvites.invite(friend.name);
      onInviteChanged?.call(friend, true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final invited = battleInvites.isInvited(friend.name);
    return Container(
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
          Expanded(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: onOpenProfile,
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
                          tr('btz_streak_line', {
                            'xp': friend.xp,
                            'n': friend.streak,
                          }),
                          style: TextStyle(
                            color: context.mutedText,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 8),
          EngramMiniButton(
            label: invited ? tr('btz_challenged') : tr('btz_challenge'),
            background: invited ? violetDark : ink,
            haptic: false,
            onTap: _toggle,
          ),
        ],
      ),
    );
  }
}
