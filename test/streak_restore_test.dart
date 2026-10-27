import 'package:engrammo/utils/streak_restore.dart';
import 'package:engrammo/utils/streak_utils.dart';
import 'package:flutter_test/flutter_test.dart';

DateTime d(int y, int m, int day) => DateTime(y, m, day);

void main() {
  group('streakRestoreCost', () {
    test('fix 450 engram 1 és 2 napra is', () {
      expect(StreakRestore.streakRestoreCost(1), 450);
      expect(StreakRestore.streakRestoreCost(2), 450);
    });
  });

  group('isStreakBroken', () {
    test('szakadás után igaz', () {
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      expect(
        StreakRestore.isStreakBroken(
          stored: 5,
          history: [
            today.subtract(const Duration(days: 3)),
            today.subtract(const Duration(days: 2)),
          ],
          today: today,
        ),
        isTrue,
      );
    });

    test('élő szériánál és üres naptárnál hamis', () {
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      expect(
        StreakRestore.isStreakBroken(
          stored: 5,
          history: [today.subtract(const Duration(days: 1)), today],
          today: today,
        ),
        isFalse,
      );
      expect(
        StreakRestore.isStreakBroken(stored: 5, history: const [], today: today),
        isFalse,
      );
    });
  });

  group('shouldShowRestorePrompt', () {
    test('naponta egyszer', () {
      expect(
        StreakRestore.shouldShowRestorePrompt(
          lastPromptDay: null,
          todayKey: '2026-09-14',
        ),
        isTrue,
      );
      expect(
        StreakRestore.shouldShowRestorePrompt(
          lastPromptDay: '2026-09-14',
          todayKey: '2026-09-14',
        ),
        isFalse,
      );
      expect(
        StreakRestore.shouldShowRestorePrompt(
          lastPromptDay: '2026-09-13',
          todayKey: '2026-09-14',
        ),
        isTrue,
      );
    });
  });

  group('planStreakRestore', () {
    test('egy kihagyott nap: pótolja, a széria folytatódik', () {
      final history = [d(2026, 9, 8), d(2026, 9, 9), d(2026, 9, 10)];
      final plan = StreakRestore.planStreakRestore(
        history: history,
        today: d(2026, 9, 12),
      );

      expect(plan, isNotNull);
      expect(plan!.missedDays, 1);
      expect(plan.filledDays, [d(2026, 9, 11)]);
      // 3 napos szakasz + 1 pótolt = 4; a mai olvasás viszi 5-re.
      expect(plan.restoredStreak, 4);
      expect(plan.lastDate, d(2026, 9, 11));
    });

    test('ma már teljesített, de van szakadás: a mait is beleszámolja', () {
      final history = [d(2026, 9, 9), d(2026, 9, 10), d(2026, 9, 12)];
      final plan = StreakRestore.planStreakRestore(
        history: history,
        today: d(2026, 9, 12),
      );

      expect(plan, isNotNull);
      expect(plan!.missedDays, 1);
      expect(plan.filledDays, [d(2026, 9, 11)]);
      expect(plan.restoredStreak, 4);
      expect(plan.lastDate, d(2026, 9, 12));
    });

    test('két kihagyott nap még visszaállítható', () {
      final history = [d(2026, 9, 7), d(2026, 9, 8)];
      final plan = StreakRestore.planStreakRestore(
        history: history,
        today: d(2026, 9, 11),
      );

      expect(plan, isNotNull);
      expect(plan!.missedDays, 2);
      expect(plan.filledDays, [d(2026, 9, 9), d(2026, 9, 10)]);
      expect(plan.restoredStreak, 4);
    });

    test('három kihagyott nap már nem állítható vissza', () {
      final history = [d(2026, 9, 7), d(2026, 9, 8)];
      expect(
        StreakRestore.planStreakRestore(history: history, today: d(2026, 9, 12)),
        isNull,
      );
    });

    test('élő széria: nincs terv', () {
      final history = [d(2026, 9, 10), d(2026, 9, 11)];
      expect(
        StreakRestore.planStreakRestore(history: history, today: d(2026, 9, 12)),
        isNull,
      );
      expect(
        StreakRestore.planStreakRestore(history: history, today: d(2026, 9, 11)),
        isNull,
      );
    });

    test('üres naptár és túl régi szakadás: nincs terv', () {
      expect(
        StreakRestore.planStreakRestore(
          history: const [],
          today: d(2026, 9, 12),
        ),
        isNull,
      );
      final old = [d(2026, 8, 1), d(2026, 8, 2)];
      expect(
        StreakRestore.planStreakRestore(history: old, today: d(2026, 9, 12)),
        isNull,
      );
    });

    test('régi szakadás nem számít bele az új szakaszba', () {
      final history = [
        d(2026, 8, 1),
        d(2026, 8, 2),
        d(2026, 8, 3),
        d(2026, 9, 10),
      ];
      final plan = StreakRestore.planStreakRestore(
        history: history,
        today: d(2026, 9, 12),
      );

      expect(plan, isNotNull);
      // Csak a szept. 10-i 1 napos szakasz + 1 pótolt.
      expect(plan!.restoredStreak, 2);
    });
  });

  group('restoreDayKeys', () {
    test('a pótolt napok napkulcsai', () {
      final plan = StreakRestore.planStreakRestore(
        history: [d(2026, 10, 1), d(2026, 10, 2), d(2026, 10, 3)],
        today: d(2026, 10, 5),
      )!;
      expect(StreakRestore.restoreDayKeys(plan), ['2026-10-04']);
    });
  });

  group('displayStreak', () {
    test('lenullázott számláló élő naptárnál a naptár hosszát mutatja', () {
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final history = [
        today.subtract(const Duration(days: 2)),
        today.subtract(const Duration(days: 1)),
        today,
      ];
      expect(
        StreakRestore.displayStreak(stored: 0, history: history, today: today),
        3,
      );
    });

    test('üres naptárnál a tárolt érték', () {
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      expect(
        StreakRestore.displayStreak(stored: 5, history: const [], today: today),
        5,
      );
    });

    test('a nagyobb tárolt érték megmarad', () {
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final history = [today.subtract(const Duration(days: 1)), today];
      expect(
        StreakRestore.displayStreak(stored: 7, history: history, today: today),
        7,
      );
    });

    test('régen megszakadt széria: 0', () {
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final history = [
        today.subtract(const Duration(days: 10)),
        today.subtract(const Duration(days: 9)),
      ];
      expect(
        StreakRestore.displayStreak(stored: 3, history: history, today: today),
        0,
      );
    });
  });

  group('streakGraceExpired', () {
    test('1-2 kihagyott nap még türelmi idő (visszaállítható)', () {
      expect(
        streakGraceExpired(
          lastDay: d(2026, 10, 12),
          today: d(2026, 10, 14),
          maxMissedDays: 2,
        ),
        isFalse,
      );
      expect(
        streakGraceExpired(
          lastDay: d(2026, 10, 11),
          today: d(2026, 10, 14),
          maxMissedDays: 2,
        ),
        isFalse,
      );
    });

    test('3 kihagyott nap után lejár (már nem visszaállítható)', () {
      expect(
        streakGraceExpired(
          lastDay: d(2026, 10, 10),
          today: d(2026, 10, 14),
          maxMissedDays: 2,
        ),
        isTrue,
      );
    });
  });

  group('parseStreakHistory', () {
    test('vegyes formátumú bejegyzéseket is elfogad', () {
      final history = parseStreakHistory([
        d(2026, 10, 12),
        d(2026, 10, 13).toIso8601String(),
        d(2026, 10, 14).millisecondsSinceEpoch,
        {'seconds': d(2026, 10, 11).millisecondsSinceEpoch ~/ 1000},
        null,
        'nem-dátum',
      ]);
      expect(history, [
        d(2026, 10, 11),
        d(2026, 10, 12),
        d(2026, 10, 13),
        d(2026, 10, 14),
      ]);
    });
  });
}
