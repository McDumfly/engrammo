import 'dart:math' as math;

import 'package:engrammo/theme/app_colors.dart' as palette;
import 'package:engrammo/widgets/app_buttons.dart';
import 'package:engrammo/widgets/recall_inputs.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

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

void main() {
  group('WCAG AA palette contrast (>= 4.5:1)', () {
    const white = Color(0xFFFFFFFF);
    test('muted text on white', () {
      expect(_ratio(palette.muted, white), greaterThanOrEqualTo(4.5));
    });
    test('white text on primary blueDark', () {
      expect(_ratio(white, palette.blueDark), greaterThanOrEqualTo(4.5));
    });
    test('white numbers on tealDark Corsi cells', () {
      expect(_ratio(white, palette.tealDark), greaterThanOrEqualTo(4.5));
    });
    test('white text on coralDark danger', () {
      expect(_ratio(white, palette.coralDark), greaterThanOrEqualTo(4.5));
    });
  });

  group('touch targets (>= 48px)', () {
    testWidgets('mini button is at least 48x48', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: EngramMiniButton(label: 'Watch', onTap: () {}),
          ),
        ),
      );
      final size = tester.getSize(find.byType(EngramMiniButton));
      expect(size.height, greaterThanOrEqualTo(48));
      expect(size.width, greaterThanOrEqualTo(48));
    });

    testWidgets('corsi controls are at least 48 tall', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: CorsiSequenceStimulus(
              sequence: [0],
              startDelay: Duration.zero,
              onTime: Duration(milliseconds: 500),
            ),
          ),
        ),
      );
      await tester.pump();
      for (final key in ['corsi-replay', 'corsi-pause', 'corsi-speed']) {
        final size = tester.getSize(find.byKey(ValueKey(key)));
        expect(size.height, greaterThanOrEqualTo(48), reason: key);
      }
      await tester.pump(const Duration(milliseconds: 1000));
    });
  });

  group('corsi pause and speed', () {
    testWidgets('pause freezes, resume continues playback', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: CorsiSequenceStimulus(
              sequence: [1, 2],
              startDelay: Duration(milliseconds: 200),
              onTime: Duration(milliseconds: 600),
              gap: Duration(milliseconds: 200),
            ),
          ),
        ),
      );
      Color? cellColor(int cell) {
        final container = tester.widget<Container>(
          find.byKey(ValueKey('corsi-stimulus-cell-$cell')),
        );
        final d = container.decoration;
        return d is BoxDecoration ? d.color : null;
      }

      await tester.pump(const Duration(milliseconds: 200));
      expect(cellColor(1), palette.tealDark);

      await tester.tap(find.byKey(const ValueKey('corsi-pause')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 2000));
      expect(cellColor(1), palette.tealDark);
      expect(find.text('RESUME'), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('corsi-pause')));
      await tester.pump(const Duration(milliseconds: 600));
      expect(cellColor(1), isNot(palette.tealDark));
      await tester.pump(const Duration(milliseconds: 200));
      expect(cellColor(2), palette.tealDark);
      await tester.pump(const Duration(milliseconds: 1000));
    });

    testWidgets('speed button cycles 1x -> 2x -> 0.5x', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: CorsiSequenceStimulus(
              sequence: [0],
              startDelay: Duration.zero,
              onTime: Duration(milliseconds: 600),
            ),
          ),
        ),
      );
      await tester.pump();
      expect(find.text('SPEED 1×'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('corsi-speed')));
      await tester.pump();
      expect(find.text('SPEED 2×'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('corsi-speed')));
      await tester.pump();
      expect(find.text('SPEED 0.5×'), findsOneWidget);
      await tester.pump(const Duration(milliseconds: 2000));
    });
  });

  group('screen-reader labels', () {
    testWidgets('buttons and corsi controls expose labels', (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Column(
              children: [
                EngramButton(label: 'CONTINUE', onPressed: () {}),
                const EngramBackButton(),
                const CorsiSequenceStimulus(
                  sequence: [0],
                  startDelay: Duration(milliseconds: 5000),
                  onTime: Duration(milliseconds: 5000),
                ),
              ],
            ),
          ),
        ),
      );
      await tester.pump();
      expect(
        tester.getSemantics(find.byType(EngramButton)).label,
        'CONTINUE',
      );
      expect(
        tester.getSemantics(find.byType(EngramBackButton)).label,
        'Back',
      );
      expect(
        tester
            .getSemantics(find.byKey(const ValueKey('corsi-pause')))
            .label,
        contains('Pause'),
      );
      expect(
        tester
            .getSemantics(find.byKey(const ValueKey('corsi-speed')))
            .label,
        'Playback speed',
      );
      expect(
        tester
            .getSemantics(find.byKey(const ValueKey('corsi-replay')))
            .label,
        'Replay sequence',
      );
      expect(
        tester
            .getSemantics(
              find.byKey(const ValueKey('corsi-stimulus-cell-0')),
            )
            .label,
        contains('Sequence cell 1 of 9'),
      );
      await tester.pump(const Duration(seconds: 30));
      handle.dispose();
    });

    testWidgets('corsi tap cells announce selection state', (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: CorsiTapGrid(onDone: (_) {})),
        ),
      );
      await tester.pump();
      final cell = find.byKey(const ValueKey('corsi-cell-3'));
      expect(tester.getSemantics(cell).label, contains('not selected'));
      await tester.tap(cell);
      await tester.pump();
      expect(tester.getSemantics(cell).label, contains('position 1'));
      handle.dispose();
    });
  });
}
