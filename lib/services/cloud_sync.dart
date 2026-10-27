import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

import 'app_settings.dart';
import 'memory_store.dart';

/// Firestore-szinkron a `users/{uid}` dokumentumba.
///
/// Mezők: displayName, username, email, scores, battleKind,
/// battleRating, avatarOpts, darkMode, haptics, streak, bestStreak,
/// engrams, streakHistory, updatedAt.
///
/// Minden metódus best-effort: backend vagy net nélkül csendben
/// visszatér, az app offline tovább megy a helyi mentéssel.
class CloudSync {
  static bool get available {
    try {
      return Firebase.apps.isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  /// A bejelentkezett felhasználó uid-je. Az [AuthService] tartja naprakészen;
  /// null esetén nincs kit szinkronizálni (kijelentkezve/vendég/offline).
  static String? currentUid;

  static String? get _uid => currentUid;

  /// Felhasználói dokumentum törlése (fióktörléskor).
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

  /// Helyi állapot feltöltése a bejelentkezett fiókba.
  static Future<void> pushFromLocal(String uid) async {
    final doc = _doc(uid);
    if (doc == null) return;
    try {
      final profile = await MemoryStore.loadProfile();
      final scores = await MemoryStore.loadScores();
      final kind = await MemoryStore.loadBattleKind();
      final rating = await MemoryStore.loadBattleRating();
      final avatar = await MemoryStore.loadAvatarOpts(const {});
      final streak = await MemoryStore.loadStreakState();
      final fsrs = await MemoryStore.loadFsrsCards();
      final meta = await MemoryStore.loadMetaCache();
      await doc.set({
        'displayName': profile.displayName,
        'username': profile.username,
        'email': profile.email,
        'scores': scores ?? const [],
        'battleKind': kind ?? -1,
        'battleRating': rating,
        'avatarOpts': avatar,
        'darkMode': appSettings.darkMode,
        'haptics': appSettings.haptics,
        'streak': streak.streak,
        'bestStreak': streak.bestStreak,
        'engrams': streak.engrams,
        'streakHistory': [
          for (final d in streak.history) d.toIso8601String(),
        ],
        'fsrsCards': fsrs,
        'metaCache': meta,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (e) {
      debugPrint('CloudSync.push kihagyva: $e');
    }
  }

  /// A bejelentkezett fiók mentésének lehúzása a helyi tárolóba.
  /// Csak akkor ír felül, ha a felhőben van használható érték.
  static Future<void> pullToLocal(String uid) async {
    final doc = _doc(uid);
    if (doc == null) return;
    try {
      final snap = await doc.get();
      final data = snap.data();
      if (data == null || data.isEmpty) {
        // Új fiók: a helyi nullás állapotot töltjük fel kiindulásnak.
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
        await MemoryStore.saveScoresWithoutNotify(
          [for (final s in scores) (s as num?)?.toInt() ?? 0],
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
      if (streak != null || best != null || engrams != null || history.isNotEmpty) {
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

      final dark = data['darkMode'];
      if (dark is bool && dark != appSettings.darkMode) {
        await appSettings.setDarkMode(dark);
      }
      final haptics = data['haptics'];
      if (haptics is bool && haptics != appSettings.haptics) {
        await appSettings.setHaptics(haptics);
      }
    } catch (e) {
      debugPrint('CloudSync.pull kihagyva: $e');
    }
  }

  /// A [MemoryStore.onChanged] horog hívja minden írás után.
  static Future<void> pushNow() async {
    final uid = _uid;
    if (uid == null) return;
    await pushFromLocal(uid);
  }
}
