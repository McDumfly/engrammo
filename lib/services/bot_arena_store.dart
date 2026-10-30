import 'dart:math';

import 'package:flutter/foundation.dart';

import '../l10n/app_localizations.dart';
import '../models/battle_bot.dart';
import '../models/battle_invites.dart';
import '../models/battle_match.dart';
import '../models/battle_rating.dart';
import '../models/battle_rewards.dart';
import '../models/friend_social.dart';
import '../models/league_season.dart';
import 'memory_store.dart';

/// One simulated exhibition pairing for the Battle Zone showcase list.
/// These are training showcases between arena bots, not live human matches,
/// so they carry no viewer counts.
class LiveDuel {
  final String mode;
  final String title;
  final String task;
  final BotPersona home;
  final BotPersona away;

  const LiveDuel({
    required this.mode,
    required this.title,
    required this.task,
    required this.home,
    required this.away,
  });
}

/// Squad matchmaking result: the player's ally and two foes.
class BattleSquad {
  final BotPersona ally;
  final BotPersona foe1;
  final BotPersona foe2;

  const BattleSquad({
    required this.ally,
    required this.foe1,
    required this.foe2,
  });

  int get foeAverage =>
      ((foe1.rating + foe2.rating) / 2).round();
}

/// Central offline arena: bot roster, league season, friends, feed and duel
/// history. Everything is seeded deterministically and persisted through
/// [MemoryStore], so the arena works with no backend and no network.
class BotArenaStore extends ChangeNotifier {
  List<BotPersona> _roster = const [];
  LeagueSeason? _season;
  List<LeagueSummary> _leagueHistory = const [];
  List<FriendEdge> _friends = const [];
  List<FeedEvent> _feed = const [];
  List<BattleRecord> _history = const [];
  BattleStats _stats = const BattleStats();
  int _battleXp = 0;
  BattleRewardState _rewards = const BattleRewardState();
  String _lastWinDay = '';
  int _playerRating = BattleRating.startingRating;
  int _playerStreak = 0;
  String _playerName = 'You';
  Future<void>? _loading;

  List<BotPersona> get roster => List<BotPersona>.unmodifiable(_roster);
  LeagueSeason? get season => _season;
  List<LeagueSummary> get leagueHistory =>
      List<LeagueSummary>.unmodifiable(_leagueHistory);
  List<FriendEdge> get friends => List<FriendEdge>.unmodifiable(_friends);
  List<FeedEvent> get feed => List<FeedEvent>.unmodifiable(_feed);
  List<BattleRecord> get history => List<BattleRecord>.unmodifiable(_history);
  BattleStats get stats => _stats;
  int get battleXp => _battleXp;
  BattleRewardState get rewards => _rewards;
  String get lastWinDay => _lastWinDay;
  int get playerRating => _playerRating;
  int get playerStreak => _playerStreak;
  String get playerName => _playerName;

  bool get hasSeason => _season != null;

  int get cachedTierIndex => _season?.tierIndex ?? 0;

  int get cachedRank => _season?.playerRank ?? 0;

  String cachedTierName(String fallback) => _cachedTierName ?? fallback;
  String? _cachedTierName;

  /// Sets the resolved tier display name. The league page owns the tier
  /// list, so it pushes the name down after loading.
  void setCachedTierName(String name) {
    _cachedTierName = name;
  }

  int get friendCount => _friends.length;

  /// Lifetime profile total: battle XP plus every league point earned.
  int get totalXp {
    var league = _season?.playerEntry?.xp ?? 0;
    for (final s in _leagueHistory) {
      league += s.playerXp;
    }
    return _battleXp + league;
  }

  /// Loads everything once. Never throws: widgets keep rendering the
  /// previous (possibly empty) state when storage is unavailable, which
  /// keeps widget tests without mock storage green.
  Future<void> ensureLoaded({DateTime? now}) {
    final pending = _loading;
    if (pending != null) return pending;
    final future = _load(now ?? DateTime.now());
    _loading = future;
    return future;
  }

