import 'dart:math';

/// Tiszta (UI-független) széria-segédek, a kreeds-app
/// `streak_week.dart`-jából átvéve és helyi modellre szabva.
///
/// Minden összehasonlítás dátum-alapú: [now] előbb éjfélre
/// normalizálódik, így a mai nap a pontos időtől függetlenül
/// sosem számít jövőbeli napnak.
DateTime _day(DateTime d) => DateTime(d.year, d.month, d.day);

/// Naptári napok különbsége DST-biztosan: hány napot kell [b]-hez
/// adni, hogy [a] napját kapjuk (tegnap→ma = 1).
///
/// A sima `difference().inDays` az óraátállításkor megcsúszik (a
/// 23 órás nap 0-nak, a 25 órás 1-nél többnek látszana), ezért
/// mindkét napot UTC-éjfélre vetítjük, ahol minden nap 24 óra.
int dayDiff(DateTime a, DateTime b) {
  final x = DateTime.utc(a.year, a.month, a.day);
  final y = DateTime.utc(b.year, b.month, b.day);
  return x.difference(y).inDays;
}

/// Egy naptár-bejegyzés dátummá alakítása. A helyi tároló
/// ISO-stringeket ír, de a `DateTime`-ot, milliszekundum-számot
/// és timestamp-szerű térképet is elfogadja — különben null.
/// Mindig éjfélre normált napot ad.
DateTime? parseStreakDate(Object? entry) {
  if (entry == null) return null;
  if (entry is DateTime) return _day(entry);
  if (entry is int) {
    try {
      return _day(DateTime.fromMillisecondsSinceEpoch(entry));
    } catch (_) {
      return null;
    }
  }
  if (entry is String) {
    final parsed = DateTime.tryParse(entry);
    return parsed == null ? null : _day(parsed);
  }
  if (entry is Map) {
    final seconds =
        entry['seconds'] ?? entry['_seconds'] ?? entry['secondsSinceEpoch'];
    if (seconds is num) {
      final nanos = entry['nanoseconds'] ?? entry['_nanoseconds'] ?? 0;
      final millis =
          seconds.toInt() * 1000 +
          ((nanos is num ? nanos.toInt() : 0) ~/ 1000000);
      try {
        return _day(DateTime.fromMillisecondsSinceEpoch(millis));
      } catch (_) {
        return null;
      }
    }
    final millis = entry['millisecondsSinceEpoch'];
    if (millis is num) {
      try {
        return _day(DateTime.fromMillisecondsSinceEpoch(millis.toInt()));
      } catch (_) {
        return null;
      }
    }
    return null;
  }
  // Firestore-szerű Timestamp (duck-typing, Firestore-import nélkül):
  // van `toDate()` metódusa.
  try {
    final converted = (entry as dynamic).toDate();
    if (converted is DateTime) return _day(converted);
  } catch (_) {
    // Nem dátumszerű bejegyzés: eldobjuk.
  }
  return null;
}

/// Nyers `streakHistory`-lista dátumlistává alakítása: ismeretlen
/// formátumú bejegyzések kiesnek, duplikátumok összevonódnak,
/// az eredmény rendezett és éjfélre normált.
List<DateTime> parseStreakHistory(Object? raw) {
  if (raw is! List) return const [];
  final days = <DateTime>{};
  for (final entry in raw) {
    final parsed = parseStreakDate(entry);
    if (parsed != null) days.add(parsed);
  }
  final sorted = days.toList()..sort();
  return sorted;
}

/// Az élő összefüggő szakasz hossza: ha a naptár vége ma vagy tegnap,
/// a visszafelé számolt egymást követő napok száma, különben 0.
/// A "tegnapi vég + ma még éjfélig teljesíthető" eset tehát élőnek
/// számít — ilyenkor nem nullázható a kijelzett széria.
int currentRunLength({
  required List<DateTime> history,
  required DateTime today,
}) {
  if (history.isEmpty) return 0;
  final t = _day(today);
  final days = history.map(_day).toSet().toList()..sort();
  final last = days.last;
  final gap = dayDiff(t, last);
  // Jövőbeli utolsó nap vagy 2+ napos szakadás: nincs élő szakasz.
  if (gap < 0 || gap > 1) return 0;
  var run = 1;
  var cursor = last;
  for (var i = days.length - 2; i >= 0; i--) {
    if (dayDiff(cursor, days[i]) == 1) {
      run++;
      cursor = days[i];
    } else {
      break;
    }
  }
  return run;
}

/// A naptárban valaha volt leghosszabb összefüggő szakasz (a csúcs
/// alsó becslése — egy tévesen nullázott `bestStreak` helyreállításához).
int maxRunLength(List<DateTime> history) {
  if (history.isEmpty) return 0;
  final days = history.map(_day).toSet().toList()..sort();
  var best = 1;
  var run = 1;
  for (var i = 1; i < days.length; i++) {
    if (dayDiff(days[i], days[i - 1]) == 1) {
      run++;
      best = max(best, run);
    } else {
      run = 1;
    }
  }
  return best;
}

/// A kijelzendő széria: élő szakasz esetén legalább a naptárból
/// számolt hossz (így egy tévesen lenullázott számláló sem mutat 0-t,
/// amíg a tegnapi/mai nap megvan), holt szakasz esetén a türelmi időn
/// belül még a tárolt érték, azon túl 0.
int effectiveStreak({
  required int stored,
  required List<DateTime> history,
  required DateTime today,
  required int maxMissedDays,
}) {
  final safeStored = stored < 0 ? 0 : stored;
  final run = currentRunLength(history: history, today: today);
  if (run > 0) return max(safeStored, run);
  if (history.isEmpty) return safeStored;
  final lastDay = history.map(_day).toList()..sort();
  if (!streakGraceExpired(
    lastDay: lastDay.last,
    today: today,
    maxMissedDays: maxMissedDays,
  )) {
    return safeStored;
  }
  return 0;
}

/// A széria utolsó napja a `stamped` ([lastStreakDate]) és a
/// `streakHistory` utolsó napja ([historyLast]) közül a frissebb.
/// A `stamped` csak visszaállításkor íródik, a napi cél a
/// naptárat bővíti — önmagában a mező elavult lehet, ezért a frissebb
/// naptár nem veszhet el. Mindkettő éjfélre normált vagy normálható nap.
DateTime? latestStreakDay({DateTime? stamped, DateTime? historyLast}) {
  if (stamped == null) return historyLast;
  if (historyLast == null) return stamped;
  return historyLast.isAfter(stamped) ? historyLast : stamped;
}

/// A csúcs (`bestStreak`) követi az aktuális szériát: ha a mostani
/// nagyobb, a csúcs felzárkózik, különben marad. Tiszta függvény.
int nextBestStreak({required int bestStreak, required int streak}) =>
    streak > bestStreak ? streak : bestStreak;

/// Lejárt-e a türelmi idő: csak akkor nullázható a kijelzett széria,
/// ha a szakadás már engramért sem pótolható ([maxMissedDays]-nél több
/// kihagyott nap). Amíg a visszaállítási ablak nyitva, az érték megmarad.
bool streakGraceExpired({
  required DateTime lastDay,
  required DateTime today,
  required int maxMissedDays,
}) {
  return dayDiff(today, lastDay) > maxMissedDays + 1;
}

/// Nap-azonosító a napi gyorsítótárhoz: a nap dátuma (pl. "2026-09-07").
String dayId(DateTime now) {
  final mm = now.month.toString().padLeft(2, '0');
  final dd = now.day.toString().padLeft(2, '0');
  return '${now.year}-$mm-$dd';
}
