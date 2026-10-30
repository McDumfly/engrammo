import 'dart:math';

import 'package:engrammo/models/battle_bot.dart';
import 'package:engrammo/models/battle_match.dart';
import 'package:engrammo/models/battle_rewards.dart';
import 'package:engrammo/models/friend_social.dart';
import 'package:engrammo/models/league_season.dart';
import 'package:engrammo/services/bot_arena_store.dart';
import 'package:engrammo/services/memory_store.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('bot tiers', () {
    test('every rating maps to exactly one tier', () {
      for (var rating = 500; rating <= 1900; rating += 25) {
        expect(tierForRating(rating), isA<BotTier>());
      }
    });

    test('accuracy rises and latency falls across tiers', () {
      final tiers = BotTier.values;
      for (var i = 1; i < tiers.length; i++) {
        final prev = specForTier(tiers[i - 1]);
        final next = specForTier(tiers[i]);
        expect(next.accMin, greaterThanOrEqualTo(prev.accMin));
        expect(next.accMax, greaterThanOrEqualTo(prev.accMax));
        expect(next.latencyMeanMs, lessThan(prev.latencyMeanMs));
        expect(next.weeklyXpMean, greaterThan(prev.weeklyXpMean));
      }
    });

    test('roster covers all tiers with unique names', () {
      final roster = buildBotRoster();
      expect(roster, hasLength(botNames.length));
      expect({for (final b in roster) b.id}.length, roster.length);
      expect({for (final b in roster) b.name}.length, roster.length);
      final tiers = {for (final b in roster) b.tier};
      expect(tiers, containsAll(BotTier.values));
      for (final bot in roster) {
        expect(bot.rating, inInclusiveRange(600, 1800));
      }
    });
  });

  group('matchmaking', () {
    final roster = buildBotRoster();

    test('picks within the window when possible', () {
      final opp = pickBotOpponent(
        playerRating: 1000,
        roster: roster,
        seed: 7,
      );
      expect(opp, isNotNull);
      expect((opp!.rating - 1000).abs(), lessThanOrEqualTo(60));
    });

    test('same seed picks the same opponent', () {
      final a = pickBotOpponent(
        playerRating: 1000,
        roster: roster,
        seed: 42,
      );
      final b = pickBotOpponent(
        playerRating: 1000,
        roster: roster,
        seed: 42,
      );
      expect(a!.id, b!.id);
    });

    test('respects the recent-opponent exclusion', () {
      final first = pickBotOpponent(
        playerRating: 1000,
        roster: roster,
        seed: 3,
      )!;
      final second = pickBotOpponent(
        playerRating: 1000,
        roster: roster,
        excludeIds: {first.id},
        seed: 3,
      )!;
      expect(second.id, isNot(first.id));
    });

    test('widens honestly for extreme ratings', () {
      final opp = pickBotOpponent(
        playerRating: 2500,
        roster: roster,
        seed: 1,
      );
      expect(opp, isNotNull);
      expect(opp!.rating, greaterThanOrEqualTo(1400));
    });

    test('empty roster returns null', () {
      expect(
        pickBotOpponent(playerRating: 1000, roster: const [], seed: 1),
        isNull,
      );
    });

    test('matchmaking delay stays within 2-6 seconds', () {
      final rng = Random(9);
      for (var i = 0; i < 50; i++) {
        final delay = matchmakingDelay(rng);
        expect(delay.inMilliseconds, inInclusiveRange(2000, 6000));
      }
    });
  });

  group('bot policy', () {
    final roster = buildBotRoster();
    final rookie = roster.firstWhere((b) => b.tier == BotTier.rookie);
    final quantum = roster.firstWhere((b) => b.tier == BotTier.quantum);

    test('accuracy stays in range and rewards rating', () {
      final low = botAccuracy(bot: rookie, kind: 1);
      final high = botAccuracy(bot: quantum, kind: 1);
      expect(low, inInclusiveRange(0.05, 0.98));
      expect(high, inInclusiveRange(0.05, 0.98));
      expect(high, greaterThan(low));
    });

    test('per-kind bias is bounded', () {
      final base = botAccuracy(bot: rookie);
      for (var kind = 0; kind < 6; kind++) {
        final biased = botAccuracy(bot: rookie, kind: kind);
        expect((biased - base).abs(), lessThanOrEqualTo(0.08 + 1e-9));
      }
    });

    test('latency stays clamped and slower paradigms take longer', () {
      final spec = specForTier(rookie.tier);
      for (var i = 0; i < 30; i++) {
        final ms = botLatencyMs(
          bot: rookie,
          paradigm: 'backward-span',
          rng: Random(i),
        );
        expect(ms, inInclusiveRange(spec.latencyMinMs, spec.latencyMaxMs));
      }
      var slowWins = 0;
      for (var i = 0; i < 30; i++) {
        final slow = botLatencyMs(
          bot: rookie,
          paradigm: 'brown-peterson',
          rng: Random(1000 + i),
        );
        final fast = botLatencyMs(
          bot: rookie,
          paradigm: 'story-recall',
          rng: Random(1000 + i),
        );
        if (slow >= fast) slowWins++;
      }
      expect(slowWins, greaterThan(20));
    });

    test('online presence is stable within the hour', () {
      final now = DateTime(2026, 10, 29, 19, 12);
      final a = isBotOnline(rookie, now);
      final b = isBotOnline(rookie, now.add(const Duration(minutes: 20)));
      expect(a, b);
    });

    test('rubber-band chases the leader within caps', () {
      final chase = applyRubberBand(
        baseAccuracy: 0.6,
        baseLatencyMs: 6000,
        playerTotal: 300,
        foeTotal: 100,
        questionIndex: 0,
        questionCount: 3,
        playerRating: 1200,
        matchesPlayed: 20,
      );
      expect(chase.accuracy, closeTo(0.68, 1e-9));
      expect(chase.latencyMs, 5400);

      final ease = applyRubberBand(
        baseAccuracy: 0.6,
        baseLatencyMs: 6000,
        playerTotal: 100,
        foeTotal: 300,
        questionIndex: 1,
        questionCount: 3,
        playerRating: 1200,
        matchesPlayed: 20,
      );
      expect(ease.accuracy, closeTo(0.52, 1e-9));
      expect(ease.latencyMs, 6600);
    });

    test('clean finish within 60 points on the final question', () {
      final clean = applyRubberBand(
        baseAccuracy: 0.6,
        baseLatencyMs: 6000,
        playerTotal: 250,
        foeTotal: 200,
        questionIndex: 2,
        questionCount: 3,
        playerRating: 1200,
        matchesPlayed: 20,
      );
      expect(clean.accuracy, closeTo(0.6, 1e-9));
      expect(clean.latencyMs, 6000);
    });

    test('new players get mercy', () {
      final mercy = applyRubberBand(
        baseAccuracy: 0.6,
        baseLatencyMs: 6000,
        playerTotal: 0,
        foeTotal: 0,
        questionIndex: 0,
        questionCount: 3,
        playerRating: 1000,
        matchesPlayed: 2,
      );
      expect(mercy.accuracy, closeTo(0.55, 1e-9));
    });
  });

  group('scoring and XP', () {
    test('faster correct answers score more', () {
      final fast = BattleScore.questionPoints(correct: true, latencyMs: 1000);
      final slow = BattleScore.questionPoints(correct: true, latencyMs: 15000);
      expect(fast, greaterThan(slow));
      expect(fast, inInclusiveRange(100, 150));
      expect(slow, inInclusiveRange(100, 150));
    });

    test('wrong answers and timeouts score nothing', () {
      expect(
        BattleScore.questionPoints(correct: false, latencyMs: 500),
        0,
      );
      expect(
        BattleScore.questionPoints(correct: true, latencyMs: 60000),
        100,
      );
    });

    test('XP ordering holds with floor and bonuses', () {
      final win = BattleXp.forOutcome(
        outcome: BattleOutcome.win,
        margin: 120,
      );
      final draw = BattleXp.forOutcome(
        outcome: BattleOutcome.draw,
        margin: 0,
      );
      final loss = BattleXp.forOutcome(
        outcome: BattleOutcome.loss,
        margin: 200,
      );
      expect(win, greaterThan(draw));
      expect(draw, greaterThan(loss));
      expect(loss, greaterThanOrEqualTo(BattleXp.participationFloor));
      final bonus = BattleXp.forOutcome(
        outcome: BattleOutcome.loss,
        margin: 0,
        fastestBonuses: 2,
      );
      expect(bonus, loss + 2 * BattleXp.fastestBonus);
    });

    test('outcome breaks ties by total latency', () {
      expect(outcomeFor(300, 200), BattleOutcome.win);
      expect(outcomeFor(200, 300), BattleOutcome.loss);
      expect(outcomeFor(250, 250), BattleOutcome.draw);
      expect(
        outcomeFor(250, 250, playerMs: 9000, foeMs: 12000),
        BattleOutcome.win,
      );
      expect(
        outcomeFor(250, 250, playerMs: 12000, foeMs: 9000),
        BattleOutcome.loss,
      );
    });

    test('stats track win rate and streaks', () {
      var stats = const BattleStats();
      expect(stats.winRateLabel, '–');
      stats = stats.record(BattleOutcome.win).record(BattleOutcome.win);
      stats = stats.record(BattleOutcome.loss);
      expect(stats.matches, 3);
      expect(stats.winRateLabel, '67%');
      expect(stats.bestStreak, 2);
      expect(stats.currentStreak, 0);
    });

    test('date labels use today, yesterday and month day', () {
      final now = DateTime(2026, 10, 29, 20, 15);
      expect(
        battleDateLabel(DateTime(2026, 10, 29, 19, 42), now),
        'Today, 19:42',
      );
      expect(
        battleDateLabel(DateTime(2026, 10, 28, 20, 15), now),
        'Yesterday, 20:15',
      );
      expect(
        battleDateLabel(DateTime(2026, 10, 23, 20, 15), now),
        'Oct 23, 20:15',
      );
    });
  });

  group('league season', () {
    final roster = buildBotRoster();
    final monday = DateTime(2026, 10, 26, 10);

    test('season starts on Monday with 30 bots plus player', () {
      expect(weekStartFor(monday).weekday, DateTime.monday);
      expect(seasonIdFor(monday), '2026-10-26');
      final season = seedSeason(
        now: monday,
        playerName: 'You',
        playerRating: 1000,
        playerStreak: 4,
        playerActivityXp: 80,
        tierIndex: 0,
        roster: roster,
      );
      expect(season.entries, hasLength(31));
      expect(season.playerEntry, isNotNull);
      expect(season.playerEntry!.xp, 80);
      expect(season.playerRank, inInclusiveRange(1, 31));
    });

    test('seeding is deterministic per week', () {
      LeagueSeason seed() => seedSeason(
        now: monday,
        playerName: 'You',
        playerRating: 1000,
        playerStreak: 4,
        playerActivityXp: 0,
        tierIndex: 0,
        roster: roster,
      );
      final a = seed();
      final b = seed();
      expect(
        [for (final e in a.sorted) '${e.id}:${e.xp}'],
        [for (final e in b.sorted) '${e.id}:${e.xp}'],
      );
    });

    test('daily tick only advances once per day', () {
      var season = seedSeason(
        now: monday,
        playerName: 'You',
        playerRating: 1000,
        playerStreak: 4,
        playerActivityXp: 0,
        tierIndex: 0,
        roster: roster,
      );
      final before = [for (final e in season.entries) e.xp];
      season = tickSeason(
        season: season,
        now: monday.add(const Duration(hours: 2)),
        playerRating: 1000,
        playerStreak: 4,
        playerActivityXp: 40,
      );
      expect([for (final e in season.entries) e.xp], isNot(before));
      final afterFirst = [for (final e in season.entries) e.xp];
      season = tickSeason(
        season: season,
        now: monday.add(const Duration(hours: 3)),
        playerRating: 1000,
        playerStreak: 4,
        playerActivityXp: 40,
      );
      expect([for (final e in season.entries) e.xp], afterFirst);
    });

    test('expired season rolls over with promotion and archive', () {
      var season = seedSeason(
        now: monday,
        playerName: 'You',
        playerRating: 1000,
        playerStreak: 4,
        playerActivityXp: 0,
        tierIndex: 2,
        roster: roster,
      );
      season = addPlayerBattleXp(season, 99999);
      final nextMonday = monday.add(const Duration(days: 7, hours: 1));
      final rolled = rolloverIfNeeded(
        season: season,
        now: nextMonday,
        playerName: 'You',
        playerRating: 1000,
        playerStreak: 5,
        playerActivityXp: 0,
        roster: roster,
      );
      expect(rolled, isNotNull);
      expect(rolled!.summary.seasonId, season.seasonId);
      expect(rolled.summary.playerRank, 1);
      expect(rolled.season.tierIndex, 3);
      expect(rolled.season.entries, hasLength(31));
      expect(rolled.season.playerBattleXp, 0);
      final kept = {
        for (final e in season.entries)
          if (e.isBot) e.id,
      }.intersection({
        for (final e in rolled.season.entries)
          if (e.isBot) e.id,
      });
      expect(kept.length, greaterThanOrEqualTo(LeagueSeason.botCount ~/ 2));
      expect(kept.length, lessThan(LeagueSeason.botCount));
    });

    test('no rollover before the week ends', () {
      final season = seedSeason(
        now: monday,
        playerName: 'You',
        playerRating: 1000,
        playerStreak: 4,
        playerActivityXp: 0,
        tierIndex: 0,
        roster: roster,
      );
      final rolled = rolloverIfNeeded(
        season: season,
        now: monday.add(const Duration(days: 6)),
        playerName: 'You',
        playerRating: 1000,
        playerStreak: 4,
        playerActivityXp: 0,
        roster: roster,
      );
      expect(rolled, isNull);
    });
  });

  group('friends and feed', () {
    test('unknown feed kinds fall back to battle', () {
      expect(feedKindFromName('nope'), FeedKind.battle);
      expect(feedKindFromName('streak'), FeedKind.streak);
    });

    test('edges and events survive a json round trip', () {
      final edge = FriendEdge(botId: 'bot_1', addedAt: DateTime(2026, 1, 2));
      expect(
        FriendEdge.fromJson(edge.toJson()).botId,
        'bot_1',
      );
      final event = FeedEvent(
        id: 'feed:1',
        at: DateTime(2026, 1, 2),
        kind: FeedKind.streak,
        text: 'Nora reached a 9-day streak',
      );
      final back = FeedEvent.fromJson(event.toJson());
      expect(back.kind, FeedKind.streak);
      expect(back.text, contains('Nora'));
    });
  });

  group('bot arena store', () {
    setUp(() async {
      botArena.resetForTest();
      SharedPreferences.setMockInitialValues({});
    });

    tearDown(() {
      botArena.resetForTest();
    });

    test('first load seeds roster, season and welcome feed', () async {
      await botArena.ensureLoaded(now: DateTime(2026, 10, 28, 19));
      expect(botArena.roster, hasLength(botNames.length));
      expect(botArena.hasSeason, isTrue);
      expect(botArena.season!.entries, hasLength(31));
      expect(botArena.cachedRank, inInclusiveRange(1, 31));
      expect(
        botArena.feed.any((e) => e.kind == FeedKind.welcome),
        isTrue,
      );
    });

    test('friends add, list and remove', () async {
      await botArena.ensureLoaded(now: DateTime(2026, 10, 28, 19));
      final bot = botArena.roster.first;
      await botArena.addFriend(bot.id);
      expect(botArena.isFriend(bot.id), isTrue);
      expect(botArena.friendBots().map((b) => b.id), contains(bot.id));
      expect(
        botArena.suggestions().map((b) => b.id),
        isNot(contains(bot.id)),
      );
      await botArena.removeFriend(bot.id);
      expect(botArena.isFriend(bot.id), isFalse);
    });

    test('recording a battle updates stats, xp and history', () async {
      await botArena.ensureLoaded(now: DateTime(2026, 10, 28, 19));
      final bot = botArena.roster.first;
      final before = bot.rating;
      final record = BattleRecord(
        id: 'battle:test-1',
        at: DateTime(2026, 10, 28, 20),
        opponent: bot.name,
        opponentRating: bot.rating,
        duel: true,
        kind: 1,
        playerScore: 320,
        foeScore: 240,
        rounds: const [],
        roundLines: const ['backward-span · you 120 / foe 80'],
        delta: 16,
        xp: 112,
      );
      await botArena.recordBattle(
        record: record,
        outcome: BattleOutcome.win,
        botIds: [bot.id],
      );
      expect(botArena.stats.matches, 1);
      expect(botArena.stats.wins, 1);
      expect(botArena.battleXp, 112);
      expect(botArena.history.first.id, 'battle:test-1');
      expect(botArena.botById(bot.id)!.rating, lessThan(before));
      expect(botArena.season!.playerEntry!.xp, greaterThanOrEqualTo(112));
      expect(botArena.headToHead(bot.name).wins, 1);
    });

    test('squads and live rows come from the roster', () async {
      await botArena.ensureLoaded(now: DateTime(2026, 10, 28, 19));
      final squad = botArena.matchSquad(seed: 11)!;
      final ids = {squad.ally.id, squad.foe1.id, squad.foe2.id};
      expect(ids, hasLength(3));
      final live = botArena.liveDuels(now: DateTime(2026, 10, 28, 19, 5));
      expect(live, hasLength(3));
      final again = botArena.liveDuels(now: DateTime(2026, 10, 28, 19, 40));
      expect(
        [for (final d in again) d.title],
        [for (final d in live) d.title],
      );
      final names = {for (final b in botArena.roster) b.name};
      for (final d in live) {
        expect(names, contains(d.home.name));
        expect(names, contains(d.away.name));
      }
    });

    test('daily first-win double claims once per day', () async {
      await botArena.ensureLoaded(now: DateTime(2026, 10, 28, 19));
      final day = DateTime(2026, 10, 28, 20);
      final bonus = await botArena.claimDailyWinBonus(112, now: day);
      expect(bonus, 112);
      expect(botArena.battleXp, 112);
      expect(botArena.lastWinDay, '2026-10-28');
      expect(botArena.rewards.bonusFor(RewardKind.daily), 112);
      final again = await botArena.claimDailyWinBonus(112, now: day);
      expect(again, 0);
      expect(botArena.battleXp, 112);
      final nextDay = await botArena.claimDailyWinBonus(
        100,
        now: DateTime(2026, 10, 29, 9),
      );
      expect(nextDay, 100);
      expect(botArena.battleXp, 212);
    });

    test('season rewards pay rank and tier exactly once', () async {
      await botArena.ensureLoaded(now: DateTime(2026, 10, 28, 19));
      Future<int> apply() => botArena.applySeasonRewards(
        seasonId: '2026-10-26',
        playerRank: 2,
        oldTierIndex: 1,
        newTierIndex: 2,
        now: DateTime(2026, 11, 2, 9),
      );
      expect(await apply(), 200);
      expect(botArena.battleXp, 200);
      expect(botArena.rewards.bonusFor(RewardKind.weekly), 100);
      expect(botArena.rewards.bonusFor(RewardKind.tier), 100);
      expect(await apply(), 0);
      expect(botArena.battleXp, 200);
      final offPodium = await botArena.applySeasonRewards(
        seasonId: '2026-11-02',
        playerRank: 12,
        oldTierIndex: 2,
        newTierIndex: 2,
      );
      expect(offPodium, 0);
    });

    test('third straight win grants the streak bonus', () async {
      await botArena.ensureLoaded(now: DateTime(2026, 10, 28, 19));
      final bot = botArena.roster.first;
      Future<void> win(int i) => botArena.recordBattle(
        record: BattleRecord(
          id: 'battle:streak-$i',
          at: DateTime(2026, 10, 28, 20, i),
          opponent: bot.name,
          opponentRating: bot.rating,
          duel: true,
          kind: 1,
          playerScore: 320,
          foeScore: 240,
          rounds: const [],
          roundLines: const [],
          delta: 10,
          xp: 100,
        ),
        outcome: BattleOutcome.win,
        botIds: [bot.id],
      );
      await win(1);
      await win(2);
      expect(botArena.battleXp, 200);
      await win(3);
      expect(botArena.stats.currentStreak, 3);
      expect(botArena.battleXp, 325);
      expect(botArena.rewards.bonusFor(RewardKind.streak), 25);
      await win(4);
      expect(botArena.battleXp, 425);
    });

    test('rewards survive a reload', () async {
      await botArena.ensureLoaded(now: DateTime(2026, 10, 28, 19));
      await botArena.claimDailyWinBonus(112, now: DateTime(2026, 10, 28, 20));
      final fresh = BotArenaStore();
      await fresh.ensureLoaded(now: DateTime(2026, 10, 28, 21));
      expect(fresh.battleXp, 112);
      expect(fresh.lastWinDay, '2026-10-28');
      expect(fresh.rewards.totalBonusXp, 112);
      final again = await fresh.claimDailyWinBonus(
        112,
        now: DateTime(2026, 10, 28, 22),
      );
      expect(again, 0);
    });

    test('streak bonus lands on the league row and in the feed', () async {
      await botArena.ensureLoaded(now: DateTime(2026, 10, 28, 19));
      final bot = botArena.roster.first;
      Future<void> win(int i) => botArena.recordBattle(
        record: BattleRecord(
          id: 'battle:row-$i',
          at: DateTime(2026, 10, 28, 20, i),
          opponent: bot.name,
          opponentRating: bot.rating,
          duel: true,
          kind: 1,
          playerScore: 320,
          foeScore: 240,
          rounds: const [],
          roundLines: const [],
          delta: 10,
          xp: 100,
        ),
        outcome: BattleOutcome.win,
        botIds: [bot.id],
      );
      await win(1);
      await win(2);
      await win(3);
      expect(botArena.season!.playerEntry!.xp, 325);
      final streakEvents = [
        for (final e in botArena.feed)
          if (e.kind == FeedKind.streak) e,
      ];
      expect(streakEvents, hasLength(1));
      expect(streakEvents.first.xpDelta, 25);
      expect(streakEvents.first.text, contains('+25 XP'));
    });

    test('daily bonus lands on the league row and in the feed', () async {
      await botArena.ensureLoaded(now: DateTime(2026, 10, 28, 19));
      final before = botArena.season!.playerEntry!.xp;
      final bonus = await botArena.claimDailyWinBonus(
        112,
        now: DateTime(2026, 10, 28, 20),
      );
      expect(bonus, 112);
      expect(botArena.season!.playerEntry!.xp, before + 112);
      expect(
        botArena.feed.any(
          (e) => e.text.contains('First win of the day') && e.xpDelta == 112,
        ),
        isTrue,
      );
    });

    test('season rewards land on the league row and in the feed', () async {
      await botArena.ensureLoaded(now: DateTime(2026, 10, 28, 19));
      final before = botArena.season!.playerEntry!.xp;
      final total = await botArena.applySeasonRewards(
        seasonId: '2026-10-26',
        playerRank: 2,
        oldTierIndex: 1,
        newTierIndex: 2,
        now: DateTime(2026, 11, 2, 9),
      );
      expect(total, 200);
      expect(botArena.season!.playerEntry!.xp, before + 200);
      final promos = [
        for (final e in botArena.feed)
          if (e.kind == FeedKind.promotion) e,
      ];
      expect(promos, hasLength(2));
      expect(promos.map((e) => e.xpDelta), containsAll([100, 100]));
    });

    test('rollover pays season rewards exactly once', () async {
      final monday = DateTime(2026, 10, 26, 10);
      await botArena.ensureLoaded(now: monday);
      final boosted = addPlayerBattleXp(botArena.season!, 99999);
      await MemoryStore.saveLeagueSeasonWithoutNotify(boosted);
      botArena.resetForTest();
      final nextMonday = monday.add(const Duration(days: 7, hours: 1));
      await botArena.ensureLoaded(now: nextMonday);
      // Rank 1 promotes: 150 rank bonus + 100 tier bonus.
      expect(botArena.battleXp, 250);
      expect(botArena.rewards.bonusFor(RewardKind.weekly), 150);
      expect(botArena.rewards.bonusFor(RewardKind.tier), 100);
      expect(
        botArena.feed.where((e) => e.kind == FeedKind.promotion),
        hasLength(2),
      );
      final second = BotArenaStore();
      await second.ensureLoaded(now: nextMonday.add(const Duration(hours: 2)));
      expect(second.battleXp, 250);
      expect(second.rewards.totalBonusXp, 250);
    });

    test('stats and history survive a reload', () async {
      await botArena.ensureLoaded(now: DateTime(2026, 10, 28, 19));
      final bot = botArena.roster.first;
      BattleRecord record(String id, int minute, {required bool won}) =>
          BattleRecord(
            id: id,
            at: DateTime(2026, 10, 28, 20, minute),
            opponent: bot.name,
            opponentRating: bot.rating,
            duel: true,
            kind: 1,
            playerScore: won ? 320 : 180,
            foeScore: won ? 240 : 300,
            rounds: const [],
            roundLines: const [],
            delta: won ? 12 : -10,
            xp: won ? 112 : 30,
            decidedOutcome: won ? BattleOutcome.win : BattleOutcome.loss,
          );
      await botArena.recordBattle(
        record: record('battle:persist-1', 1, won: true),
        outcome: BattleOutcome.win,
        botIds: [bot.id],
      );
      await botArena.recordBattle(
        record: record('battle:persist-2', 2, won: false),
        outcome: BattleOutcome.loss,
        botIds: [bot.id],
      );
      final fresh = BotArenaStore();
      await fresh.ensureLoaded(now: DateTime(2026, 10, 28, 21));
      expect(fresh.stats.matches, 2);
      expect(fresh.stats.wins, 1);
      expect(fresh.stats.losses, 1);
      expect(fresh.battleXp, 142);
      expect(
        [for (final r in fresh.history) r.id],
        containsAll(['battle:persist-1', 'battle:persist-2']),
      );
      expect(fresh.headToHead(bot.name).wins, 1);
      expect(fresh.headToHead(bot.name).losses, 1);
      expect(
        fresh.feed.where((e) => e.kind == FeedKind.battle),
        isNotEmpty,
      );
    });

    test('stored outcome beats score math and survives JSON', () {
      final tied = BattleRecord(
        id: 'battle:tied',
        at: DateTime(2026, 10, 28, 20),
        opponent: 'Nora',
        opponentRating: 1000,
        duel: true,
        kind: 1,
        playerScore: 250,
        foeScore: 250,
        rounds: const [],
        roundLines: const [],
        delta: 4,
        xp: 100,
        decidedOutcome: BattleOutcome.win,
      );
      expect(tied.outcome, BattleOutcome.win);
      final back = BattleRecord.fromJson(tied.toJson());
      expect(back.outcome, BattleOutcome.win);
      final legacy = BattleRecord.fromJson({
        'id': 'battle:legacy',
        'at': '2026-10-28T20:00:00.000',
        'opponent': 'Nora',
        'opponentRating': 1000,
        'duel': true,
        'kind': 1,
        'playerScore': 250,
        'foeScore': 250,
        'rounds': [],
        'roundLines': [],
        'delta': 0,
        'xp': 60,
      });
      expect(legacy.outcome, BattleOutcome.draw);
    });
  });
}