  Future<void> _load(DateTime now) async {
    try {
      var roster = await MemoryStore.loadBotRoster();
      if (roster.length < botNames.length) {
        roster = buildBotRoster();
        await MemoryStore.saveBotRosterWithoutNotify(roster);
      }
      _roster = roster;

      _history = await MemoryStore.loadBattleHistory();
      _stats = await MemoryStore.loadBattleStats();
      _battleXp = await MemoryStore.loadBattleXp();
      _rewards = await MemoryStore.loadBattleRewards();
      _lastWinDay = await MemoryStore.loadBattleLastWinDay();
      _friends = await MemoryStore.loadFriendGraph();
      _feed = await MemoryStore.loadFriendFeed();
      final scrubbed = [for (final e in _feed) if (e.botId == null) e];
      if (scrubbed.length != _feed.length) {
        _feed = scrubbed;
        await MemoryStore.saveFriendFeedWithoutNotify(_feed);
      }
      _leagueHistory = await MemoryStore.loadLeagueHistory();
      try {
        _playerRating = await MemoryStore.loadBattleRating(
          defaultRating: BattleRating.startingRating,
        );
      } catch (_) {
        _playerRating = BattleRating.startingRating;
      }
      try {
        final streak = await MemoryStore.loadStreakState();
        _playerStreak = streak.streak;
      } catch (_) {
        _playerStreak = 0;
      }
      try {
        final profile = await MemoryStore.loadProfile();
        final name = profile.username.isNotEmpty
            ? profile.username
            : profile.displayName;
        _playerName = name.isEmpty ? 'You' : name;
      } catch (_) {
        _playerName = 'You';
      }

      var season = await MemoryStore.loadLeagueSeason();
      final activity = await _playerActivityXp(now);
      LeagueSummary? finishedSummary;
      var finishedOldTier = 0;
      if (season == null || season.seasonId != seasonIdFor(now)) {
        if (season != null) {
          finishedOldTier = season.tierIndex;
          final rolled = rolloverIfNeeded(
            season: season,
            now: now,
            playerName: _playerName,
            playerRating: _playerRating,
            playerStreak: _playerStreak,
            playerActivityXp: activity,
            roster: _roster,
          );
          if (rolled != null) {
            season = rolled.season;
            finishedSummary = rolled.summary;
            _leagueHistory = [..._leagueHistory, rolled.summary];
            await MemoryStore.saveLeagueHistoryWithoutNotify(_leagueHistory);
          } else {
            season = null;
          }
        }
        season ??= seedSeason(
          now: now,
          playerName: _playerName,
          playerRating: _playerRating,
          playerStreak: _playerStreak,
          playerActivityXp: activity,
          tierIndex: 0,
          roster: _roster,
        );
        _feed = [
          FeedEvent(
            id: 'feed:${now.microsecondsSinceEpoch}:welcome',
            at: now,
            kind: FeedKind.welcome,
            text: tr('blg_feed_welcome', {'name': _playerName}),
          ),
          ..._feed,
        ];
        await MemoryStore.saveLeagueSeasonWithoutNotify(season);
        await MemoryStore.saveFriendFeedWithoutNotify(_feed);
      } else {
        final ticked = tickSeason(
          season: season,
          now: now,
          playerRating: _playerRating,
          playerStreak: _playerStreak,
          playerActivityXp: activity,
        );
        if (ticked.lastTickDay != season.lastTickDay) {
          season = ticked;
          await MemoryStore.saveLeagueSeasonWithoutNotify(season);
        } else if (ticked.playerEntry?.xp != season.playerEntry?.xp ||
            ticked.playerEntry?.rating != season.playerEntry?.rating) {
          season = ticked;
          await MemoryStore.saveLeagueSeasonWithoutNotify(season);
        }
      }
      _season = season;
      // Season-end payouts for the finished week: top-3 rank bonus plus
      // tier-promotion bonus. Idempotent per season id, lands on the fresh
      // season row and in the feed.
      final finished = finishedSummary;
      final fresh = _season;
      if (finished != null && fresh != null) {
        await applySeasonRewards(
          seasonId: finished.seasonId,
          playerRank: finished.playerRank,
          oldTierIndex: finishedOldTier,
          newTierIndex: fresh.tierIndex,
          now: now,
        );
      }
    } catch (_) {
      // Degrade to empty arena; screens render their empty states.
    } finally {
      try {
        notifyListeners();
      } catch (_) {}
    }
  }

