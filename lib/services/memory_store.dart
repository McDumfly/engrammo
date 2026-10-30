import 'dart:async';
import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/assessment.dart' show assessmentProbeCount;
import '../models/battle_bot.dart';
import '../models/battle_match.dart';
import '../models/battle_rewards.dart';
import '../models/friend_social.dart';
import '../models/league_season.dart';
import '../models/marathon.dart' show maxStoredReps;
import '../models/norms.dart' show LocalNorm, maxStoredRuns;
import '../models/user_goals.dart';
import '../utils/streak_restore.dart';
import '../utils/streak_utils.dart';

class StreakState {
  final List<DateTime> history;
  final int streak;
  final int bestStreak;
  final int engrams;
  const StreakState({
    required this.history,
    required this.streak,
    required this.bestStreak,
    required this.engrams,
  });
}

/// Practice-hub totals shared by the benchmark screen, local storage and
/// Firestore. Attempt lists are newest-last and capped at 30 entries.
class BenchmarkState {
  final Map<String, int> best;
  final Map<String, List<int>> attempts;
  final int xp;
  final int plays;
  final bool bonusClaimed;

  const BenchmarkState({
    this.best = const {},
    this.attempts = const {},
    this.xp = 0,
    this.plays = 0,
    this.bonusClaimed = false,
  });

  Map<String, dynamic> toJson() => {
    'best': best,
    'attempts': attempts,
    'xp': xp,
    'plays': plays,
    'bonusClaimed': bonusClaimed,
  };

  factory BenchmarkState.fromJson(Map<String, dynamic> json) {
    final best = <String, int>{};
    final rawBest = json['best'];
    if (rawBest is Map) {
      rawBest.forEach((k, v) {
        final key = k.toString();
        final score = (v as num?)?.toInt();
        if (key.isNotEmpty && score != null) best[key] = score;
      });
    }
    final attempts = <String, List<int>>{};
    final rawAttempts = json['attempts'];
    if (rawAttempts is Map) {
      rawAttempts.forEach((k, v) {
        final key = k.toString();
        if (key.isEmpty || v is! List) return;
        final list = [
          for (final e in v) (e as num?)?.toInt() ?? 0,
        ];
        attempts[key] = list.length > MemoryStore.benchmarkAttemptsCap
            ? list.sublist(list.length - MemoryStore.benchmarkAttemptsCap)
            : list;
      });
    }
    return BenchmarkState(
      best: best,
      attempts: attempts,
      xp: (json['xp'] as num?)?.toInt() ?? 0,
      plays: (json['plays'] as num?)?.toInt() ?? 0,
      bonusClaimed: json['bonusClaimed'] == true,
    );
  }
}

class MemoryStore {
  static const _scoresKey = 'memory_scores_v1';
  static const _dominantKindKey = 'dominant_kind_v1';
  static const _dominantMetaKey = 'dominant_meta_v1';
  static const _battleKindKey = 'battle_memory_kind_v1';
  static const _battleRatingKey = 'battle_rating_v1';
  static const _avatarOptsKey = 'avatar_opts_v1';

  /// Session-level copy of the last avatar options seen through load/save.
  /// The profile page seeds from here so navbar re-entries paint the cached
  /// avatar instantly instead of flashing the defaults first.
  static Map<String, String>? _avatarOptsMemory;

  /// Last avatar options seen in this session, or null when unknown.
  /// Returns a copy; callers may mutate the result freely.
  static Map<String, String>? get lastAvatarOpts {
    final cached = _avatarOptsMemory;
    return cached == null ? null : Map<String, String>.of(cached);
  }

  /// Session-level copies of the profile-screen data seen through load/save.
  /// The profile page seeds from here so re-entries paint instantly, then
  /// the background loads revalidate and patch only on real change.
  static ({String displayName, String username, String email})? _profileMemory;
  static List<int>? _scoresMemory;
  static int? _dominantKindMemory;
  static StreakState? _streakMemory;
  static int? _battleRatingMemory;
  static int? _battleXpMemory;

  /// Last profile seen in this session, or null when unknown.
  static ({String displayName, String username, String email})? get lastProfile =>
      _profileMemory;

  /// Last scores seen in this session, or null when unknown.
  /// Returns a copy; callers may mutate the result freely.
  static List<int>? get lastScores {
    final cached = _scoresMemory;
    return cached == null ? null : List<int>.of(cached);
  }

  /// Last dominant memory kind seen in this session, or null when unknown.
  static int? get lastDominantKind => _dominantKindMemory;

  /// Last streak state seen in this session, or null when unknown.
  /// Returns a copy; callers may mutate the result freely.
  static StreakState? get lastStreakState {
    final cached = _streakMemory;
    if (cached == null) return null;
    return StreakState(
      history: List<DateTime>.of(cached.history),
      streak: cached.streak,
      bestStreak: cached.bestStreak,
      engrams: cached.engrams,
    );
  }

  /// Last battle rating seen in this session, or null when unknown.
  static int? get lastBattleRating => _battleRatingMemory;

  /// Last battle XP seen in this session, or null when unknown.
  static int? get lastBattleXp => _battleXpMemory;

