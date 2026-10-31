import 'package:engrammo/l10n/app_localizations.dart';
import 'package:engrammo/screens/benchmark_stats.dart';
import 'package:engrammo/widgets/app_buttons.dart';
import 'package:engrammo/widgets/recall_inputs.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('EngramPress3D korlátlan helyen is méretezi magát és nyomódik',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    var tapped = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ListView(
            children: [
              EngramPress3D(
                onTap: () => tapped++,
                shadowColor: Colors.black,
                depth: 4,
                top: Container(
                  height: 40,
                  color: Colors.blue,
                ),
              ),
            ],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final box = tester.getSize(find.byType(EngramPress3D).first);
    expect(box.height, 44);

    AnimatedPadding pad() =>
        tester.widget<AnimatedPadding>(find.byType(AnimatedPadding));
    expect(pad().padding, const EdgeInsets.only(bottom: 4));

    final gesture = await tester.startGesture(
      tester.getCenter(find.byType(EngramPress3D)),
    );
    await tester.pumpAndSettle();
    expect(pad().padding, const EdgeInsets.only(top: 4));
    await gesture.up();
    await tester.pumpAndSettle();
    expect(pad().padding, const EdgeInsets.only(bottom: 4));
    expect(tapped, 1);
  });

  testWidgets('recall ellenőrzőgomb 3D-ben nyomódik és beküld', (tester) async {
    SharedPreferences.setMockInitialValues({});
    var submitted = '';
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ListView(
            children: [
              RecallTextField(
                hint: 'hint',
                onSubmit: (v) => submitted = v,
              ),
            ],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final key = const ValueKey('recall-check');
    expect(find.byKey(key), findsOneWidget);
    expect(tester.widget(find.byKey(key)).runtimeType, EngramPress3D);

    AnimatedPadding pad() => tester.widget<AnimatedPadding>(
          find.descendant(
            of: find.byKey(key),
            matching: find.byType(AnimatedPadding),
          ),
        );
    expect(pad().padding, const EdgeInsets.only(bottom: 4));

    await tester.enterText(find.byKey(const ValueKey('recall-input')), 'abc');
    await tester.pump();
    final gesture = await tester.startGesture(tester.getCenter(find.byKey(key)));
    await tester.pumpAndSettle();
    expect(pad().padding, const EdgeInsets.only(top: 4));
    await gesture.up();
    await tester.pumpAndSettle();
    expect(pad().padding, const EdgeInsets.only(bottom: 4));
    expect(submitted, 'abc');
  });

  testWidgets('benchmark indítógomb 3D-ben nyomódik', (tester) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(
      MaterialApp(
        home: BenchmarkDetailPage(
          gameId: 'number',
          title: 't',
          subtitle: 's',
          tint: Colors.blue,
          bestLabel: 'b',
          higherIsBetter: true,
          best: null,
          attempts: const [],
          buildGame: () => const Scaffold(body: Text('game')),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text(tr('bstat_play')), 300);
    await tester.pumpAndSettle();

    final press = find.byType(EngramPress3D);
    expect(press, findsOneWidget);

    AnimatedPadding pad() =>
        tester.widget<AnimatedPadding>(find.byType(AnimatedPadding));
    expect(pad().padding, const EdgeInsets.only(bottom: 4));
    final gesture = await tester.startGesture(tester.getCenter(press));
    await tester.pumpAndSettle();
    expect(pad().padding, const EdgeInsets.only(top: 4));
    await gesture.up();
    await tester.pumpAndSettle();
    expect(find.text('game'), findsOneWidget);
    Navigator.of(tester.element(find.text('game'))).pop();
    await tester.pumpAndSettle();
    expect(pad().padding, const EdgeInsets.only(bottom: 4));
  });
}
