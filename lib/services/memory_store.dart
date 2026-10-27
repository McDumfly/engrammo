import 'dart:async';

import 'package:shared_preferences/shared_preferences.dart';

import '../utils/streak_restore.dart';
import '../utils/streak_utils.dart';

/// Pillanatkép a széria állapotáról a helyi tárolóból.
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

/// Local persistence for the user's memory profile and Battle Zone choices.
class MemoryStore {
  static const _scoresKey = 'memory_scores_v1';
  static const _battleKindKey = 'battle_memory_kind_v1';
  static const _battleRatingKey = 'battle_rating_v1';
  static const _avatarOptsKey = 'avatar_opts_v1';
  static const _profileNameKey = 'profile_display_name_v1';
  static const _profileUsernameKey = 'profile_username_v1';
  static const _profileEmailKey = 'profile_email_v1';

  /// Horog a felhő-szinkronnak: minden érdemi írás után lefut
  /// (best-effort, a hívó nem várja meg). Az Auth-réteg köti be,
  /// így a tároló nem függ a Firebase-től.
  static Future<void> Function()? onChanged;

  static void _notifyChanged() {
    final cb = onChanged;
    if (cb != null) unawaited(cb());
  }

  /// Scores per [memoryKinds] index from the last finished assessment.
  static Future<void> saveScores(List<int> scores) async {
    await saveScoresWithoutNotify(scores);
    _notifyChanged();
  }

