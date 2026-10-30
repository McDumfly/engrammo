import 'package:engrammo/models/foundations.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('isFoundationLesson', () {
    test('az alapozó fejezetek első két leckéje alapozó', () {
      for (final c in [0, 1, 2, 3, 4, 5]) {
        expect(isFoundationLesson(c, 0, 0), isTrue, reason: 'chapter $c');
        expect(isFoundationLesson(c, 0, 1), isTrue, reason: 'chapter $c');
        expect(isFoundationLesson(c, 0, 2), isFalse, reason: 'chapter $c');
        expect(isFoundationLesson(c, 1, 0), isFalse, reason: 'chapter $c');
      }
    });

    test('mély fejezetekben nincs alapozó lecke', () {
      expect(isFoundationLesson(18, 0, 0), isFalse);
      expect(isFoundationLesson(34, 0, 0), isFalse);
      expect(isFoundationLesson(-1, 0, 0), isFalse);
    });
  });

  group('wantsLagIntroduction', () {
    test('csak az alapozó második részében, késleltetésnél', () {
      expect(wantsLagIntroduction(0, 1, 1), isTrue);
      expect(wantsLagIntroduction(0, 1, 0), isFalse);
      expect(wantsLagIntroduction(0, 0, 1), isFalse);
      expect(wantsLagIntroduction(0, 2, 1), isFalse);
      expect(wantsLagIntroduction(18, 0, 1), isFalse);
    });
  });

  group('workedExampleForTrack', () {
    test('minden sávra teljes, nem üres példa', () {
      for (var t = 0; t < 6; t++) {
        final e = workedExampleForTrack(t);
        expect(e.situation, isNotEmpty, reason: 'track $t');
        expect(e.thinkAloud.length, 3, reason: 'track $t');
        expect(e.payoff, isNotEmpty, reason: 'track $t');
      }
      expect(workedExampleForTrack(-1).situation, isNotEmpty);
      expect(workedExampleForTrack(99).situation, isNotEmpty);
    });
  });

  group('stimulus labels', () {
    test('sorszámok angolul helyesek', () {
      expect(stimulusOrdinal(0), '1st');
      expect(stimulusOrdinal(1), '2nd');
      expect(stimulusOrdinal(2), '3rd');
      expect(stimulusOrdinal(3), '4th');
      expect(stimulusOrdinal(9), '10th');
    });

    test('minden feladattípusnak van rövid címkéje', () {
      for (final kind in [
        'sensory',
        'working',
        'sequence',
        'order',
        'duel',
        'number',
        'spatial',
        'visual',
        'pattern',
        'episodic',
        'semantic',
        'verbal',
        'face',
        'foreign',
        'prospective',
        'poem',
        'replay',
        'interference',
      ]) {
        expect(drillKindLabel(kind), isNotEmpty, reason: kind);
        expect(drillKindLabel(kind), isNot('drill'), reason: kind);
      }
      expect(drillKindLabel('typo-kind'), 'drill');
    });

    test('az inger- és kérdéscímke egyértelműen sorszámoz', () {
      expect(stimulusBadge(1, 4, 'number'), 'Drill 2 of 4 · number');
      expect(
        delayedQuestionLead(0, 4, 'number'),
        'About drill 1 of 4 (number):',
      );
      expect(delayedQuestionLead(2, 5, 'replay'), contains('drill 3 of 5'));
    });
  });
}
