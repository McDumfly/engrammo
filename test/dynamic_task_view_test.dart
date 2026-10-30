import 'package:engrammo/models/dynamic_task.dart';
import 'package:engrammo/widgets/dynamic_task_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

DynamicTask _task() => DynamicTask(
  id: 'w1',
  title: 'My test task',
  instructions: 'Answer every block.',
  targetId: 'todos-errands',
  blocks: const [
    DynamicBlock(type: 'info', id: 'b0', label: 'Chain items in order.'),
    DynamicBlock(
      type: 'choice',
      id: 'b1',
      label: 'What comes first?',
      options: ['milk', 'keys', 'letter', 'bread'],
      answer: '0',
    ),
    DynamicBlock(
      type: 'text',
      id: 'b2',
      label: 'Retell the chain:',
      answer: 'milk keys letter',
    ),
    DynamicBlock(
      type: 'checklist',
      id: 'b3',
      label: 'Lock it in:',
      options: ['recall once', 'check source'],
    ),
    DynamicBlock(
      type: 'order',
      id: 'b4',
      label: 'Tap in order:',
      options: ['milk', 'keys', 'letter'],
      answer: '0,1,2',
    ),
  ],
  createdAt: DateTime(2026, 1, 1),
);

Future<void> _open(WidgetTester tester, DynamicTask task) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(child: DynamicTaskView(task: task)),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _tapVisible(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

void main() {
  group('DynamicTaskView', () {
    testWidgets('minden blokk kirajzolódik, folyamatjelző indul', (
      tester,
    ) async {
      await _open(tester, _task());
      expect(find.text('My test task · 0/5 done'), findsOneWidget);
      expect(
        find.byKey(const ValueKey('dynamic-progress')),
        findsOneWidget,
      );
      for (final id in ['b0', 'b1', 'b2', 'b3', 'b4']) {
        expect(
          find.byKey(ValueKey('dynamic-block-$id')),
          findsOneWidget,
        );
      }
      expect(find.byKey(const ValueKey('dynamic-finish')), findsNothing);
    });

    testWidgets('választás után halad a sáv és visszajelez', (tester) async {
      await _open(tester, _task());
      await tester.tap(find.byKey(const ValueKey('dynamic-gotit-b0')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('dynamic-option-b1-0')));
      await tester.pumpAndSettle();
      expect(find.text('My test task · 2/5 done'), findsOneWidget);
    });

    testWidgets('szöveg kulccsal: helyes és hibás ág', (tester) async {
      await _open(tester, _task());
      await tester.enterText(
        find.byKey(const ValueKey('dynamic-input-b2')),
        'milk keys letter',
      );
      await tester.tap(find.byKey(const ValueKey('dynamic-submit-b2')));
      await tester.pumpAndSettle();
      expect(find.text('Correct — locked in.'), findsOneWidget);
    });

    testWidgets('checklista csak teljesen kész', (tester) async {
      await _open(tester, _task());
      await _tapVisible(
        tester,
        find.byKey(const ValueKey('dynamic-checklist-b3-0')),
      );
      expect(find.text('My test task · 0/5 done'), findsOneWidget);
      await _tapVisible(
        tester,
        find.byKey(const ValueKey('dynamic-checklist-b3-1')),
      );
      expect(find.text('My test task · 1/5 done'), findsOneWidget);
    });

    testWidgets('sorrend: csak a pontos sorrend helyes', (tester) async {
      await _open(tester, _task());
      Future<void> tapChip(String label) async {
        final chip = find.ancestor(
          of: find.text(label),
          matching: find.byType(ActionChip),
        );
        await _tapVisible(tester, chip.first);
      }

      await tapChip('keys');
      await tapChip('milk');
      await tapChip('letter');
      await _tapVisible(
        tester,
        find.byKey(const ValueKey('dynamic-order-check-b4')),
      );
      expect(find.textContaining('Not quite'), findsOneWidget);
    });

    testWidgets('minden blokk után FINISH és eredmény', (tester) async {
      DynamicTaskResult? got;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: DynamicTaskView(task: _task(), onDone: (r) => got = r),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await _tapVisible(
        tester,
        find.byKey(const ValueKey('dynamic-gotit-b0')),
      );
      await _tapVisible(
        tester,
        find.byKey(const ValueKey('dynamic-option-b1-0')),
      );
      await tester.ensureVisible(
        find.byKey(const ValueKey('dynamic-input-b2')),
      );
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const ValueKey('dynamic-input-b2')),
        'milk keys letter',
      );
      await _tapVisible(
        tester,
        find.byKey(const ValueKey('dynamic-submit-b2')),
      );
      await _tapVisible(
        tester,
        find.byKey(const ValueKey('dynamic-checklist-b3-0')),
      );
      await _tapVisible(
        tester,
        find.byKey(const ValueKey('dynamic-checklist-b3-1')),
      );
      Future<void> tapChip(String label) async {
        final chip = find.ancestor(
          of: find.text(label),
          matching: find.byType(ActionChip),
        );
        await _tapVisible(tester, chip.first);
      }

      await tapChip('milk');
      await tapChip('keys');
      await tapChip('letter');
      await _tapVisible(
        tester,
        find.byKey(const ValueKey('dynamic-order-check-b4')),
      );
      expect(find.text('My test task · 5/5 done'), findsOneWidget);
      await _tapVisible(
        tester,
        find.byKey(const ValueKey('dynamic-finish')),
      );
      expect(got, isNotNull);
      expect(got!.complete, isTrue);
      expect(got!.keyed, 3);
      expect(got!.correct, 3);
    });
  });
}