  static Future<void> saveScoresWithoutNotify(List<int> scores) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
      _scoresKey,
      [for (final s in scores) s.toString()],
    );
  }

  static Future<List<int>?> loadScores() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(_scoresKey);
    if (raw == null || raw.isEmpty) return null;
    return [for (final s in raw) int.tryParse(s) ?? 0];
  }

  /// Index of the strongest memory kind in [scores], or 0 when unknown.
  static int strongestKind(List<int>? scores) {
    if (scores == null || scores.isEmpty) return 0;
    var best = 0;
    for (var i = 1; i < scores.length; i++) {
      if (scores[i] > scores[best]) best = i;
    }
    return best;
  }

  /// Explicit Battle Zone memory-type choice made by the user, if any.
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

  /// Sima battle pontszám: [defaultRating]-ről indul, 0 alá nem mehet.
  static Future<int> loadBattleRating({int defaultRating = 1000}) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getInt(_battleRatingKey);
    if (raw == null) return defaultRating;
    return raw < 0 ? 0 : raw;
  }

  static Future<void> saveBattleRating(int rating) async {
    await saveBattleRatingWithoutNotify(rating);
    _notifyChanged();
  }

  static Future<void> saveBattleRatingWithoutNotify(int rating) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_battleRatingKey, rating < 0 ? 0 : rating);
  }

  /// A profilavatar beallitasai: menteskor elrakjuk, a profiloldal
  /// betolteskor visszaolvassa, igy nem all vissza alapra, es a
  /// hozza tartozo SVG lemezcache-talalat is egybol megvan.
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
    } catch (_) {
      // Csak gyorsitas: hiba eseten marad a memoria-allapot.
    }
  }

  /// Profil-azonosítók (megjelenő név, @név, email). A belépőképernyő
  /// és a beállítások írja, a profil olvassa, a felhő szinkronizálja.
  static Future<({String displayName, String username, String email})>
  loadProfile() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return (
        displayName: prefs.getString(_profileNameKey) ?? '',
        username: prefs.getString(_profileUsernameKey) ?? '',
        email: prefs.getString(_profileEmailKey) ?? '',
      );
    } catch (_) {
      return (displayName: '', username: '', email: '');
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
    } catch (_) {
      // Hiba esetén marad a memóriabeli állapot.
    }
  }

  /// Széria-állapot közvetlen írása (felhő-lehúzáshoz). Csak a nem-null
  /// mezőket írja felül; az előzményt csak nem-üres lista esetén.
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
      // Hiba esetén marad a helyi állapot.
    }
  }

  /// A mentett avatar-beallitasok [fallback]-re ultetve.
  /// Ismeretlen vagy ures tarolo eseten maga a [fallback].
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
      return map;
    } catch (_) {
      return fallback;
    }
  }

  // ── Széria + engram-egyenleg (helyi, kreeds-app logikával) ──────────

  static const _streakHistoryKey = 'streak_history_v1';
  static const _streakKey = 'streak_v1';
  static const _bestStreakKey = 'best_streak_v1';
  static const _engramsKey = 'engrams_v1';
  static const _restorePromptDayKey = 'restore_prompt_day_v1';

  /// Naptár-bejegyzések legfeljebb ennyi napig őrződnek.
  static const int historyCap = 400;

  /// Mai napkulcs "yyyy-MM-dd" formában.
  static String todayKey([DateTime? now]) {
    final n = now ?? DateTime.now();
    final m = n.month.toString().padLeft(2, '0');
    final d = n.day.toString().padLeft(2, '0');
    return '${n.year}-$m-$d';
  }

  /// Teljes széria-állapot egy olvasással.
  static Future<StreakState> loadStreakState() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(_streakHistoryKey) ?? const [];
    return StreakState(
      history: parseStreakHistory(raw),
      streak: prefs.getInt(_streakKey) ?? 0,
      bestStreak: prefs.getInt(_bestStreakKey) ?? 0,
      engrams: prefs.getInt(_engramsKey) ?? 0,
    );
  }

  static Future<void> _saveStreakState(
    SharedPreferences prefs, {
    required List<DateTime> history,
    required int streak,
    required int bestStreak,
    required int engrams,
  }) async {
    final capped =
        history.length > historyCap
            ? history.sublist(history.length - historyCap)
            : history;
    await prefs.setStringList(
      _streakHistoryKey,
      [for (final d in capped) d.toIso8601String()],
    );
    await prefs.setInt(_streakKey, streak);
    await prefs.setInt(_bestStreakKey, bestStreak);
    await prefs.setInt(_engramsKey, engrams);
  }

  /// Mai nap teljesítésének rögzítése (kreeds `GamificationTracker`
  /// napi lezárásának helyi megfelelője): ma először -> a tegnapi
  /// folytatása vagy újrakezdés 1-től; ismételt hívás nem dupláz.
  /// Visszatérés a frissített állapot.
  static Future<StreakState> recordStreakDay([DateTime? now]) async {
    final prefs = await SharedPreferences.getInstance();
    final current = await loadStreakState();
    final today = now ?? DateTime.now();
    final t = DateTime(today.year, today.month, today.day);
    final days = current.history.toList();
    if (days.any((d) => d == t)) return current;

    int streak;
    if (days.isEmpty) {
      streak = 1;
    } else {
      final last = days.last;
      final gap = t.difference(last).inDays;
      streak = gap == 1 ? current.streak + 1 : 1;
      // Holt naptár + elcsúszott számláló: a naptár hossza a minimum.
      if (gap == 1 && current.streak <= 0) {
        streak = currentRunLength(
          history: [...days, t],
          today: t,
        );
      }
    }
    days.add(t);
    final best = nextBestStreak(bestStreak: current.bestStreak, streak: streak);
    await _saveStreakState(
      prefs,
      history: days,
      streak: streak,
      bestStreak: best,
      engrams: current.engrams,
    );
    _notifyChanged();
    return StreakState(
      history: days,
      streak: streak,
      bestStreak: best,
      engrams: current.engrams,
    );
  }

  /// Visszaállítás engramért: terv-számítás + egyenleg-ellenőrzés +
  /// napok pótlása egyben (a kreeds `restoreStreak` tranzakció
  /// helyi megfelelője; dupla koppintás ellen a friss terv dönt).
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
    final merged =
        {...current.history, ...plan.filledDays}.toList()..sort();
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

  /// Mai visszaállítás-emlékeztető naplója (naponta egyszer ugrik fel).
  static Future<String?> loadRestorePromptDay() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_restorePromptDayKey);
  }

  static Future<void> markRestorePromptShown([DateTime? now]) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_restorePromptDayKey, todayKey(now));
  }

  /// Default game mode: saved choice, else strongest assessed kind, else 0.
  static Future<int> resolveBattleKind(int kindCount) async {
    final saved = await loadBattleKind();
    if (saved != null && saved >= 0 && saved < kindCount) return saved;
    final scores = await loadScores();
    final strongest = strongestKind(scores);
    if (strongest >= 0 && strongest < kindCount) return strongest;
    return 0;
  }

  // ── FSRS-lite kártyák + Meta-gyorsítótár (best-effort, offline) ──

  static const _fsrsCardsKey = 'fsrs_cards_v1';
  static const _metaCacheKey = 'meta_cache_v1';

  /// FSRS-kártyák száma legfeljebb ennyi lehet helyben.
  static const int fsrsCap = 200;

  /// Meta-válaszok gyorsítótára legfeljebb ennyi kulcsot őriz.
  static const int metaCacheCap = 40;

  static Future<void> saveFsrsCards(
    Map<String, String> byCardIdJson,
  ) async {
    await saveFsrsCardsWithoutNotify(byCardIdJson);
    _notifyChanged();
  }

  static Future<void> saveFsrsCardsWithoutNotify(
    Map<String, String> byCardIdJson,
  ) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final entries = byCardIdJson.entries.toList();
      final capped =
          entries.length > fsrsCap
              ? entries.sublist(entries.length - fsrsCap)
              : entries;
      await prefs.setStringList(_fsrsCardsKey, [
        for (final e in capped) '${e.key}=${e.value}',
      ]);
    } catch (_) {
      // Hiba esetén marad a memóriabeli állapot.
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
      final capped =
          list.length > metaCacheCap
              ? list.sublist(list.length - metaCacheCap)
              : list;
      await prefs.setStringList(_metaCacheKey, [
        for (final e in capped) '${e.key}=${e.value}',
      ]);
    } catch (_) {
      // A gyorsítótár csak gyorsítás: hiba esetén eldobjuk.
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
}
