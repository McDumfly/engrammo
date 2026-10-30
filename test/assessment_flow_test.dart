import 'package:engrammo/models/item_banks.dart' show assessmentCategory;
import 'package:engrammo/screens/memory_profile.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  Future<void> scrollSeek(WidgetTester tester, Finder target) async {
    if (target.evaluate().isEmpty) {
      await tester.scrollUntilVisible(
        target,
        200,
        maxScrolls: 20,
      );
      await tester.pumpAndSettle();
    } else {
      await tester.ensureVisible(target);
      await tester.pumpAndSettle();
    }
  }

  Future<void> revealIfNeeded(WidgetTester tester) async {
    final cont = find.text('CONTINUE TO QUESTION');
    if (cont.evaluate().isEmpty) {
      try {
        await tester.scrollUntilVisible(
          cont,
          200,
            maxScrolls: 20,
        );
        await tester.pumpAndSettle();
      } on StateError {
        return;
      }
    }
    final found = find.text('CONTINUE TO QUESTION');
    if (found.evaluate().isNotEmpty) {
      await tester.ensureVisible(found);
      await tester.pumpAndSettle();
      await tester.tap(found);
      await tester.pumpAndSettle();
    }
  }

  Future<void> settleAdvance(WidgetTester tester, int ms) async {
    await tester.pump(Duration(milliseconds: ms));
    await tester.pumpAndSettle();
  }

  Future<void> answerRecall(WidgetTester tester, String text) async {
    await revealIfNeeded(tester);
    await scrollSeek(tester, find.byKey(const ValueKey('recall-input')));
    await tester.enterText(find.byKey(const ValueKey('recall-input')), text);
    await tester.pump();
    await scrollSeek(tester, find.byKey(const ValueKey('recall-check')));
    await tester.tap(find.byKey(const ValueKey('recall-check')));
    await settleAdvance(tester, 1600);
  }

  Future<void> answerCorsi(WidgetTester tester) async {
    await revealIfNeeded(tester);
    await scrollSeek(tester, find.byKey(const ValueKey('corsi-cell-0')));
    await tester.tap(find.byKey(const ValueKey('corsi-cell-0')));
    await tester.pump();
    await scrollSeek(tester, find.byKey(const ValueKey('corsi-done')));
    await tester.tap(find.byKey(const ValueKey('corsi-done')));
    await settleAdvance(tester, 1600);
  }

  Future<void> answerChoice(WidgetTester tester, String option) async {
    await revealIfNeeded(tester);
    await scrollSeek(tester, find.text(option).first);
    await tester.tap(find.text(option).first);
    await settleAdvance(tester, 800);
  }

  testWidgets('13 probes: blind direction, cued sensory, 3-level spatial', (
    WidgetTester tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(
      const MaterialApp(home: MemoryAssessmentPage()),
    );
    await tester.pumpAndSettle();

    expect(find.text('Memory assessment 1/13'), findsOneWidget);

    await revealIfNeeded(tester);
    expect(find.text('What was the 2nd digit? Type it.'), findsOneWidget);
    await answerRecall(tester, '3');

    await revealIfNeeded(tester);
    expect(
      find.text('What were the 2nd and 5th digits? Type them in order.'),
      findsOneWidget,
    );
    await answerRecall(tester, '8 1');

    expect(
      find.text('Hold these digits — the direction comes next!'),
      findsOneWidget,
    );
    expect(
      find.textContaining(RegExp(r'[Rr]evers')),
      findsNothing,
    );
    expect(
      find.textContaining(RegExp(r'[Ff]orward')),
      findsNothing,
    );
    await revealIfNeeded(tester);
    expect(find.text('Type the order REVERSED.'), findsOneWidget);
    expect(find.text('Type the digits'), findsOneWidget);
    expect(find.textContaining('8-1-4'), findsNothing);
    await tester.enterText(
      find.byKey(const ValueKey('recall-input')),
      '8 1 4',
    );
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('recall-check')));
    await settleAdvance(tester, 1600);

    expect(
      find.text('Five digits — the direction comes next, hold them all!'),
      findsOneWidget,
    );
    expect(
      find.textContaining(RegExp(r'[Rr]evers')),
      findsNothing,
    );
    expect(
      find.textContaining(RegExp(r'[Ff]orward')),
      findsNothing,
    );
    await revealIfNeeded(tester);
    expect(find.text('Type the full order FORWARD.'), findsOneWidget);
    expect(find.textContaining('3-9-1-6-2'), findsNothing);
    await tester.enterText(
      find.byKey(const ValueKey('recall-input')),
      '3 9 1 6 2',
    );
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('recall-check')));
    await settleAdvance(tester, 1600);

    expect(
      find.text('Watch the tiles light up — 3 in order!'),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('corsi-stimulus-cell-0')), findsOneWidget);
    expect(find.text('1'), findsNothing);
    expect(find.text('2'), findsNothing);
    expect(find.text('3'), findsNothing);
    await answerCorsi(tester);
    expect(find.text('Watch carefully — 5 tiles in order!'), findsOneWidget);
    expect(find.text('1'), findsNothing);
    await answerCorsi(tester);
    expect(
      find.text('Watch carefully — 6 tiles, at the limit!'),
      findsOneWidget,
    );
    await answerCorsi(tester);

    await answerChoice(tester, 'Same');
    await answerChoice(tester, 'Same');

    await answerRecall(tester, 'some story words');
    await answerRecall(tester, 'more story words');

    final catEasy = assessmentCategory(0, false);
    await answerChoice(tester, catEasy.correct);
    final catHard = assessmentCategory(0, true);
    await answerChoice(tester, catHard.correct);

    expect(find.textContaining('Quick interview'), findsOneWidget);
  });
}