  /// Practice earns league points: 40 XP per lesson finished this week.
  Future<int> _playerActivityXp(DateTime now) async {
    try {
      final start = weekStartFor(now);
      final done = await MemoryStore.loadLessonDoneDates();
      var count = 0;
      for (final at in done.values) {
        if (!at.isBefore(start)) count++;
      }
      return count * 40;
    } catch (_) {
      return 0;
    }
  }

  BotPersona? botById(String id) {
    for (final bot in _roster) {
      if (bot.id == id) return bot;
    }
    return null;
  }

  BotPersona? botByName(String name) {
    for (final bot in _roster) {
      if (bot.name == name) return bot;
    }
    return null;
  }

  /// Fair 1v1 opponent near the player's rating.
  BotPersona? matchOpponent({Set<String> excludeIds = const {}, int? seed}) {
    return pickBotOpponent(
      playerRating: _playerRating,
      roster: _roster,
      excludeIds: excludeIds,
      seed: seed ?? DateTime.now().microsecondsSinceEpoch,
    );
  }

  /// 2v2 squads: an ally near the player, foes near the squad average.
  BattleSquad? matchSquad({int? seed}) {
    if (_roster.length < 3) return null;
    final rng = Random(seed ?? DateTime.now().microsecondsSinceEpoch);
    final ally = pickBotOpponent(
      playerRating: _playerRating,
      roster: _roster,
      seed: rng.nextInt(1 << 32),
    );
    if (ally == null) return null;
    final squadAvg = ((_playerRating + ally.rating) / 2).round();
    final rest = [for (final b in _roster) if (b.id != ally.id) b];
    final foe1 = pickBotOpponent(
      playerRating: squadAvg,
      roster: rest,
      seed: rng.nextInt(1 << 32),
    );
    if (foe1 == null) return null;
    final rest2 = [for (final b in rest) if (b.id != foe1.id) b];
    final foe2 = pickBotOpponent(
      playerRating: squadAvg,
      roster: rest2,
      seed: rng.nextInt(1 << 32),
    );
    if (foe2 == null) return null;
    return BattleSquad(ally: ally, foe1: foe1, foe2: foe2);
  }

