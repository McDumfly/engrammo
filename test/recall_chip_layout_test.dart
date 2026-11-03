import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:engrammo/screens/benchmark.dart';

void main() {
  test('két közeli tárgy címkéje nem fedi egymást', () {
    // Plant pot right next to the dresser: their centred chips collide.
    final slots = layoutRecallChips(
      const [Rect.fromLTWH(40, 200, 50, 80), Rect.fromLTWH(70, 210, 40, 70)],
      const [110, 90],
      360,
      360,
    );
    expect(slots[0].overlaps(slots[1]), isFalse);
    for (final r in slots) {
      expect(r.left >= 0 && r.right <= 360, isTrue);
      expect(r.top >= 0 && r.bottom <= 360, isTrue);
    }
  });

  test('a kép alján felfelé tér ki', () {
    final slots = layoutRecallChips(
      const [Rect.fromLTWH(40, 300, 50, 60), Rect.fromLTWH(60, 300, 50, 60)],
      const [100, 100],
      360,
      360,
    );
    expect(slots[0].overlaps(slots[1]), isFalse);
    expect(slots[1].bottom <= 360, isTrue);
  });

  test('húsz pixelre lévő dobozok címkéi sem fedik egymást', () {
    // Lamp right below the plant pot, 20 px apart: chips must not collide.
    final slots = layoutRecallChips(
      const [Rect.fromLTWH(100, 100, 60, 60), Rect.fromLTWH(110, 180, 60, 60)],
      const [110, 100],
      360,
      360,
    );
    expect(slots[0].overlaps(slots[1]), isFalse);
    for (final r in slots) {
      expect(r.left >= 0 && r.right <= 360, isTrue);
      expect(r.top >= 0 && r.bottom <= 360, isTrue);
    }
  });

  test('a keskeny tárgy nem vágja le a címkét', () {
    final slots = layoutRecallChips(
      const [Rect.fromLTWH(150, 100, 20, 40)],
      const [120],
      360,
      360,
    );
    expect(slots.single.width, 120);
  });
}
