import 'package:engrammo/screens/battle_zone.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('memoryLevelForScore', () {
    test('mérés nélkül, 0 pont az 1-es szint', () {
      expect(memoryLevelForScore(0), 1);
    });

    test('a profilképlettel egyezik a példa pontszámokon', () {
      expect(memoryLevelForScore(55), 6);
      expect(memoryLevelForScore(61), 7);
      expect(memoryLevelForScore(74), 8);
      expect(memoryLevelForScore(86), 9);
      expect(memoryLevelForScore(68), 7);
      expect(memoryLevelForScore(48), 5);
    });

    test('100 pont a legmagasabb szint', () {
      expect(memoryLevelForScore(100), 11);
    });
  });
}