  /// Persists one finished duel: history, stats, XP wallet, bot rating
  /// drift, league row and feed. Rating itself is saved by the caller via
  /// [MemoryStore.saveBattleRating] and reloaded here.
  Future<void> recordBattle({
    required BattleRecord record,
    required BattleOutcome outcome,
    List<String> botIds = const [],
    DateTime? now,
  }) async {
    final at = now ?? DateTime.now();
    _history = [record, ..._history];
    _stats = _stats.record(outcome);
    var bonusXp = 0;
    if (outcome == BattleOutcome.win) {
      final streakXp = BattleRewards.streakBonusFor(_stats.currentStreak);
      if (streakXp > 0) {
        final grant = RewardGrant(
          id: 'streak:${record.id}',
          kind: RewardKind.streak,
          xp: streakXp,
          at: at,
        );
        if (!_rewards.hasGrant(grant.id)) {
          _rewards = _rewards.withGrant(grant);
          bonusXp = streakXp;
        }
      }
    }
    _battleXp += record.xp + bonusXp;
    try {
      _playerRating = await MemoryStore.loadBattleRating(
        defaultRating: BattleRating.startingRating,
      );
    } catch (_) {}
    final drifted = <BotPersona>[];
    for (final bot in _roster) {
      if (!botIds.contains(bot.id)) {
        drifted.add(bot);
        continue;
      }
      final score = switch (outcome) {
        BattleOutcome.win => 0.0,
        BattleOutcome.loss => 1.0,
        BattleOutcome.draw => 0.5,
      };
      final next = BattleRating.nextRating(
        player: bot.rating,
        opponent: _playerRating,
        score: score,
      );
      final clamped = (next - bot.rating).clamp(-8, 8) + bot.rating;
      drifted.add(
        bot.copyWith(
          rating: max(BattleRating.minRating, clamped),
          xp: bot.xp + (outcome == BattleOutcome.loss ? 90 : 40),
        ),
      );
    }
    _roster = drifted;
    final season = _season;
    if (season != null) {
      _season = addPlayerBattleXp(season, record.xp + bonusXp);
      await MemoryStore.saveLeagueSeasonWithoutNotify(_season!);
    }
    final resultKey = switch (outcome) {
      BattleOutcome.win => 'blg_feed_win',
      BattleOutcome.loss => 'blg_feed_loss',
      BattleOutcome.draw => 'blg_feed_draw',
    };
    _feed = [
      FeedEvent(
        id: 'feed:${at.microsecondsSinceEpoch}:battle',
        at: at,
        kind: FeedKind.battle,
        text: tr(resultKey, {'name': record.opponent, 'xp': record.xp}),
        xpDelta: record.xp,
      ),
      if (bonusXp > 0)
        FeedEvent(
          id: 'feed:${at.microsecondsSinceEpoch}:streak',
          at: at,
          kind: FeedKind.streak,
          text: tr('blg_feed_streak', {'xp': bonusXp}),
          xpDelta: bonusXp,
        ),
      ..._feed,
    ];
    await MemoryStore.saveBattleHistoryWithoutNotify(_history);
    await MemoryStore.saveBattleStatsWithoutNotify(_stats);
    await MemoryStore.saveBattleXpWithoutNotify(_battleXp);
    await MemoryStore.saveBattleRewardsWithoutNotify(_rewards);
    await MemoryStore.saveBotRosterWithoutNotify(_roster);
    await MemoryStore.saveFriendFeedWithoutNotify(_feed);
    notifyListeners();
  }

  /// Daily first-win double. Call after a won duel with the duel's base XP.
  /// Grants bonus XP equal to [baseXp] (x2 total) once per calendar day and
  /// returns the bonus actually granted (0 when already claimed today).
  Future<int> claimDailyWinBonus(int baseXp, {DateTime? now}) async {
    final at = now ?? DateTime.now();
    final bonus = BattleRewards.dailyWinBonus(
      baseXp: baseXp,
      lastWinDay: _lastWinDay,
      now: at,
    );
    if (bonus <= 0) return 0;
    final day = BattleRewards.dayKey(at);
    _lastWinDay = day;
    _rewards = _rewards.withGrant(
      RewardGrant(id: 'daily:$day', kind: RewardKind.daily, xp: bonus, at: at),
    );
    _battleXp += bonus;
    final season = _season;
    if (season != null) {
      _season = addPlayerBattleXp(season, bonus);
      await MemoryStore.saveLeagueSeasonWithoutNotify(_season!);
    }
    _feed = [
      FeedEvent(
        id: 'feed:${at.microsecondsSinceEpoch}:daily',
        at: at,
        kind: FeedKind.battle,
        text: tr('blg_feed_daily', {'xp': bonus}),
        xpDelta: bonus,
      ),
      ..._feed,
    ];
    await MemoryStore.saveBattleXpWithoutNotify(_battleXp);
    await MemoryStore.saveBattleRewardsWithoutNotify(_rewards);
    await MemoryStore.saveBattleLastWinDayWithoutNotify(day);
    await MemoryStore.saveFriendFeedWithoutNotify(_feed);
    notifyListeners();
    return bonus;
  }

