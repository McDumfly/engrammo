import 'package:engrammo/models/fsrs_card.dart';
import 'package:flutter_test/flutter_test.dart';

FsrsCard card({DateTime? due}) => FsrsCard(
  cardId: 'c1',
  taskId: 't1',
  stability: 1.0,
  difficulty: 5.0,
  due: due ?? DateTime(2026, 10, 27, 12),
);

void main() {
  group('FsrsCard', () {
    test('json korbeir', () {
      final c = card();
      expect(FsrsCard.fromJson(c.toJson()), c);
    });

    test('isDue határesetei', () {
      final now = DateTime(2026, 10, 27, 12);
      expect(card(due: now).isDue(now), isTrue);
      expect(
        card(due: now.add(const Duration(seconds: 1))).isDue(now),
        isFalse,
      );
      expect(
        card(due: now.subtract(const Duration(seconds: 1))).isDue(now),
        isTrue,
      );
    });
  });

  group('FsrsScheduler.next', () {
    test('1-es bukás: stabilitás esik, nehézség nő, lapses nő', () {
      final now = DateTime(2026, 10, 27, 12);
      final next = FsrsScheduler.next(card(due: now), 1, now);
      expect(next.reps, 1);
      expect(next.lapses, 1);
      expect(next.difficulty, greaterThan(5.0));
      expect(next.stability, lessThan(1.0));
      expect(next.due.isAfter(now), isTrue);
    });

    test('4-es könnyű: stabilitás nő legjobban', () {
      final now = DateTime(2026, 10, 27, 12);
      final easy = FsrsScheduler.next(card(due: now), 4, now);
      final good = FsrsScheduler.next(card(due: now), 3, now);
      expect(easy.stability, greaterThan(good.stability));
      expect(easy.reps, 1);
      expect(easy.lapses, 0);
    });

    test('értékelés 1..4-re van vágva', () {
      final now = DateTime(2026, 10, 27, 12);
      final low = FsrsScheduler.next(card(due: now), -5, now);
      final high = FsrsScheduler.next(card(due: now), 99, now);
      expect(low.lapses, 1);
      expect(high.lapses, 0);
      expect(high.stability, greaterThan(1.0));
    });
  });

  group('FsrsScheduler.dueCards', () {
    test('csak az esedékesek, legkorábbi elöl', () {
      final now = DateTime(2026, 10, 27, 12);
      final late = card(due: now.subtract(const Duration(days: 2)));
      final early = card(due: now.subtract(const Duration(days: 5)));
      final future = card(due: now.add(const Duration(days: 1)));
      final due = FsrsScheduler.dueCards([
        late.copyWith(cardId: 'late'),
        early.copyWith(cardId: 'early'),
        future,
      ], now);
      expect(due.map((c) => c.cardId).toList(), ['early', 'late']);
    });
  });
}