  /// Drops every session-level copy without touching storage.
  /// Used on sign-out (via [clearAccountData]) and by tests for isolation.
  static void clearMemoryCache() {
    _avatarOptsMemory = null;
    _profileMemory = null;
    _scoresMemory = null;
    _dominantKindMemory = null;
    _streakMemory = null;
    _battleRatingMemory = null;
    _battleXpMemory = null;
  }
  static const _profileNameKey = 'profile_display_name_v1';
  static const _profileUsernameKey = 'profile_username_v1';
  static const _profileEmailKey = 'profile_email_v1';
  static const _profileSetupDoneKey = 'profile_setup_done_v1';
  static const _chapterProgressKey = 'chapter_progress_v1';
  static const _onboardingDoneKey = 'onboarding_done_v1';
  static const _assessmentRunsKey = 'assessment_runs_v1';
  static const _botRosterKey = 'bot_roster_v1';
  static const _battleHistoryKey = 'battle_history_v1';
  static const _battleStatsKey = 'battle_stats_v1';
  static const _battleXpKey = 'battle_xp_v1';
  static const _battleRewardsKey = 'battle_rewards_v1';
  static const _battleLastWinDayKey = 'battle_last_win_day_v1';
  static const _leagueSeasonKey = 'league_season_v1';
  static const _leagueHistoryKey = 'league_history_v1';
  static const _friendsGraphKey = 'friends_graph_v1';
  static const _friendsFeedKey = 'friends_feed_v1';
  static const _missionsDoneKey = 'transfer_missions_done_v1';
  static const _ownMaterialKey = 'own_material_v1';
  static const _userGoalsKey = 'user_goals_v1';
  static const _localNormsKey = 'local_norms_v1';
  static const _assessmentRunsDataKey = 'assessment_runs_data_v1';
  static const _benchmarkKey = 'benchmark_state_v1';
  static const _battleInvitesKey = 'battle_invites_v1';

  static Future<void> Function()? onChanged;

  static void _notifyChanged() {
    final cb = onChanged;
    if (cb != null) unawaited(cb());
  }

  static Future<void> saveScores(List<int> scores) async {
    await saveScoresWithoutNotify(scores);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(
      _assessmentRunsKey,
      (prefs.getInt(_assessmentRunsKey) ?? 0) + 1,
    );
    _notifyChanged();
  }

