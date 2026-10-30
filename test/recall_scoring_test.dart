import 'package:engrammo/models/item_banks.dart';
import 'package:engrammo/models/meta_task.dart';
import 'package:engrammo/models/recall_scoring.dart';
import 'package:flutter_test/flutter_test.dart';

MetaTask _task({
  required String paradigm,
  List<String> items = const [],
  List<String> options = const ['a', 'b', 'c', 'd'],
  int correct = 0,
}) => MetaTask(
      prompt: 'p',
      items: items,
      question: 'q?',
      options: options,
      correct: correct,
      paradigm: paradigm,
      createdAt: DateTime(2026, 1, 1),
    );

void main() {
  group('normalizeAnswer', () {
    test('folds case, accents, punctuation and spaces', () {
      expect(normalizeAnswer('  Ánna’s BLUE-Scarf! '), 'anna s blue scarf');
      expect(normalizeAnswer('3   apples'), '3 apples');
      expect(normalizeAnswer('őűóü'), 'ouou');
    });
  });

  group('levenshtein', () {
    test('known distances', () {
      expect(levenshtein('', ''), 0);
      expect(levenshtein('a', ''), 1);
      expect(levenshtein('kitten', 'sitting'), 3);
      expect(levenshtein('umbrella', 'umbrela'), 1);
    });
  });

  group('fuzzyWordMatch', () {
    test('exact always matches', () {
      expect(fuzzyWordMatch('apple', 'apple'), isTrue);
    });

    test('one typo passes at length 5+, never for short tokens', () {
      expect(fuzzyWordMatch('apples', 'apple'), isTrue);
      expect(fuzzyWordMatch('cat', 'car'), isFalse);
      expect(fuzzyWordMatch('2', '3'), isFalse);
    });

    test('two typos pass only at length 9+', () {
      expect(fuzzyWordMatch('blacksmith', 'blacksmyth'), isTrue);
      expect(fuzzyWordMatch('apples', 'axxesx'), isFalse);
    });
  });

  group('parseDigits / parseCells', () {
    test('digits ignore separators', () {
      expect(parseDigits('8-1-4'), ['8', '1', '4']);
      expect(parseDigits('8 1 4!'), ['8', '1', '4']);
      expect(parseDigits('no digits'), isEmpty);
    });

    test('cells split multi-digit runs (14 = cells 1 then 4)', () {
      expect(parseCells('1,4,7'), [1, 4, 7]);
      expect(parseCells('14'), [1, 4]);
      expect(parseCells('9'), isEmpty);
    });
  });

  group('scoreDigitSpan', () {
    test('exact order scores 1 + exact', () {
      final s = scoreDigitSpan(['8', '1', '4'], '8-1-4');
      expect(s.proportion, 1);
      expect(s.exact, isTrue);
    });

    test('one wrong position gives partial credit, not exact', () {
      final s = scoreDigitSpan(['8', '1', '4'], '8-2-4');
      expect(s.proportion, closeTo(2 / 3, 1e-9));
      expect(s.exact, isFalse);
      expect(s.detail, contains('2/3'));
    });

    test('short and empty responses score low, never throw', () {
      expect(scoreDigitSpan(['8', '1', '4'], '8').proportion, closeTo(1 / 3, 1e-9));
      expect(scoreDigitSpan(['8', '1', '4'], '').proportion, 0);
      expect(scoreDigitSpan([], '8').proportion, 0);
    });
  });

  group('scoreSingleToken', () {
    test('exact and embedded answers count', () {
      expect(scoreSingleToken('7', '7').exact, isTrue);
      final embedded = scoreSingleToken('7', 'the answer is 7');
      expect(embedded.proportion, 1);
      expect(embedded.exact, isFalse);
    });

    test('near-miss typo earns 0.75 in a longer reply', () {
      final s = scoreSingleToken('umbrella', 'a red umbrela I think');
      expect(s.proportion, 0.75);
      expect(s.exact, isFalse);
    });

    test('wrong token misses', () {
      expect(scoreSingleToken('7', 'nine').proportion, 0);
    });
  });

  group('scoreStoryRecall', () {
    final units = assessmentStory(0, false).units;

    test('full retell hits every idea unit', () {
      final s = scoreStoryRecall(
        units,
        'Yesterday Anna bought three apples and a blue scarf.',
      );
      expect(s.proportion, 1);
      expect(s.exact, isTrue);
    });

    test('partial retell earns partial credit', () {
      final s = scoreStoryRecall(units, 'Anna bought apples');
      expect(s.proportion, closeTo(2 / 3, 1e-9));
      expect(s.detail, contains('2/3'));
    });

    test('digit/word forms both count', () {
      final s = scoreStoryRecall(units, 'anna 3 apples scarf');
      expect(s.proportion, 1);
    });
  });

  group('scoreOrderedCells', () {
    test('order errors are errors (Corsi is sequential)', () {
      final swapped = scoreOrderedCells([0, 8], [8, 0]);
      expect(swapped.proportion, 0);
      expect(swapped.exact, isFalse);
      final exact = scoreOrderedCells([0, 4, 2], [0, 4, 2]);
      expect(exact.proportion, 1);
      expect(exact.exact, isTrue);
    });

    test('partial prefix earns partial credit', () {
      final s = scoreOrderedCells([0, 4, 2, 8], [0, 4, 8]);
      expect(s.proportion, 0.5);
    });
  });

  group('scoreCellSet', () {
    test('extra guesses are penalized, not free', () {
      final exact = scoreCellSet([1, 4, 7], '1,4,7');
      expect(exact.proportion, 1);
      final extra = scoreCellSet([1, 4, 7], '1,4,7,0');
      expect(extra.proportion, closeTo(2 / 3, 1e-9));
      final wild = scoreCellSet([1], '0,2,3');
      expect(wild.proportion, 0);
    });
  });

  group('scoreTaskRecall', () {
    test('backward span scores against the reversed key', () {
      final t = _task(
        paradigm: 'backward-span',
        items: ['4', '1', '8'],
        options: ['4-1-8', '8-4-1', '8-1-4', '1-8-4'],
        correct: 2,
      );
      expect(scoreTaskRecall(t, '8-1-4').exact, isTrue);
      expect(scoreTaskRecall(t, '8-1-5').proportion, closeTo(2 / 3, 1e-9));
    });

    test('banked story uses idea units, not the MCQ key', () {
      final story = assessmentStory(2, true);
      final t = _task(
        paradigm: 'story-recall',
        items: [story.text],
        options: [story.correct, ...story.lures],
      );
      final full = scoreTaskRecall(
        t,
        'Eva sold three lamps and a wooden clock at the fair, paid Ben at 7',
      );
      expect(full.proportion, 1);
      final thin = scoreTaskRecall(t, 'Eva sold lamps');
      expect(thin.proportion, closeTo(2 / 5, 1e-9));
    });

    test('unbanked (AI) story falls back to phrase recall', () {
      final t = _task(
        paradigm: 'story-recall',
        items: ['Some fresh AI tale nobody banked.'],
        options: ['green bicycle', 'red car', 'blue boat', 'long train'],
      );
      expect(scoreTaskRecall(t, 'a GREEN bicycle').proportion, 1);
      expect(scoreTaskRecall(t, 'something else').proportion, 0);
    });

    test('single-word paradigms accept the typed key', () {
      final t = _task(
        paradigm: 'paired-associate',
        items: ['hammer → candle'],
        options: ['candle', 'bridge', 'lamp', 'key'],
      );
      expect(scoreTaskRecall(t, 'candle').exact, isTrue);
      expect(scoreTaskRecall(t, 'bridge').proportion, 0);
    });

    test('brown-peterson scores letters in place', () {
      final t = _task(
        paradigm: 'brown-peterson',
        items: ['XJR'],
        options: ['XJR', 'KPL', 'ZVM', 'BQT'],
      );
      expect(scoreTaskRecall(t, 'xjr').exact, isTrue);
      expect(
        scoreTaskRecall(t, 'xjk').proportion,
        closeTo(2 / 3, 1e-9),
      );
    });

    test('unknown paradigm and bad key never throw', () {
      final t = _task(
        paradigm: 'mystery',
        options: ['apple', 'pear', 'plum', 'peach'],
      );
      expect(scoreTaskRecall(t, 'apple').proportion, 1);
      final bad = _task(paradigm: 'backward-span', correct: 9);
      expect(scoreTaskRecall(bad, '1-2').proportion, 0);
    });
  });
}
