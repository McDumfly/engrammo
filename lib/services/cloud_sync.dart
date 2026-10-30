import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

import 'app_settings.dart';
import '../models/battle_bot.dart';
import '../models/battle_match.dart';
import '../models/friend_social.dart';
import '../models/league_season.dart';
import '../models/user_goals.dart';
import 'memory_store.dart';
import 'meta_ai_service.dart';
import 'profile_setup.dart';

class NoConnectionException implements Exception {
  const NoConnectionException();

  @override
  String toString() => 'NoConnectionException';
}

class CloudSync {
  static bool get available {
    try {
      return Firebase.apps.isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  static String? currentUid;

  static String? get _uid => currentUid;

  static Future<void> deleteUserDoc(String uid) async {
    final doc = _doc(uid);
    if (doc == null) return;
    await doc.delete();
  }

  static DocumentReference<Map<String, dynamic>>? _doc(String uid) {
    try {
      if (!available) return null;
      return FirebaseFirestore.instance.collection('users').doc(uid);
    } catch (_) {
      return null;
    }
  }

  static Future<void> pushFromLocal(String uid) async {
    final doc = _doc(uid);
    if (doc == null) return;
    try {
      final profile = await MemoryStore.loadProfile();
      final scores = await MemoryStore.loadScores();
      final dominant = await MemoryStore.loadDominantKind();
      final dominantMeta = await MemoryStore.loadDominantMeta();
      final kind = await MemoryStore.loadBattleKind();
      final rating = await MemoryStore.loadBattleRating();
      final battleXp = await MemoryStore.loadBattleXp();
      final battleStats = await MemoryStore.loadBattleStats();
      final battleHistory = await MemoryStore.loadBattleHistory();
      final friendGraph = await MemoryStore.loadFriendGraph();
      final avatar = await MemoryStore.loadAvatarOpts(const {});
      final streak = await MemoryStore.loadStreakState();
      final fsrs = await MemoryStore.loadFsrsCards();
      final meta = await MemoryStore.loadMetaCache();
      final chapterProgress = await MemoryStore.loadChapterProgress();
      final lessonReps = await MemoryStore.loadLessonReps();
      final trackMinutes = await MemoryStore.loadTrackMinutes();
      final lessonDone = await MemoryStore.loadLessonDoneDates();
      final onboardingDone = await MemoryStore.loadOnboardingDone();
      final setupDone = await MemoryStore.isProfileSetupDone(uid);
      final roster = await MemoryStore.loadBotRoster();
      final season = await MemoryStore.loadLeagueSeason();
      final leagueHistory = await MemoryStore.loadLeagueHistory();
      final feed = await MemoryStore.loadFriendFeed();
      final goals = await MemoryStore.loadUserGoals();
      final missions = await MemoryStore.loadDoneMissions();
      final materials = await MemoryStore.loadAllOwnMaterials();
      final benchmark = await MemoryStore.loadBenchmark();
      final invites = await MemoryStore.loadBattleInvites();
      final aiConsent = await MetaAIService.cloudConsent();
      await doc.set({
        'displayName': profile.displayName,
        'username': profile.username,
        'profileCompleted': setupDone,
        'email': profile.email,
        'scores': scores ?? const [],
        'dominantKind': dominant ?? -1,
        'dominantMeta': dominantMeta,
        'battleKind': kind ?? -1,
        'battleRating': rating,
        'battleXp': battleXp,
        'battleStats': battleStats.toJson(),
        'battleHistory': [for (final r in battleHistory) r.toJson()],
        'friendsGraph': {
          for (final e in friendGraph) e.botId: e.addedAt.toIso8601String(),
        },
        'avatarOpts': avatar,
        'darkMode': appSettings.darkMode,
        'haptics': appSettings.haptics,
        'languageCode': appSettings.languageCode,
        'streak': streak.streak,
        'bestStreak': streak.bestStreak,
        'engrams': streak.engrams,
        'streakHistory': [for (final d in streak.history) d.toIso8601String()],
        'fsrsCards': fsrs,
        'metaCache': meta,
        'chapterProgress': chapterProgress,
        'lessonReps': lessonReps,
        'trackMinutes': trackMinutes,
        'lessonDone': {
          for (final e in lessonDone.entries)
            e.key: e.value.toIso8601String(),
        },
        'onboardingDone': onboardingDone,
        'botRoster': [for (final b in roster) b.toJson()],
        'leagueSeason': season?.toJson(),
        'leagueHistory': [for (final s in leagueHistory) s.toJson()],
        'friendFeed': [for (final e in feed) e.toJson()],
        'userGoals': [for (final g in goals) g.toJson()],
        'doneMissions': missions.toList()..sort(),
        'ownMaterial': materials,
        'benchmark': benchmark.toJson(),
        'battleInvites': invites.toList()..sort(),
        'aiCloudConsent': aiConsent,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (e) {
      debugPrint('CloudSync.push skipped: $e');
    }
  }

  static Future<void> pullToLocal(String uid) async {
    final doc = _doc(uid);
    if (doc == null) return;
    try {
      final snap = await doc.get();
      final data = snap.data();
      if (data == null || data.isEmpty) {
        await pushFromLocal(uid);
        return;
      }

      final cloudName = (data['displayName'] as String?) ?? '';
      final cloudUsername = (data['username'] as String?) ?? '';
      final cloudEmail = (data['email'] as String?) ?? '';
      if (cloudName.isNotEmpty ||
          cloudUsername.isNotEmpty ||
          cloudEmail.isNotEmpty) {
        await MemoryStore.saveProfileWithoutNotify(
          displayName: cloudName,
          username: cloudUsername,
          email: cloudEmail,
        );
      }

      final scores = data['scores'];
      if (scores is List && scores.isNotEmpty) {
        await MemoryStore.saveScoresWithoutNotify([
          for (final s in scores) (s as num?)?.toInt() ?? 0,
        ]);
      }
      final dominant = data['dominantKind'];
      if (dominant is int && dominant >= 0) {
        final meta = data['dominantMeta'];
        final rationale =
            meta is Map ? (meta['rationale']?.toString() ?? '') : '';
        final ai = meta is Map && meta['source']?.toString() == 'ai';
        await MemoryStore.saveDominantKindWithoutNotify(
          dominant,
          rationale: rationale,
          ai: ai,
        );
      }
      final kind = data['battleKind'];
      if (kind is int && kind >= 0) {
        await MemoryStore.saveBattleKindWithoutNotify(kind);
      }
      final rating = data['battleRating'];
      if (rating is num) {
        await MemoryStore.saveBattleRatingWithoutNotify(rating.toInt());
      }
      final xp = data['battleXp'];
      if (xp is num) {
        final local = await MemoryStore.loadBattleXp();
        if (xp.toInt() > local) {
          await MemoryStore.saveBattleXpWithoutNotify(xp.toInt());
        }
      }
      final statsCloud = data['battleStats'];
      if (statsCloud is Map) {
        final local = await MemoryStore.loadBattleStats();
        int numOf(Object? v) => (v as num?)?.toInt() ?? 0;
        final merged = BattleStats(
          matches: numOf(statsCloud['matches']).clamp(local.matches, 1 << 30),
          wins: numOf(statsCloud['wins']).clamp(local.wins, 1 << 30),
          losses: numOf(statsCloud['losses']).clamp(local.losses, 1 << 30),
          draws: numOf(statsCloud['draws']).clamp(local.draws, 1 << 30),
          bestStreak: numOf(
            statsCloud['bestStreak'],
          ).clamp(local.bestStreak, 1 << 30),
          currentStreak: numOf(
            statsCloud['currentStreak'],
          ).clamp(local.currentStreak, 1 << 30),
        );
        await MemoryStore.saveBattleStatsWithoutNotify(merged);
      }
      final historyCloud = data['battleHistory'];
      if (historyCloud is List && historyCloud.isNotEmpty) {
        final local = await MemoryStore.loadBattleHistory();
        final byId = {for (final r in local) r.id: r};
        for (final e in historyCloud) {
          if (e is! Map) continue;
          final record = BattleRecord.fromJson(
            e.map((k, v) => MapEntry(k.toString(), v)),
          );
          if (record.id.isEmpty || byId.containsKey(record.id)) continue;
          byId[record.id] = record;
        }
        await MemoryStore.saveBattleHistoryWithoutNotify(byId.values.toList());
      }
      final graphCloud = data['friendsGraph'];
      if (graphCloud is Map && graphCloud.isNotEmpty) {
        final local = await MemoryStore.loadFriendGraph();
        final byId = {for (final e in local) e.botId: e};
        graphCloud.forEach((k, v) {
          final id = k.toString();
          if (id.isEmpty || byId.containsKey(id)) return;
          final at = DateTime.tryParse(v.toString()) ?? DateTime.now();
          byId[id] = FriendEdge(botId: id, addedAt: at);
        });
        await MemoryStore.saveFriendGraphWithoutNotify(byId.values.toList());
      }
      final avatar = data['avatarOpts'];
      if (avatar is Map && avatar.isNotEmpty) {
        await MemoryStore.saveAvatarOptsWithoutNotify(
          avatar.map((k, v) => MapEntry(k.toString(), v.toString())),
        );
      }

      var history = <DateTime>[];
      final rawHistory = data['streakHistory'];
      if (rawHistory is List) {
        history = [
          for (final e in rawHistory)
            if (DateTime.tryParse(e.toString()) != null)
              DateTime.parse(e.toString()),
        ];
      }
      final streak = (data['streak'] as num?)?.toInt();
      final best = (data['bestStreak'] as num?)?.toInt();
      final engrams = (data['engrams'] as num?)?.toInt();
      if (streak != null ||
          best != null ||
          engrams != null ||
          history.isNotEmpty) {
        await MemoryStore.saveStreakStateDirect(
          history: history.isEmpty ? null : history,
          streak: streak,
          bestStreak: best,
          engrams: engrams,
        );
      }

      final fsrsCloud = data['fsrsCards'];
      if (fsrsCloud is Map && fsrsCloud.isNotEmpty) {
        await MemoryStore.saveFsrsCardsWithoutNotify(
          fsrsCloud.map((k, v) => MapEntry(k.toString(), v.toString())),
        );
      }
      final metaCloud = data['metaCache'];
      if (metaCloud is Map && metaCloud.isNotEmpty) {
        await MemoryStore.saveMetaCacheWithoutNotify(
          metaCloud.map((k, v) => MapEntry(k.toString(), v.toString())),
        );
      }
      final chaptersCloud = data['chapterProgress'];
      if (chaptersCloud is Map && chaptersCloud.isNotEmpty) {
        final parsed = await MemoryStore.loadChapterProgress();
        chaptersCloud.forEach((k, v) {
          final key = k.toString();
          final stars = (v as num?)?.toInt() ?? 0;
          final kept = parsed[key] ?? 0;
          final next = stars.clamp(0, 3);
          parsed[key] = next > kept ? next : kept;
        });
        await MemoryStore.saveChapterProgressWithoutNotify(parsed);
      }
      final repsCloud = data['lessonReps'];
      if (repsCloud is Map && repsCloud.isNotEmpty) {
        final parsed = await MemoryStore.loadLessonReps();
        repsCloud.forEach((k, v) {
          final key = k.toString();
          final next = (v as num?)?.toInt() ?? 0;
          final kept = parsed[key] ?? 0;
          parsed[key] = next > kept ? next : kept;
        });
        await MemoryStore.saveLessonRepsWithoutNotify(parsed);
      }
      final minutesCloud = data['trackMinutes'];
      if (minutesCloud is Map && minutesCloud.isNotEmpty) {
        final parsed = await MemoryStore.loadTrackMinutes();
        minutesCloud.forEach((k, v) {
          final key = k.toString();
          final next = (v as num?)?.toInt() ?? 0;
          final kept = parsed[key] ?? 0;
          parsed[key] = next > kept ? next : kept;
        });
        await MemoryStore.saveTrackMinutesWithoutNotify(parsed);
      }
      final doneCloud = data['lessonDone'];
      if (doneCloud is Map && doneCloud.isNotEmpty) {
        final parsed = await MemoryStore.loadLessonDoneDates();
        doneCloud.forEach((k, v) {
          final at = DateTime.tryParse(v.toString());
          if (at == null) return;
          final key = k.toString();
          final kept = parsed[key];
          if (kept == null || at.isAfter(kept)) parsed[key] = at;
        });
        await MemoryStore.saveLessonDoneDatesWithoutNotify(parsed);
      }
      final onboardingCloud = data['onboardingDone'];
      if (onboardingCloud == true) {
        await MemoryStore.saveOnboardingDone();
      }
      if (data['profileCompleted'] == true) {
        await MemoryStore.markProfileSetupDoneWithoutNotify(uid);
      }

      final rosterCloud = data['botRoster'];
      if (rosterCloud is List && rosterCloud.isNotEmpty) {
        final local = await MemoryStore.loadBotRoster();
        final byId = <String, BotPersona>{};
        for (final e in rosterCloud) {
          if (e is! Map) continue;
          try {
            final bot = BotPersona.fromJson(
              e.map((k, v) => MapEntry(k.toString(), v)),
            );
            if (bot.id.isEmpty) continue;
            byId[bot.id] = bot;
          } catch (_) {}
        }
        for (final bot in local) {
          final kept = byId[bot.id];
          if (kept == null || bot.xp > kept.xp) byId[bot.id] = bot;
        }
        if (byId.isNotEmpty) {
          await MemoryStore.saveBotRosterWithoutNotify(byId.values.toList());
        }
      }
      final seasonCloud = data['leagueSeason'];
      if (seasonCloud is Map) {
        try {
          final cloud = LeagueSeason.fromJson(
            seasonCloud.map((k, v) => MapEntry(k.toString(), v)),
          );
          final local = await MemoryStore.loadLeagueSeason();
          final current = seasonIdFor(DateTime.now());
          LeagueSeason? picked;
          if (local != null && local.seasonId == current) {
            picked = local;
          } else if (cloud.seasonId == current) {
            picked = cloud;
          } else if (local == null) {
            picked = cloud;
          } else {
            picked = cloud.updatedAt.isAfter(local.updatedAt) ? cloud : local;
          }
          await MemoryStore.saveLeagueSeasonWithoutNotify(picked);
        } catch (_) {}
      }
      final leagueHistoryCloud = data['leagueHistory'];
      if (leagueHistoryCloud is List && leagueHistoryCloud.isNotEmpty) {
        final local = await MemoryStore.loadLeagueHistory();
        final byId = {for (final s in local) s.seasonId: s};
        for (final e in leagueHistoryCloud) {
          if (e is! Map) continue;
          try {
            final summary = LeagueSummary.fromJson(
              e.map((k, v) => MapEntry(k.toString(), v)),
            );
            if (summary.seasonId.isEmpty ||
                byId.containsKey(summary.seasonId)) {
              continue;
            }
            byId[summary.seasonId] = summary;
          } catch (_) {}
        }
        await MemoryStore.saveLeagueHistoryWithoutNotify(byId.values.toList());
      }
      final feedCloud = data['friendFeed'];
      if (feedCloud is List && feedCloud.isNotEmpty) {
        final local = await MemoryStore.loadFriendFeed();
        final byId = {for (final e in local) e.id: e};
        for (final e in feedCloud) {
          if (e is! Map) continue;
          try {
            final event = FeedEvent.fromJson(
              e.map((k, v) => MapEntry(k.toString(), v)),
            );
            if (event.id.isEmpty || byId.containsKey(event.id)) continue;
            byId[event.id] = event;
          } catch (_) {}
        }
        await MemoryStore.saveFriendFeedWithoutNotify(byId.values.toList());
      }
      final goalsCloud = data['userGoals'];
      if (goalsCloud is List && goalsCloud.isNotEmpty) {
        final local = await MemoryStore.loadUserGoals();
        final byId = {for (final g in local) g.id: g};
        for (final e in goalsCloud) {
          if (e is! Map) continue;
          try {
            final goal = UserGoal.fromJson(
              e.map((k, v) => MapEntry(k.toString(), v)),
            );
            if (goal.id.isEmpty) continue;
            final kept = byId[goal.id];
            if (kept == null || goal.updatedAt.isAfter(kept.updatedAt)) {
              byId[goal.id] = goal;
            }
          } catch (_) {}
        }
        await MemoryStore.saveUserGoalsWithoutNotify(byId.values.toList());
      }
      final missionsCloud = data['doneMissions'];
      if (missionsCloud is List && missionsCloud.isNotEmpty) {
        final local = await MemoryStore.loadDoneMissions();
        final merged = {
          ...local,
          for (final e in missionsCloud)
            if (e is String && e.isNotEmpty) e,
        };
        await MemoryStore.saveDoneMissionsWithoutNotify(merged);
      }
      final materialsCloud = data['ownMaterial'];
      if (materialsCloud is Map && materialsCloud.isNotEmpty) {
        final local = await MemoryStore.loadAllOwnMaterials();
        final merged = {
          for (final e in materialsCloud.entries)
            if (e.key.toString().isNotEmpty) e.key.toString(): e.value.toString(),
          ...local,
        };
        await MemoryStore.saveAllOwnMaterialsWithoutNotify(merged);
      }
      final benchmarkCloud = data['benchmark'];
      if (benchmarkCloud is Map) {
        try {
          final cloud = BenchmarkState.fromJson(
            benchmarkCloud.map((k, v) => MapEntry(k.toString(), v)),
          );
          final local = await MemoryStore.loadBenchmark();
          final keepCloud = cloud.plays > local.plays;
          await MemoryStore.saveBenchmarkWithoutNotify(
            BenchmarkState(
              best: keepCloud ? cloud.best : local.best,
              attempts: keepCloud ? cloud.attempts : local.attempts,
              xp: cloud.xp > local.xp ? cloud.xp : local.xp,
              plays: cloud.plays > local.plays ? cloud.plays : local.plays,
              bonusClaimed: cloud.bonusClaimed || local.bonusClaimed,
            ),
          );
        } catch (_) {}
      }
      final invitesCloud = data['battleInvites'];
      if (invitesCloud is List && invitesCloud.isNotEmpty) {
        final local = await MemoryStore.loadBattleInvites();
        final merged = {
          ...local,
          for (final e in invitesCloud)
            if (e is String && e.isNotEmpty) e,
        };
        await MemoryStore.saveBattleInvitesWithoutNotify(merged);
      }
      if (data.containsKey('aiCloudConsent')) {
        final consent = data['aiCloudConsent'] == true;
        if (consent != (await MetaAIService.cloudConsent())) {
          await MetaAIService.setCloudConsent(consent);
        }
      }

      final dark = data['darkMode'];
      if (dark is bool && dark != appSettings.darkMode) {
        await appSettings.setDarkMode(dark);
      }
      final haptics = data['haptics'];
      if (haptics is bool && haptics != appSettings.haptics) {
        await appSettings.setHaptics(haptics);
      }
      final language = data['languageCode'];
      if (language is String && language != appSettings.languageCode) {
        await appSettings.setLanguage(language);
      }
    } catch (e) {
      debugPrint('CloudSync.pull skipped: $e');
    }
  }

  static Future<void> pushNow() async {
    final uid = _uid;
    if (uid == null) return;
    await pushFromLocal(uid);
  }

  static Future<bool?> isUsernameAvailable(String username, String uid) async {
    try {
      if (!available || uid.isEmpty) return null;
      final name = ProfileSetupRules.normalizeUsername(username);
      if (ProfileSetupRules.validateUsername(name) != null) return null;
      final snap = await FirebaseFirestore.instance
          .collection('usernames')
          .doc(name)
          .get();
      if (!snap.exists) return true;
      return (snap.data()?['uid'] as String?) == uid;
    } catch (_) {
      return null;
    }
  }

  static Future<void> claimUsername({
    required String uid,
    required String username,
  }) async {
    if (!available || uid.isEmpty) {
      throw const NoConnectionException();
    }
    final name = ProfileSetupRules.normalizeUsername(username);
    final error = ProfileSetupRules.validateUsername(name);
    if (error != null) throw StateError(error);
    final db = FirebaseFirestore.instance;
    final nameRef = db.collection('usernames').doc(name);
    final userRef = db.collection('users').doc(uid);
    try {
      await db.runTransaction((tx) async {
        final snap = await tx.get(nameRef);
        if (snap.exists && (snap.data()?['uid'] as String?) != uid) {
          throw const UsernameTakenException();
        }
        tx.set(nameRef, {
          'uid': uid,
          'updatedAt': FieldValue.serverTimestamp(),
        });
        tx.set(userRef, {
          'username': name,
        }, SetOptions(merge: true));
      });
    } on UsernameTakenException {
      rethrow;
    } catch (e) {
      if (e is StateError) rethrow;
      throw const NoConnectionException();
    }
  }

  static Future<void> releaseUsername({
    required String uid,
    required String username,
  }) async {
    try {
      if (!available || uid.isEmpty) return;
      final name = ProfileSetupRules.normalizeUsername(username);
      if (name.isEmpty) return;
      final ref = FirebaseFirestore.instance
          .collection('usernames')
          .doc(name);
      final snap = await ref.get();
      if (snap.exists && (snap.data()?['uid'] as String?) == uid) {
        await ref.delete();
      }
    } catch (_) {
    }
  }
}