  static Future<int> loadAssessmentRuns() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_assessmentRunsKey) ?? 0;
  }

  static Future<void> saveScoresWithoutNotify(List<int> scores) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_scoresKey, [
      for (final s in scores) s.toString(),
    ]);
    _scoresMemory = List<int>.of(scores);
  }

  static Future<List<int>?> loadScores() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(_scoresKey);
    if (raw == null || raw.isEmpty) {
      _scoresMemory = null;
      return null;
    }
    final scores = [for (final s in raw) int.tryParse(s) ?? 0];
    _scoresMemory = List<int>.of(scores);
    return scores;
  }

  static int strongestKind(List<int>? scores) {
    if (scores == null || scores.isEmpty) return 0;
    var best = 0;
    for (var i = 1; i < scores.length; i++) {
      if (scores[i] > scores[best]) best = i;
    }
    return best;
  }

  static int? strongestKindOrNull(List<int>? scores) {
    if (scores == null || scores.isEmpty) return null;
    return strongestKind(scores);
  }

  static Future<int?> loadDominantKind() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final kind = prefs.getInt(_dominantKindKey);
      _dominantKindMemory = kind;
      return kind;
    } catch (_) {
      return _dominantKindMemory;
    }
  }

  static Future<Map<String, String>> loadDominantMeta() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getStringList(_dominantMetaKey);
      if (raw == null || raw.isEmpty) return {};
      final map = <String, String>{};
      for (final e in raw) {
        final i = e.indexOf('=');
        if (i <= 0) continue;
        map[e.substring(0, i)] = e.substring(i + 1);
      }
      return map;
    } catch (_) {
      return {};
    }
  }

  static Future<void> saveDominantKind(
    int kind, {
    String rationale = '',
    required bool ai,
  }) async {
    await saveDominantKindWithoutNotify(kind, rationale: rationale, ai: ai);
    _notifyChanged();
  }

  static Future<void> saveDominantKindWithoutNotify(
    int kind, {
    String rationale = '',
    required bool ai,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(_dominantKindKey, kind);
      await prefs.setStringList(_dominantMetaKey, [
        'rationale=${rationale.replaceAll('\n', ' ')}',
        'source=${ai ? 'ai' : 'local'}',
        'at=${DateTime.now().toIso8601String()}',
      ]);
      _dominantKindMemory = kind;
    } catch (_) {
    }
  }

  static Future<bool> loadOnboardingDone() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getBool(_onboardingDoneKey) ?? false;
    } catch (_) {
      return false;
    }
  }

  static Future<void> saveOnboardingDone() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_onboardingDoneKey, true);
    } catch (_) {
    }
  }

  static Future<int?> loadBattleKind() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_battleKindKey);
  }

  static Future<void> saveBattleKind(int kind) async {
    await saveBattleKindWithoutNotify(kind);
    _notifyChanged();
  }

  static Future<void> saveBattleKindWithoutNotify(int kind) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_battleKindKey, kind);
  }

  static Future<int> loadBattleRating({int defaultRating = 1000}) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getInt(_battleRatingKey);
    final rating = raw == null ? defaultRating : (raw < 0 ? 0 : raw);
    _battleRatingMemory = rating;
    return rating;
  }

  static Future<void> saveBattleRating(int rating) async {
    await saveBattleRatingWithoutNotify(rating);
    _notifyChanged();
  }

  static Future<void> saveBattleRatingWithoutNotify(int rating) async {
    final prefs = await SharedPreferences.getInstance();
    final kept = rating < 0 ? 0 : rating;
    await prefs.setInt(_battleRatingKey, kept);
    _battleRatingMemory = kept;
  }

  static const int botRosterCap = 60;
  static const int battleHistoryCap = 20;
  static const int leagueHistoryCap = 8;
  static const int friendsFeedCap = 50;
  static const int friendsGraphCap = 100;

  static Future<List<BotPersona>> loadBotRoster() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getStringList(_botRosterKey);
      if (raw == null || raw.isEmpty) return [];
      final out = <BotPersona>[];
      for (final e in raw) {
        if (e.isEmpty) continue;
        try {
          final data = jsonDecode(e);
          if (data is Map<String, dynamic>) {
            final bot = BotPersona.fromJson(data);
            if (bot.id.isNotEmpty) out.add(bot);
          }
        } catch (_) {}
      }
      return out;
    } catch (_) {
      return [];
    }
  }

  static Future<void> saveBotRoster(List<BotPersona> roster) async {
    await saveBotRosterWithoutNotify(roster);
    _notifyChanged();
  }

  static Future<void> saveBotRosterWithoutNotify(
    List<BotPersona> roster,
  ) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final capped = roster.length > botRosterCap
          ? roster.sublist(0, botRosterCap)
          : roster;
      await prefs.setStringList(_botRosterKey, [
        for (final b in capped) jsonEncode(b.toJson()),
      ]);
    } catch (_) {}
  }

  static Future<List<BattleRecord>> loadBattleHistory() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getStringList(_battleHistoryKey);
      if (raw == null || raw.isEmpty) return [];
      final out = <BattleRecord>[];
      for (final e in raw) {
        if (e.isEmpty) continue;
        try {
          final data = jsonDecode(e);
          if (data is Map<String, dynamic>) {
            final record = BattleRecord.fromJson(data);
            if (record.id.isNotEmpty) out.add(record);
          }
        } catch (_) {}
      }
      out.sort((a, b) => b.at.compareTo(a.at));
      return out;
    } catch (_) {
      return [];
    }
  }

  static Future<void> saveBattleHistory(List<BattleRecord> history) async {
    await saveBattleHistoryWithoutNotify(history);
    _notifyChanged();
  }

  static Future<void> saveBattleHistoryWithoutNotify(
    List<BattleRecord> history,
  ) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final sorted = List<BattleRecord>.of(history)
        ..sort((a, b) => b.at.compareTo(a.at));
      final capped = sorted.length > battleHistoryCap
          ? sorted.sublist(0, battleHistoryCap)
          : sorted;
      await prefs.setStringList(_battleHistoryKey, [
        for (final r in capped) jsonEncode(r.toJson()),
      ]);
    } catch (_) {}
  }

  static Future<BattleStats> loadBattleStats() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_battleStatsKey);
      if (raw == null || raw.isEmpty) return const BattleStats();
      final data = jsonDecode(raw);
      if (data is Map<String, dynamic>) return BattleStats.fromJson(data);
      return const BattleStats();
    } catch (_) {
      return const BattleStats();
    }
  }

  static Future<void> saveBattleStats(BattleStats stats) async {
    await saveBattleStatsWithoutNotify(stats);
    _notifyChanged();
  }

  static Future<void> saveBattleStatsWithoutNotify(BattleStats stats) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_battleStatsKey, jsonEncode(stats.toJson()));
    } catch (_) {}
  }

  static Future<int> loadBattleXp() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final xp = prefs.getInt(_battleXpKey) ?? 0;
      _battleXpMemory = xp;
      return xp;
    } catch (_) {
      return _battleXpMemory ?? 0;
    }
  }

  static Future<void> saveBattleXp(int xp) async {
    await saveBattleXpWithoutNotify(xp);
    _notifyChanged();
  }

  static Future<void> saveBattleXpWithoutNotify(int xp) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final kept = xp < 0 ? 0 : xp;
      await prefs.setInt(_battleXpKey, kept);
      _battleXpMemory = kept;
    } catch (_) {}
  }

  static Future<BattleRewardState> loadBattleRewards() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_battleRewardsKey);
      if (raw == null || raw.isEmpty) return const BattleRewardState();
      final data = jsonDecode(raw);
      if (data is Map<String, dynamic>) return BattleRewardState.fromJson(data);
      return const BattleRewardState();
    } catch (_) {
      return const BattleRewardState();
    }
  }

  static Future<void> saveBattleRewards(BattleRewardState state) async {
    await saveBattleRewardsWithoutNotify(state);
    _notifyChanged();
  }

  static Future<void> saveBattleRewardsWithoutNotify(
    BattleRewardState state,
  ) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_battleRewardsKey, jsonEncode(state.toJson()));
    } catch (_) {}
  }

  static Future<String> loadBattleLastWinDay() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString(_battleLastWinDayKey) ?? '';
    } catch (_) {
      return '';
    }
  }

  static Future<void> saveBattleLastWinDay(String day) async {
    await saveBattleLastWinDayWithoutNotify(day);
    _notifyChanged();
  }

  static Future<void> saveBattleLastWinDayWithoutNotify(String day) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_battleLastWinDayKey, day);
    } catch (_) {}
  }

  static Future<LeagueSeason?> loadLeagueSeason() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_leagueSeasonKey);
      if (raw == null || raw.isEmpty) return null;
      final data = jsonDecode(raw);
      if (data is! Map<String, dynamic>) return null;
      final season = LeagueSeason.fromJson(data);
      if (season.entries.isEmpty) return null;
      return season;
    } catch (_) {
      return null;
    }
  }

  static Future<void> saveLeagueSeason(LeagueSeason season) async {
    await saveLeagueSeasonWithoutNotify(season);
    _notifyChanged();
  }

  static Future<void> saveLeagueSeasonWithoutNotify(
    LeagueSeason season,
  ) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_leagueSeasonKey, jsonEncode(season.toJson()));
    } catch (_) {}
  }

  static Future<List<LeagueSummary>> loadLeagueHistory() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getStringList(_leagueHistoryKey);
      if (raw == null || raw.isEmpty) return [];
      final out = <LeagueSummary>[];
      for (final e in raw) {
        if (e.isEmpty) continue;
        try {
          final data = jsonDecode(e);
          if (data is Map<String, dynamic>) {
            final summary = LeagueSummary.fromJson(data);
            if (summary.seasonId.isNotEmpty) out.add(summary);
          }
        } catch (_) {}
      }
      return out;
    } catch (_) {
      return [];
    }
  }

  static Future<void> saveLeagueHistory(List<LeagueSummary> history) async {
    await saveLeagueHistoryWithoutNotify(history);
    _notifyChanged();
  }

  static Future<void> saveLeagueHistoryWithoutNotify(
    List<LeagueSummary> history,
  ) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final capped = history.length > leagueHistoryCap
          ? history.sublist(history.length - leagueHistoryCap)
          : history;
      await prefs.setStringList(_leagueHistoryKey, [
        for (final s in capped) jsonEncode(s.toJson()),
      ]);
    } catch (_) {}
  }

  static Future<List<FriendEdge>> loadFriendGraph() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getStringList(_friendsGraphKey);
      if (raw == null || raw.isEmpty) return [];
      final out = <FriendEdge>[];
      for (final e in raw) {
        if (e.isEmpty) continue;
        try {
          final data = jsonDecode(e);
          if (data is Map<String, dynamic>) {
            final edge = FriendEdge.fromJson(data);
            if (edge.botId.isNotEmpty) out.add(edge);
          }
        } catch (_) {}
      }
      out.sort((a, b) => b.addedAt.compareTo(a.addedAt));
      return out;
    } catch (_) {
      return [];
    }
  }

  static Future<void> saveFriendGraph(List<FriendEdge> edges) async {
    await saveFriendGraphWithoutNotify(edges);
    _notifyChanged();
  }

  static Future<void> saveFriendGraphWithoutNotify(
    List<FriendEdge> edges,
  ) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final sorted = List<FriendEdge>.of(edges)
        ..sort((a, b) => b.addedAt.compareTo(a.addedAt));
      final capped = sorted.length > friendsGraphCap
          ? sorted.sublist(0, friendsGraphCap)
          : sorted;
      await prefs.setStringList(_friendsGraphKey, [
        for (final e in capped) jsonEncode(e.toJson()),
      ]);
    } catch (_) {}
  }

  static Future<List<FeedEvent>> loadFriendFeed() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getStringList(_friendsFeedKey);
      if (raw == null || raw.isEmpty) return [];
      final out = <FeedEvent>[];
      for (final e in raw) {
        if (e.isEmpty) continue;
        try {
          final data = jsonDecode(e);
          if (data is Map<String, dynamic>) {
            final event = FeedEvent.fromJson(data);
            if (event.id.isNotEmpty) out.add(event);
          }
        } catch (_) {}
      }
      out.sort((a, b) => b.at.compareTo(a.at));
      return out;
    } catch (_) {
      return [];
    }
  }

  static Future<void> saveFriendFeed(List<FeedEvent> feed) async {
    await saveFriendFeedWithoutNotify(feed);
    _notifyChanged();
  }

  static Future<void> saveFriendFeedWithoutNotify(List<FeedEvent> feed) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final sorted = List<FeedEvent>.of(feed)
        ..sort((a, b) => b.at.compareTo(a.at));
      final capped = sorted.length > friendsFeedCap
          ? sorted.sublist(0, friendsFeedCap)
          : sorted;
      await prefs.setStringList(_friendsFeedKey, [
        for (final e in capped) jsonEncode(e.toJson()),
      ]);
    } catch (_) {}
  }

  static Future<void> saveAvatarOpts(Map<String, String> opts) async {
    await saveAvatarOptsWithoutNotify(opts);
    _notifyChanged();
  }

  static Future<void> saveAvatarOptsWithoutNotify(
    Map<String, String> opts,
  ) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(_avatarOptsKey, [
        for (final e in opts.entries) '${e.key}=${e.value}',
      ]);
      _avatarOptsMemory = Map<String, String>.of(opts);
    } catch (_) {
    }
  }

  static Future<({String displayName, String username, String email})>
  loadProfile() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final profile = (
        displayName: prefs.getString(_profileNameKey) ?? '',
        username: prefs.getString(_profileUsernameKey) ?? '',
        email: prefs.getString(_profileEmailKey) ?? '',
      );
      _profileMemory = profile;
      return profile;
    } catch (_) {
      return _profileMemory ?? (displayName: '', username: '', email: '');
    }
  }

  static Future<void> saveProfile({
    required String displayName,
    required String username,
    required String email,
  }) async {
    await saveProfileWithoutNotify(
      displayName: displayName,
      username: username,
      email: email,
    );
    _notifyChanged();
  }

  static Future<void> saveProfileWithoutNotify({
    required String displayName,
    required String username,
    required String email,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_profileNameKey, displayName);
      await prefs.setString(_profileUsernameKey, username);
      await prefs.setString(_profileEmailKey, email);
      _profileMemory = (
        displayName: displayName,
        username: username,
        email: email,
      );
    } catch (_) {
    }
  }

  static Future<bool> isProfileSetupDone(String uid) async {
    if (uid.isEmpty) return false;
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString(_profileSetupDoneKey) == uid;
    } catch (_) {
      return false;
    }
  }

  static Future<void> markProfileSetupDone(String uid) async {
    await markProfileSetupDoneWithoutNotify(uid);
    _notifyChanged();
  }

  static Future<void> markProfileSetupDoneWithoutNotify(String uid) async {
    if (uid.isEmpty) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_profileSetupDoneKey, uid);
    } catch (_) {
    }
  }

  static String lessonKey(int chapter, int section, int lesson) =>
      '$chapter-$section-$lesson';

  static Future<Map<String, int>> loadChapterProgress() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getStringList(_chapterProgressKey);
      if (raw == null || raw.isEmpty) return {};
      final map = <String, int>{};
      for (final e in raw) {
        final i = e.indexOf('=');
        if (i <= 0) continue;
        final stars = int.tryParse(e.substring(i + 1)) ?? 0;
        map[e.substring(0, i)] = stars.clamp(0, 3);
      }
      return map;
    } catch (_) {
      return {};
    }
  }

  static Future<void> saveChapterProgress(Map<String, int> progress) async {
    await saveChapterProgressWithoutNotify(progress);
    _notifyChanged();
  }

  static Future<void> saveChapterProgressWithoutNotify(
    Map<String, int> progress,
  ) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(_chapterProgressKey, [
        for (final e in progress.entries) '${e.key}=${e.value.clamp(0, 3)}',
      ]);
    } catch (_) {
    }
  }

  static Future<void> saveLessonStars({
    required int chapter,
    required int section,
    required int lesson,
    required int stars,
  }) async {
    final progress = await loadChapterProgress();
    final key = lessonKey(chapter, section, lesson);
    final kept = progress[key] ?? 0;
    final next = stars.clamp(0, 3);
    progress[key] = next > kept ? next : kept;
    await saveChapterProgress(progress);
  }

  static Future<void> saveLessonStarsWithoutNotify({
    required int chapter,
    required int section,
    required int lesson,
    required int stars,
  }) async {
    final progress = await loadChapterProgress();
    final key = lessonKey(chapter, section, lesson);
    final kept = progress[key] ?? 0;
    final next = stars.clamp(0, 3);
    progress[key] = next > kept ? next : kept;
    await saveChapterProgressWithoutNotify(progress);
  }

  static const _lessonRepsKey = 'lesson_reps_v1';
  static const _trackMinutesKey = 'track_minutes_v1';
  static const _lessonDoneKey = 'lesson_done_v1';

  static Future<Map<String, int>> loadLessonReps() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getStringList(_lessonRepsKey);
      if (raw == null || raw.isEmpty) return {};
      final map = <String, int>{};
      for (final e in raw) {
        final i = e.indexOf('=');
        if (i <= 0) continue;
        map[e.substring(0, i)] =
            (int.tryParse(e.substring(i + 1)) ?? 0).clamp(0, maxStoredReps);
      }
      return map;
    } catch (_) {
      return {};
    }
  }

  static Future<void> saveLessonReps(Map<String, int> reps) async {
    await saveLessonRepsWithoutNotify(reps);
    _notifyChanged();
  }

  static Future<void> saveLessonRepsWithoutNotify(
    Map<String, int> reps,
  ) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(_lessonRepsKey, [
        for (final e in reps.entries)
          '${e.key}=${e.value.clamp(0, maxStoredReps)}',
      ]);
    } catch (_) {
    }
  }

  static Future<Map<String, int>> loadTrackMinutes() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getStringList(_trackMinutesKey);
      if (raw == null || raw.isEmpty) return {};
      final map = <String, int>{};
      for (final e in raw) {
        final i = e.indexOf('=');
        if (i <= 0) continue;
        map[e.substring(0, i)] = (int.tryParse(e.substring(i + 1)) ?? 0)
            .clamp(0, 1 << 30);
      }
      return map;
    } catch (_) {
      return {};
    }
  }

  static Future<void> saveTrackMinutes(Map<String, int> minutes) async {
    await saveTrackMinutesWithoutNotify(minutes);
    _notifyChanged();
  }

  static Future<void> saveTrackMinutesWithoutNotify(
    Map<String, int> minutes,
  ) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(_trackMinutesKey, [
        for (final e in minutes.entries)
          '${e.key}=${e.value.clamp(0, 1 << 30)}',
      ]);
    } catch (_) {
    }
  }

  static Future<Map<String, DateTime>> loadLessonDoneDates() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getStringList(_lessonDoneKey);
      if (raw == null || raw.isEmpty) return {};
      final map = <String, DateTime>{};
      for (final e in raw) {
        final i = e.indexOf('=');
        if (i <= 0) continue;
        final at = DateTime.tryParse(e.substring(i + 1));
        if (at != null) map[e.substring(0, i)] = at;
      }
      return map;
    } catch (_) {
      return {};
    }
  }

  static Future<void> saveLessonDoneDates(Map<String, DateTime> dates) async {
    await saveLessonDoneDatesWithoutNotify(dates);
    _notifyChanged();
  }

  static Future<void> saveLessonDoneDatesWithoutNotify(
    Map<String, DateTime> dates,
  ) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(_lessonDoneKey, [
        for (final e in dates.entries) '${e.key}=${e.value.toIso8601String()}',
      ]);
    } catch (_) {
    }
  }

  static Future<void> recordLessonSession({
    required int track,
    required int chapter,
    required int section,
    required int lesson,
    required int minutes,
    DateTime? now,
  }) async {
    await recordLessonSessionWithoutNotify(
      track: track,
      chapter: chapter,
      section: section,
      lesson: lesson,
      minutes: minutes,
      now: now,
    );
    _notifyChanged();
  }

  static Future<void> recordLessonSessionWithoutNotify({
    required int track,
    required int chapter,
    required int section,
    required int lesson,
    required int minutes,
    DateTime? now,
  }) async {
    final key = lessonKey(chapter, section, lesson);
    final reps = await loadLessonReps();
    reps[key] = ((reps[key] ?? 0) + 1).clamp(0, maxStoredReps);
    await saveLessonRepsWithoutNotify(reps);
    final doses = await loadTrackMinutes();
    final slot = track.clamp(0, 5).toString();
    doses[slot] = ((doses[slot] ?? 0) + minutes.clamp(1, 240))
        .clamp(0, 1 << 30);
    await saveTrackMinutesWithoutNotify(doses);
    final dates = await loadLessonDoneDates();
    dates[key] = now ?? DateTime.now();
    await saveLessonDoneDatesWithoutNotify(dates);
  }

  static Future<Set<String>> loadDoneMissions() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getStringList(_missionsDoneKey);
      if (raw == null || raw.isEmpty) return {};
      return raw.toSet();
    } catch (_) {
      return {};
    }
  }

  static Future<void> saveMissionDone(String missionId, {bool done = true}) async {
    await saveMissionDoneWithoutNotify(missionId, done: done);
    _notifyChanged();
  }

  static Future<void> saveMissionDoneWithoutNotify(
    String missionId, {
    bool done = true,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final current =
          prefs.getStringList(_missionsDoneKey)?.toSet() ?? <String>{};
      if (done) {
        current.add(missionId);
      } else {
        current.remove(missionId);
      }
      await prefs.setStringList(_missionsDoneKey, current.toList()..sort());
    } catch (_) {
    }
  }

  static Future<void> saveDoneMissionsWithoutNotify(Set<String> done) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(_missionsDoneKey, done.toList()..sort());
    } catch (_) {
    }
  }

  static Future<String> loadOwnMaterial(String targetId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getStringList(_ownMaterialKey) ?? const [];
      for (final e in raw) {
        final cut = e.indexOf('=');
        if (cut > 0 && e.substring(0, cut) == targetId) {
          return e.substring(cut + 1);
        }
      }
      return '';
    } catch (_) {
      return '';
    }
  }

  static Future<Map<String, String>> loadAllOwnMaterials() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final out = <String, String>{};
      for (final e in prefs.getStringList(_ownMaterialKey) ?? const []) {
        final cut = e.indexOf('=');
        if (cut > 0) out[e.substring(0, cut)] = e.substring(cut + 1);
      }
      return out;
    } catch (_) {
      return {};
    }
  }

  static Future<void> saveOwnMaterial(String targetId, String text) async {
    await saveOwnMaterialWithoutNotify(targetId, text);
    _notifyChanged();
  }

  static Future<void> saveOwnMaterialWithoutNotify(
    String targetId,
    String text,
  ) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final rest = <String>[
        for (final e in prefs.getStringList(_ownMaterialKey) ?? const [])
          if (!(e.startsWith('$targetId='))) e,
      ];
      if (text.trim().isNotEmpty) rest.add('$targetId=${text.trim()}');
      await prefs.setStringList(_ownMaterialKey, rest);
    } catch (_) {
    }
  }

  static Future<void> saveAllOwnMaterialsWithoutNotify(
    Map<String, String> materials,
  ) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(_ownMaterialKey, [
        for (final e in materials.entries)
          if (e.key.isNotEmpty && e.value.trim().isNotEmpty)
            '${e.key}=${e.value.trim()}',
      ]);
    } catch (_) {
    }
  }

  static const int userGoalsCap = 50;

  static Future<List<UserGoal>> loadUserGoals() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getStringList(_userGoalsKey);
      if (raw == null || raw.isEmpty) return [];
      final goals = <UserGoal>[];
      for (final e in raw) {
        if (e.isEmpty) continue;
        try {
          final data = jsonDecode(e);
          if (data is Map<String, dynamic>) {
            final goal = UserGoal.fromJson(data);
            if (goal.id.isNotEmpty && goal.title.trim().isNotEmpty) {
              goals.add(goal);
            }
          }
        } catch (_) {
        }
      }
      goals.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
      return goals;
    } catch (_) {
      return [];
    }
  }

  static Future<void> saveUserGoals(List<UserGoal> goals) async {
    await saveUserGoalsWithoutNotify(goals);
    _notifyChanged();
  }

  static Future<void> saveUserGoalsWithoutNotify(List<UserGoal> goals) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final sorted = List<UserGoal>.of(goals)
        ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
      final capped = sorted.length > userGoalsCap
          ? sorted.sublist(0, userGoalsCap)
          : sorted;
      await prefs.setStringList(_userGoalsKey, [
        for (final g in capped) jsonEncode(g.toJson()),
      ]);
    } catch (_) {
    }
  }

  static Future<List<UserGoal>> addUserGoal(UserGoal goal) async {
    final goals = await loadUserGoals();
    goals.removeWhere((g) => g.id == goal.id);
    goals.add(goal);
    await saveUserGoals(goals);
    return loadUserGoals();
  }

  static Future<List<UserGoal>> updateUserGoal(UserGoal goal) async {
    final goals = await loadUserGoals();
    var found = false;
    for (var i = 0; i < goals.length; i++) {
      if (goals[i].id == goal.id) {
        goals[i] = goal;
        found = true;
      }
    }
    if (!found) goals.add(goal);
    await saveUserGoals(goals);
    return loadUserGoals();
  }

  static Future<List<UserGoal>> deleteUserGoal(String goalId) async {
    final goals = await loadUserGoals();
    goals.removeWhere((g) => g.id == goalId);
    await saveUserGoals(goals);
    return loadUserGoals();
  }

  static Future<UserGoal?> loadUserGoal(String goalId) async {
    final goals = await loadUserGoals();
    for (final g in goals) {
      if (g.id == goalId) return g;
    }
    return null;
  }

  static Future<UserGoal?> recordGoalPractice(String goalId) async {
    final goal = await loadUserGoal(goalId);
    if (goal == null) return null;
    final now = DateTime.now();
    final next = goal.copyWith(
      practiceCount: goal.practiceCount + 1,
      lastPracticedAt: now,
      updatedAt: now,
    );
    await updateUserGoal(next);
    return next;
  }

  static const int benchmarkAttemptsCap = 30;

  /// Practice-hub totals. Lenient: corrupt rows decode to the empty state,
  /// never throw.
  static Future<BenchmarkState> loadBenchmark() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_benchmarkKey);
      if (raw == null || raw.isEmpty) return const BenchmarkState();
      final data = jsonDecode(raw);
      if (data is! Map<String, dynamic>) return const BenchmarkState();
      return BenchmarkState.fromJson(data);
    } catch (_) {
      return const BenchmarkState();
    }
  }

  static Future<void> saveBenchmark(BenchmarkState state) async {
    await saveBenchmarkWithoutNotify(state);
    _notifyChanged();
  }

  static Future<void> saveBenchmarkWithoutNotify(BenchmarkState state) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_benchmarkKey, jsonEncode(state.toJson()));
    } catch (_) {}
  }

  static Future<Set<String>> loadBattleInvites() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getStringList(_battleInvitesKey);
      if (raw == null || raw.isEmpty) return {};
      return raw.where((e) => e.isNotEmpty).toSet();
    } catch (_) {
      return {};
    }
  }

  static Future<void> saveBattleInvites(Set<String> invited) async {
    await saveBattleInvitesWithoutNotify(invited);
    _notifyChanged();
  }

  static Future<void> saveBattleInvitesWithoutNotify(Set<String> invited) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(
        _battleInvitesKey,
        invited.where((e) => e.isNotEmpty).toList()..sort(),
      );
    } catch (_) {}
  }

  static Future<void> clearAccountData() async {
    clearMemoryCache();
    try {
      final prefs = await SharedPreferences.getInstance();
      for (final key in [
        _scoresKey,
        _dominantKindKey,
        _dominantMetaKey,
        _battleKindKey,
        _battleRatingKey,
        _botRosterKey,
        _battleHistoryKey,
        _battleStatsKey,
        _battleXpKey,
        _battleRewardsKey,
        _battleLastWinDayKey,
        _leagueSeasonKey,
        _leagueHistoryKey,
        _friendsGraphKey,
        _friendsFeedKey,
        _avatarOptsKey,
        _profileNameKey,
        _profileUsernameKey,
        _profileEmailKey,
        _profileSetupDoneKey,
        _chapterProgressKey,
        _lessonRepsKey,
        _trackMinutesKey,
        _lessonDoneKey,
        _assessmentRunsKey,
        _missionsDoneKey,
        _ownMaterialKey,
        _userGoalsKey,
        _fsrsCardsKey,
        _metaCacheKey,
        _benchmarkKey,
        _battleInvitesKey,
      ]) {
        await prefs.remove(key);
      }
    } catch (_) {
    }
  }

  static Future<void> saveStreakStateDirect({
    List<DateTime>? history,
    int? streak,
    int? bestStreak,
    int? engrams,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final current = await loadStreakState();
      await _saveStreakState(
        prefs,
        history: (history == null || history.isEmpty)
            ? current.history
            : history,
        streak: streak ?? current.streak,
        bestStreak: bestStreak ?? current.bestStreak,
        engrams: engrams ?? current.engrams,
      );
    } catch (_) {
    }
  }

  static Future<Map<String, String>> loadAvatarOpts(
    Map<String, String> fallback,
  ) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getStringList(_avatarOptsKey);
      if (raw == null || raw.isEmpty) return fallback;
      final map = Map<String, String>.of(fallback);
      for (final e in raw) {
        final i = e.indexOf('=');
        if (i <= 0) continue;
        map[e.substring(0, i)] = e.substring(i + 1);
      }
      _avatarOptsMemory = Map<String, String>.of(map);
      return map;
    } catch (_) {
      return fallback;
    }
  }

  static const _streakHistoryKey = 'streak_history_v1';
  static const _streakKey = 'streak_v1';
  static const _bestStreakKey = 'best_streak_v1';
  static const _engramsKey = 'engrams_v1';
  static const _restorePromptDayKey = 'restore_prompt_day_v1';

  static const int historyCap = 400;

  static const int engramsPerDay = 20;

  static String todayKey([DateTime? now]) {
    final n = now ?? DateTime.now();
    final m = n.month.toString().padLeft(2, '0');
    final d = n.day.toString().padLeft(2, '0');
    return '${n.year}-$m-$d';
  }

  static Future<StreakState> loadStreakState() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(_streakHistoryKey) ?? const [];
    final state = StreakState(
      history: parseStreakHistory(raw),
      streak: prefs.getInt(_streakKey) ?? 0,
      bestStreak: prefs.getInt(_bestStreakKey) ?? 0,
      engrams: prefs.getInt(_engramsKey) ?? 0,
    );
    _streakMemory = StreakState(
      history: List<DateTime>.of(state.history),
      streak: state.streak,
      bestStreak: state.bestStreak,
      engrams: state.engrams,
    );
    return state;
  }

  static Future<void> _saveStreakState(
    SharedPreferences prefs, {
    required List<DateTime> history,
    required int streak,
    required int bestStreak,
    required int engrams,
  }) async {
    final capped = history.length > historyCap
        ? history.sublist(history.length - historyCap)
        : history;
    await prefs.setStringList(_streakHistoryKey, [
      for (final d in capped) d.toIso8601String(),
    ]);
    await prefs.setInt(_streakKey, streak);
    await prefs.setInt(_bestStreakKey, bestStreak);
    await prefs.setInt(_engramsKey, engrams);
    _streakMemory = StreakState(
      history: List<DateTime>.of(capped),
      streak: streak,
      bestStreak: bestStreak,
      engrams: engrams,
    );
  }

  static Future<StreakState> recordStreakDay([DateTime? now]) async {
    final prefs = await SharedPreferences.getInstance();
    final current = await loadStreakState();
    final today = now ?? DateTime.now();
    final t = DateTime(today.year, today.month, today.day);
    final days = current.history.where((d) => !d.isAfter(t)).toList();
    if (days.any((d) => d == t)) {
      if (days.length != current.history.length) {
        await _saveStreakState(
          prefs,
          history: days,
          streak: current.streak,
          bestStreak: current.bestStreak,
          engrams: current.engrams,
        );
      }
      return StreakState(
        history: days,
        streak: current.streak,
        bestStreak: current.bestStreak,
        engrams: current.engrams,
      );
    }

    int streak;
    if (days.isEmpty) {
      streak = 1;
    } else {
      final last = days.last;
      final gap = dayDiff(t, last);
      streak = gap == 1 ? current.streak + 1 : 1;
      if (gap == 1 && current.streak <= 0) {
        streak = currentRunLength(history: [...days, t], today: t);
      }
    }
    days.add(t);
    final best = nextBestStreak(bestStreak: current.bestStreak, streak: streak);
    final engrams = current.engrams + engramsPerDay;
    await _saveStreakState(
      prefs,
      history: days,
      streak: streak,
      bestStreak: best,
      engrams: engrams,
    );
    _notifyChanged();
    return StreakState(
      history: days,
      streak: streak,
      bestStreak: best,
      engrams: engrams,
    );
  }

  static Future<StreakRestoreOutcome> restoreStreak([DateTime? now]) async {
    final prefs = await SharedPreferences.getInstance();
    final current = await loadStreakState();
    final today = now ?? DateTime.now();
    final t = DateTime(today.year, today.month, today.day);
    final plan = StreakRestore.planStreakRestore(
      history: current.history,
      today: t,
    );
    if (plan == null) return StreakRestoreOutcome.notEligible;
    final cost = StreakRestore.streakRestoreCost(plan.missedDays);
    if (current.engrams < cost) {
      return StreakRestoreOutcome.insufficientFunds;
    }
    final merged = {...current.history, ...plan.filledDays}.toList()..sort();
    final streak = plan.restoredStreak;
    final best = nextBestStreak(bestStreak: current.bestStreak, streak: streak);
    await _saveStreakState(
      prefs,
      history: merged,
      streak: streak,
      bestStreak: best,
      engrams: current.engrams - cost,
    );
    _notifyChanged();
    return StreakRestoreOutcome.restored;
  }

  static Future<String?> loadRestorePromptDay() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_restorePromptDayKey);
  }

  static Future<void> markRestorePromptShown([DateTime? now]) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_restorePromptDayKey, todayKey(now));
  }

  static Future<int> resolveBattleKind(int kindCount) async {
    final saved = await loadBattleKind();
    if (saved != null && saved >= 0 && saved < kindCount) return saved;
    final verdict = await loadDominantKind();
    if (verdict != null && verdict >= 0 && verdict < kindCount) return verdict;
    final scores = await loadScores();
    final strongest = strongestKind(scores);
    if (strongest >= 0 && strongest < kindCount) return strongest;
    return 0;
  }

  static const _fsrsCardsKey = 'fsrs_cards_v1';
  static const _metaCacheKey = 'meta_cache_v1';

  static const int fsrsCap = 200;

  static const int metaCacheCap = 40;

  static Future<void> saveFsrsCards(Map<String, String> byCardIdJson) async {
    await saveFsrsCardsWithoutNotify(byCardIdJson);
    _notifyChanged();
  }

  static Future<void> saveFsrsCardsWithoutNotify(
    Map<String, String> byCardIdJson,
  ) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final entries = byCardIdJson.entries.toList();
      final capped = entries.length > fsrsCap
          ? entries.sublist(entries.length - fsrsCap)
          : entries;
      await prefs.setStringList(_fsrsCardsKey, [
        for (final e in capped) '${e.key}=${e.value}',
      ]);
    } catch (_) {
    }
  }

  static Future<Map<String, String>> loadFsrsCards() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getStringList(_fsrsCardsKey);
      if (raw == null || raw.isEmpty) return {};
      final map = <String, String>{};
      for (final e in raw) {
        final i = e.indexOf('=');
        if (i <= 0) continue;
        map[e.substring(0, i)] = e.substring(i + 1);
      }
      return map;
    } catch (_) {
      return {};
    }
  }

  static Future<void> saveMetaCache(Map<String, String> entries) async {
    await saveMetaCacheWithoutNotify(entries);
    _notifyChanged();
  }

  static Future<void> saveMetaCacheWithoutNotify(
    Map<String, String> entries,
  ) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final list = entries.entries.toList();
      final capped = list.length > metaCacheCap
          ? list.sublist(list.length - metaCacheCap)
          : list;
      await prefs.setStringList(_metaCacheKey, [
        for (final e in capped) '${e.key}=${e.value}',
      ]);
    } catch (_) {
    }
  }

  static Future<Map<String, String>> loadMetaCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getStringList(_metaCacheKey);
      if (raw == null || raw.isEmpty) return {};
      final map = <String, String>{};
      for (final e in raw) {
        final i = e.indexOf('=');
        if (i <= 0) continue;
        map[e.substring(0, i)] = e.substring(i + 1);
      }
      return map;
    } catch (_) {
      return {};
    }
  }

  static Future<void> recordAssessmentRun({
    required List<double> itemProps,
    required List<int> scores,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final rows = prefs.getStringList(_assessmentRunsDataKey) ?? [];
      rows.add([for (final p in itemProps) p.clamp(0.0, 1.0).toStringAsFixed(3)]
          .join(','));
      while (rows.length > maxStoredRuns) {
        rows.removeAt(0);
      }
      await prefs.setStringList(_assessmentRunsDataKey, rows);
      final norms = await loadLocalNorms();
      for (var k = 0; k < scores.length && k < 6; k++) {
        (norms[k] ??= LocalNorm()).add((scores[k] / 100).clamp(0.0, 1.0));
      }
      await prefs.setStringList(_localNormsKey, [
        for (final e in norms.entries)
          '${e.key}=${e.value.n},${e.value.mean},${e.value.m2}',
      ]);
    } catch (_) {
    }
  }

  static Future<Map<int, LocalNorm>> loadLocalNorms() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getStringList(_localNormsKey);
      if (raw == null || raw.isEmpty) return {};
      final map = <int, LocalNorm>{};
      for (final e in raw) {
        final i = e.indexOf('=');
        if (i <= 0) continue;
        final kind = int.tryParse(e.substring(0, i));
        final parts = e.substring(i + 1).split(',');
        if (kind == null || parts.length != 3) continue;
        map[kind] = LocalNorm(
          n: int.tryParse(parts[0]) ?? 0,
          mean: double.tryParse(parts[1]) ?? 0,
          m2: double.tryParse(parts[2]) ?? 0,
        );
      }
      return map;
    } catch (_) {
      return {};
    }
  }

  static Future<List<List<double>>> loadAssessmentRunsData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getStringList(_assessmentRunsDataKey);
      if (raw == null || raw.isEmpty) return [];
      final runs = <List<double>>[];
      for (final row in raw) {
        final props = [
          for (final c in row.split(',')) double.tryParse(c) ?? 0,
        ];
        if (props.length == assessmentProbeCount) runs.add(props);
      }
      return runs;
    } catch (_) {
      return [];
    }
  }
}