  /// Season-end payouts: weekly top-3 rank bonus plus tier-promotion bonus.
  /// Idempotent per [seasonId]; returns the total bonus XP granted.
  Future<int> applySeasonRewards({
    required String seasonId,
    required int playerRank,
    required int oldTierIndex,
    required int newTierIndex,
    DateTime? now,
  }) async {
    final at = now ?? DateTime.now();
    final grants = BattleRewards.seasonGrants(
      seasonId: seasonId,
      playerRank: playerRank,
      oldTierIndex: oldTierIndex,
      newTierIndex: newTierIndex,
      now: at,
    );
    var total = 0;
    final fresh = <RewardGrant>[];
    for (final grant in grants) {
      if (_rewards.hasGrant(grant.id)) continue;
      _rewards = _rewards.withGrant(grant);
      fresh.add(grant);
      total += grant.xp;
    }
    if (total <= 0) return 0;
    _battleXp += total;
    final season = _season;
    if (season != null) {
      _season = addPlayerBattleXp(season, total);
      await MemoryStore.saveLeagueSeasonWithoutNotify(_season!);
    }
    _feed = [
      for (final grant in fresh)
        FeedEvent(
          id: 'feed:${at.microsecondsSinceEpoch}:reward:${grant.id}',
          at: at,
          kind: FeedKind.promotion,
          text: grant.kind == RewardKind.weekly
              ? tr('blg_feed_weekly', {
                  'rank': playerRank < 1 ? '-' : playerRank,
                  'xp': grant.xp,
                })
              : tr('blg_feed_promo', {'xp': grant.xp}),
          xpDelta: grant.xp,
        ),
      ..._feed,
    ];
    await MemoryStore.saveBattleXpWithoutNotify(_battleXp);
    await MemoryStore.saveBattleRewardsWithoutNotify(_rewards);
    await MemoryStore.saveFriendFeedWithoutNotify(_feed);
    notifyListeners();
    return total;
  }

  /// Rating drift for a squad ally: allies win and lose with the player.
  Future<void> driftTeammate(String botId, {required bool playerWon}) async {
    final drifted = <BotPersona>[];
    var changed = false;
    for (final bot in _roster) {
      if (bot.id != botId) {
        drifted.add(bot);
        continue;
      }
      changed = true;
      final next = BattleRating.nextRating(
        player: bot.rating,
        opponent: _playerRating,
        score: playerWon ? 1.0 : 0.0,
      );
      final clamped = (next - bot.rating).clamp(-8, 8) + bot.rating;
      drifted.add(
        bot.copyWith(
          rating: max(BattleRating.minRating, clamped),
          xp: bot.xp + (playerWon ? 90 : 40),
        ),
      );
    }
    if (!changed) return;
    _roster = drifted;
    await MemoryStore.saveBotRoster(_roster);
    notifyListeners();
  }

  bool isFriend(String botId) => _friends.any((e) => e.botId == botId);

  Future<void> addFriend(String botId, {DateTime? now}) async {
    if (isFriend(botId) || botById(botId) == null) return;
    _friends = [
      FriendEdge(botId: botId, addedAt: now ?? DateTime.now()),
      ..._friends,
    ];
    await MemoryStore.saveFriendGraph(_friends);
    notifyListeners();
  }

  Future<void> removeFriend(String botId) async {
    if (!isFriend(botId)) return;
    _friends = [for (final e in _friends) if (e.botId != botId) e];
    await MemoryStore.saveFriendGraph(_friends);
    notifyListeners();
  }

  /// Added friends, newest first.
  List<BotPersona> friendBots() {
    final out = <BotPersona>[];
    for (final edge in _friends) {
      final bot = botById(edge.botId);
      if (bot != null) out.add(bot);
    }
    return out;
  }

  /// Suggested friends: similarly-rated bots the player has not added yet.
  List<BotPersona> suggestions({int limit = 8}) {
    final added = {for (final e in _friends) e.botId};
    final pool = [
      for (final bot in _roster)
        if (!added.contains(bot.id)) bot,
    ];
    pool.sort((a, b) {
      final da = (a.rating - _playerRating).abs();
      final db = (b.rating - _playerRating).abs();
      if (da != db) return da.compareTo(db);
      return b.xp.compareTo(a.xp);
    });
    final capped = limit.clamp(1, pool.length);
    return pool.take(capped).toList();
  }

