import 'dart:math' as math;

import 'package:engrammo/models/item_banks.dart';
import 'package:engrammo/models/meta_task.dart';
import 'package:engrammo/models/recall_scoring.dart';
import 'package:engrammo/models/validated_tasks.dart' show localValidatedTask;
import 'package:engrammo/screens/assessment_interview.dart';
import 'package:engrammo/screens/memory_profile.dart';
import 'package:engrammo/theme/app_colors.dart' as palette;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('backward-span key is the reversed forward sequence', () {
    test('options[correct] == items reversed, every kind/difficulty/seed', () {
      const kinds = ['working', 'sequence', 'order', 'duel'];
      for (final kind in kinds) {
        for (var d = 1; d <= 5; d++) {
          for (var s = 0; s < 5; s++) {
            final task = localValidatedTask(
              MetaTaskRequest(
                kind: kind,
                difficulty: d,
                seed: 'fix8-$kind-$d-$s',
                locale: 'en',
              ),
            );
            expect(task.paradigm, 'backward-span');
            final key = task.options[task.correct];
            expect(
              key,
              task.items.reversed.join('-'),
              reason: 'key must reverse items: $kind d$d seed $s',
            );
            expect(
              parseDigits(key),
              task.items.reversed.toList(),
              reason: 'key digits must match items reversed: $kind d$d',
            );
          }
        }
      }
    });

    test('typing the reversed key scores exact, forward does not', () {
      final task = localValidatedTask(
        const MetaTaskRequest(
          kind: 'working',
          difficulty: 3,
          seed: 'fix8-exact',
          locale: 'en',
        ),
      );
      final key = task.options[task.correct];
      expect(scoreTaskRecall(task, key).exact, isTrue);
      final forward = task.items.join('-');
      if (forward != key) {
        expect(scoreTaskRecall(task, forward).exact, isFalse);
      }
    });
  });

  group('pattern-span scoring branch (unified set rule)', () {
    MetaTask patternTask(List<String> items) => MetaTask(
      prompt: 'p',
      items: items,
      question: 'q?',
      options: const ['1,4,7', '0,4,7', '1,2,7', '1,4,8'],
      correct: 0,
      paradigm: 'pattern-span',
      createdAt: DateTime(2026, 1, 1),
    );

    test('routes through scoreCellSet over task.items', () {
      final task = patternTask(['1', '4', '7']);
      for (final response in ['1,4,7', '7,4,1', '1,4,7,0', '1,4', '0,2,3']) {
        final viaBranch = scoreTaskRecall(task, response);
        final direct = scoreCellSet([1, 4, 7], response);
        expect(
          viaBranch.proportion,
          closeTo(direct.proportion, 1e-9),
          reason: 'branch must equal set rule for "$response"',
        );
        expect(viaBranch.exact, direct.exact, reason: '"$response"');
      }
    });

    test('set semantics: order-free, extras penalized, partial credit', () {
      final task = patternTask(['1', '4', '7']);
      final reordered = scoreTaskRecall(task, '7,4,1');
      expect(reordered.proportion, 1);
      expect(reordered.exact, isTrue);
      final extra = scoreTaskRecall(task, '1,4,7,0');
      expect(extra.proportion, closeTo(2 / 3, 1e-9));
      expect(extra.exact, isFalse);
      final partial = scoreTaskRecall(task, '1,4');
      expect(partial.proportion, closeTo(2 / 3, 1e-9));
      expect(partial.exact, isFalse);
      expect(scoreTaskRecall(task, '0,2,3').proportion, 0);
    });

    test('non-cell items are ignored, never throw', () {
      final task = patternTask(['1', 'x', '4', '9', '7']);
      expect(scoreTaskRecall(task, '1,4,7').exact, isTrue);
      final empty = patternTask(['x', '9']);
      expect(scoreTaskRecall(empty, '1,4,7').proportion, 0);
    });
  });

  group('interview Skip button', () {
    testWidgets('Skip lands on the result page without answering', (
      tester,
    ) async {
      SharedPreferences.setMockInitialValues({});
      await tester.pumpWidget(
        const MaterialApp(
          home: AssessmentInterviewPage(
            scores: [100, 80, 60, 40, 20, 0],
            hardHits: [1, 0, 0, 0, 0, 0],
            latenciesMs: [1000, 1000, 1000, 1000, 1000, 1000],
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Skip'), findsOneWidget);
      await tester.tap(find.text('Skip'));
      await tester.pumpAndSettle();
      expect(find.byType(MemoryResultPage), findsOneWidget);
    });
  });

  group('fixed palette holds WCAG AA (>= 4.5:1)', () {
    const white = Color(0xFFFFFFFF);

    test('text pairs on their backgrounds', () {
      expect(_ratio(palette.muted, white), greaterThanOrEqualTo(4.5));
      expect(_ratio(palette.ink, white), greaterThanOrEqualTo(4.5));
      expect(_ratio(white, palette.blueDark), greaterThanOrEqualTo(4.5));
      expect(_ratio(white, palette.tealDark), greaterThanOrEqualTo(4.5));
      expect(_ratio(white, palette.coralDark), greaterThanOrEqualTo(4.5));
    });
  });

  group('Forms A-D share no answers, decoys, or names', () {
    test('story answers + decoys are disjoint across forms (English-only)', () {
      for (final bank in [assessmentStories]) {
        final optionsByForm = <int, Set<String>>{};
        for (final s in bank) {
          optionsByForm.putIfAbsent(s.form, () => <String>{}).addAll([
            s.correct.toLowerCase(),
            ...s.lures.map((l) => l.toLowerCase()),
          ]);
        }
        expect(optionsByForm.keys.toSet(), {0, 1, 2, 3});
        for (var f = 0; f < 4; f++) {
          for (var g = f + 1; g < 4; g++) {
            expect(
              optionsByForm[f]!.intersection(optionsByForm[g]!),
              isEmpty,
              reason: 'forms $f/$g share no story answer or decoy',
            );
          }
        }
      }
    });

    test('story agent names are unique across forms (English-only)', () {
      for (final bank in [assessmentStories]) {
        final agents = [for (final s in bank) s.units.first.label.toLowerCase()];
        expect(agents.toSet().length, agents.length);
      }
    });

    test('category answers + decoys + labels disjoint across forms', () {
      for (final bank in [assessmentCategories]) {
        final wordsByForm = <int, Set<String>>{};
        for (final c in bank) {
          wordsByForm.putIfAbsent(c.form, () => <String>{}).addAll([
            c.category.toLowerCase(),
            c.correct.toLowerCase(),
            ...c.lures.map((l) => l.toLowerCase()),
          ]);
        }
        for (var f = 0; f < 4; f++) {
          for (var g = f + 1; g < 4; g++) {
            expect(
              wordsByForm[f]!.intersection(wordsByForm[g]!),
              isEmpty,
              reason: 'forms $f/$g share no category word',
            );
          }
        }
      }
    });
  });
}

double _luminance(Color c) {
  double f(int channel) {
    final v = channel / 255;
    return v <= 0.03928
        ? v / 12.92
        : math.pow((v + 0.055) / 1.055, 2.4).toDouble();
  }

  final argb = c.toARGB32();
  return 0.2126 * f((argb >> 16) & 0xFF) +
      0.7152 * f((argb >> 8) & 0xFF) +
      0.0722 * f(argb & 0xFF);
}

double _ratio(Color a, Color b) {
  final l1 = _luminance(a);
  final l2 = _luminance(b);
  final hi = l1 > l2 ? l1 : l2;
  final lo = l1 > l2 ? l2 : l1;
  return (hi + 0.05) / (lo + 0.05);
}
