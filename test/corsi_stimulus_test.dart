import 'package:engrammo/widgets/recall_inputs.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const teal = Color(0xFF0B7E72);

  Color? cellColor(WidgetTester tester, int cell) {
    final container = tester.widget<Container>(
      find.byKey(ValueKey('corsi-stimulus-cell-$cell')),
    );
    final decoration = container.decoration;
    if (decoration is BoxDecoration) return decoration.color;
    return null;
  }

  List<int> litCells(WidgetTester tester) {
    return [
      for (var cell = 0; cell < 9; cell++)
        if (cellColor(tester, cell) == teal) cell,
    ];
  }

  testWidgets('flashes cells one at a time in order, never numbered', (
    WidgetTester tester,
  ) async {
    const sequence = [0, 8, 4];
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: CorsiSequenceStimulus(
            sequence: sequence,
            startDelay: Duration(milliseconds: 400),
            onTime: Duration(milliseconds: 600),
            gap: Duration(milliseconds: 300),
          ),
        ),
      ),
    );
    await tester.pump();

    for (final n in ['1', '2', '3', '4', '5', '6', '7']) {
      expect(find.text(n), findsNothing, reason: 'no "$n" badge allowed');
    }
    expect(litCells(tester), isEmpty);

    await tester.pump(const Duration(milliseconds: 400));
    expect(litCells(tester), [0]);
    await tester.pump(const Duration(milliseconds: 600));
    expect(litCells(tester), isEmpty);
    await tester.pump(const Duration(milliseconds: 300));
    expect(litCells(tester), [8]);
    await tester.pump(const Duration(milliseconds: 600));
    expect(litCells(tester), isEmpty);
    await tester.pump(const Duration(milliseconds: 300));
    expect(litCells(tester), [4]);
    await tester.pump(const Duration(milliseconds: 600));
    expect(litCells(tester), isEmpty);

    await tester.pump(const Duration(milliseconds: 500));
    for (final n in ['1', '2', '3', '4', '5', '6', '7']) {
      expect(find.text(n), findsNothing, reason: 'no "$n" badge allowed');
    }
  });

  testWidgets('replay restarts the sequence from the first cell', (
    WidgetTester tester,
  ) async {
    const sequence = [2, 6];
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: CorsiSequenceStimulus(
            sequence: sequence,
            startDelay: Duration(milliseconds: 200),
            onTime: Duration(milliseconds: 500),
            gap: Duration(milliseconds: 200),
          ),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 200));
    expect(litCells(tester), [2]);
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pump(const Duration(milliseconds: 200));
    expect(litCells(tester), [6]);
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pump(const Duration(milliseconds: 500));
    expect(litCells(tester), isEmpty);

    await tester.tap(find.byKey(const ValueKey('corsi-replay')));
    await tester.pump(const Duration(milliseconds: 200));
    expect(litCells(tester), [2]);
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pump(const Duration(milliseconds: 200));
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pump(const Duration(milliseconds: 500));
    expect(litCells(tester), isEmpty);
  });

  testWidgets('replay works once per probe, then disables (anti-cheat)', (
    WidgetTester tester,
  ) async {
    const sequence = [2, 6];
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: CorsiSequenceStimulus(
            sequence: sequence,
            startDelay: Duration(milliseconds: 200),
            onTime: Duration(milliseconds: 500),
            gap: Duration(milliseconds: 200),
          ),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 200));
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pump(const Duration(milliseconds: 200));
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pump(const Duration(milliseconds: 500));

    final replay = find.byKey(const ValueKey('corsi-replay'));
    expect(
      tester.widget<GestureDetector>(replay).onTap,
      isNotNull,
      reason: 'first replay must be available',
    );

    await tester.tap(replay);
    await tester.pump(const Duration(milliseconds: 200));
    expect(litCells(tester), [2]);
    expect(
      tester.widget<GestureDetector>(replay).onTap,
      isNull,
      reason: 'replay must disable after one use',
    );
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pump(const Duration(milliseconds: 200));
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pump(const Duration(milliseconds: 500));
    expect(litCells(tester), isEmpty);

    await tester.tap(replay, warnIfMissed: false);
    await tester.pump(const Duration(milliseconds: 200));
    await tester.pump(const Duration(milliseconds: 500));
    expect(litCells(tester), isEmpty);
  });

  testWidgets('a new probe resets the single replay allowance', (
    WidgetTester tester,
  ) async {
    Widget frame(List<int> sequence) => MaterialApp(
      home: Scaffold(
        body: CorsiSequenceStimulus(
          sequence: sequence,
          startDelay: Duration.zero,
          onTime: const Duration(milliseconds: 100),
          gap: Duration.zero,
        ),
      ),
    );
    await tester.pumpWidget(frame(const [1, 2]));
    await tester.pump(const Duration(milliseconds: 300));
    final replay = find.byKey(const ValueKey('corsi-replay'));
    await tester.tap(replay);
    await tester.pump(const Duration(milliseconds: 300));
    expect(tester.widget<GestureDetector>(replay).onTap, isNull);

    await tester.pumpWidget(frame(const [3, 4]));
    await tester.pump(const Duration(milliseconds: 300));
    expect(tester.widget<GestureDetector>(replay).onTap, isNotNull);
    await tester.pump(const Duration(milliseconds: 500));
  });
}