  /// Friends-only directory for the Battle Zone invite list: only bots the
  /// player actually added, newest first.
  List<BattleFriend> friendsDirectory({DateTime? now}) {
    final at = now ?? DateTime.now();
    return [for (final bot in friendBots()) botToFriend(bot, at)];
  }

  /// Full searchable directory: friends first, then suggestions.
  List<BattleFriend> directory({DateTime? now}) {
    final at = now ?? DateTime.now();
    final seen = <String>{};
    final out = <BattleFriend>[];
    for (final bot in [...friendBots(), ...suggestions(limit: 40)]) {
      if (!seen.add(bot.id)) continue;
      out.add(botToFriend(bot, at));
    }
    return out;
  }

  BattleFriend botToFriend(BotPersona bot, [DateTime? now]) {
    return BattleFriend(
      name: bot.name,
      xp: bot.xp,
      streak: bot.streak,
      online: isBotOnline(bot, now ?? DateTime.now()),
    );
  }

  /// Three deterministic exhibition pairings, stable within the hour.
  List<LiveDuel> liveDuels({DateTime? now, String locale = 'en'}) {
    final at = now ?? DateTime.now();
    if (_roster.length < 6) return const [];
    final bucket = DateTime(at.year, at.month, at.day, at.hour);
    final rng = Random(
      botSeedHash('live:${bucket.millisecondsSinceEpoch}'),
    );
    final tasks = <String>[
      for (var i = 0; i < 6; i++) trFor(locale, 'btl_show_$i'),
    ];
    final pool = List<BotPersona>.of(_roster)..shuffle(rng);
    final out = <LiveDuel>[];
    for (var i = 0; i < 3; i++) {
      final duel = i != 1;
      final home = pool[i * 2];
      final away = pool[i * 2 + 1];
      out.add(
        LiveDuel(
          mode: duel ? '1v1' : '2v2',
          title: duel ? '${home.name} vs ${away.name}' : _squadTitle(pool, rng),
          task: tasks[rng.nextInt(tasks.length)],
          home: home,
          away: away,
        ),
      );
    }
    return out;
  }

  String _squadTitle(List<BotPersona> pool, Random rng) {
    final a = pool[rng.nextInt(pool.length)];
    var b = pool[rng.nextInt(pool.length)];
    while (b.id == a.id) {
      b = pool[rng.nextInt(pool.length)];
    }
    var c = pool[rng.nextInt(pool.length)];
    while (c.id == a.id || c.id == b.id) {
      c = pool[rng.nextInt(pool.length)];
    }
    var d = pool[rng.nextInt(pool.length)];
    while (d.id == a.id || d.id == b.id || d.id == c.id) {
      d = pool[rng.nextInt(pool.length)];
    }
    return '${a.name} + ${b.name} vs ${c.name} + ${d.name}';
  }

  /// Head-to-head record against one opponent name.
  ({int wins, int losses, int draws}) headToHead(String opponent) {
    var wins = 0;
    var losses = 0;
    var draws = 0;
    for (final record in _history) {
      if (record.opponent != opponent) continue;
      switch (record.outcome) {
        case BattleOutcome.win:
          wins++;
        case BattleOutcome.loss:
          losses++;
        case BattleOutcome.draw:
          draws++;
      }
    }
    return (wins: wins, losses: losses, draws: draws);
  }

  /// Reloads everything from local storage. Called after a cloud pull so
  /// the arena reflects the Firebase state instead of the pre-login cache.
  Future<void> refresh() {
    _loading = null;
    return ensureLoaded();
  }

  @visibleForTesting
  void resetForTest() {
    _roster = const [];
    _season = null;
    _leagueHistory = const [];
    _friends = const [];
    _feed = const [];
    _history = const [];
    _stats = const BattleStats();
    _battleXp = 0;
    _rewards = const BattleRewardState();
    _lastWinDay = '';
    _playerRating = BattleRating.startingRating;
    _playerStreak = 0;
    _playerName = 'You';
    _cachedTierName = null;
    _loading = null;
  }
}

final botArena = BotArenaStore();
