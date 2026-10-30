import 'package:engrammo/models/avatar_traits.dart';
import 'package:engrammo/screens/avatar_selection_screen.dart';
import 'package:engrammo/services/app_feedback.dart';
import 'package:engrammo/services/app_settings.dart';
import 'package:engrammo/widgets/app_buttons.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<void> settleStudio(WidgetTester tester) async {
  for (var i = 0; i < 120; i++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 50)),
    );
    await tester.pump(const Duration(milliseconds: 50));
    if (find.byType(CircularProgressIndicator).evaluate().isEmpty) break;
  }
  await tester.pumpAndSettle();
}

void tallWindow(WidgetTester tester) {
  tester.view.physicalSize = const Size(800, 1600);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

bool _isRailFace(BoxDecoration? d) =>
    d != null && d.borderRadius == BorderRadius.circular(18);

void main() {
  testWidgets(
    'EngramPress3D: lenyomasra lesullyed es rezeg, felengedesre visszaugrik',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      await appSettings.setHaptics(true);
      AppFeedback.resetForTest();
      final calls = <String>[];
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, (call) async {
            if (call.method == 'HapticFeedback.vibrate') {
              calls.add('${call.arguments}');
            }
            return null;
          });
      addTearDown(() async {
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(SystemChannels.platform, null);
        await appSettings.setHaptics(true);
      });

      var tapped = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: 120,
                height: 64,
                child: EngramPress3D(
                  onTap: () => tapped++,
                  shadowColor: Colors.black,
                  top: Container(color: Colors.blue),
                ),
              ),
            ),
          ),
        ),
      );

      AnimatedPositioned pos() =>
          tester.widget<AnimatedPositioned>(find.byType(AnimatedPositioned));
      expect(pos().top, 0);
      expect(pos().bottom, 4);

      final gesture = await tester.startGesture(
        tester.getCenter(find.byType(EngramPress3D)),
      );
      await tester.pumpAndSettle();
      expect(pos().top, 4);
      expect(pos().bottom, 0);
      expect(calls, isNotEmpty, reason: 'lenyomasra haptikus rezzes jon');
      expect(tapped, 0);

      await gesture.up();
      await tester.pumpAndSettle();
      expect(pos().top, 0);
      expect(pos().bottom, 4);
      expect(tapped, 1);
    },
  );

  testWidgets('Kijelolt szekciogomb: arnyek es hatter szine elter', (
    tester,
  ) async {
    tallWindow(tester);
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(
      MaterialApp(
        home: AvatarSelectionScreen(initialOpts: AvatarTraits.defaults()),
      ),
    );
    await settleStudio(tester);

    await tester.tap(find.text('Eyes'));
    await settleStudio(tester);

    final eyesText = find.text('Eyes');
    expect(eyesText, findsOneWidget);

    Element? topEl;
    for (final el
        in find
            .ancestor(of: eyesText, matching: find.byType(Container))
            .evaluate()) {
      final c = el.widget as Container;
      if (_isRailFace(c.decoration as BoxDecoration?) &&
          (topEl == null || el.depth > topEl.depth)) {
        topEl = el;
      }
    }
    expect(topEl, isNotNull, reason: 'a gomb felso lapja megtalalhato');
    final topColor =
        ((topEl!.widget as Container).decoration as BoxDecoration).color;
    expect(topColor, isNotNull);

    Element? tileStack;
    for (final el
        in find
            .ancestor(of: eyesText, matching: find.byType(Stack))
            .evaluate()) {
      if (tileStack == null || el.depth > tileStack.depth) tileStack = el;
    }
    expect(tileStack, isNotNull);

    Container? shadow;
    for (final el
        in find
            .descendant(
              of: find.byWidget(tileStack!.widget),
              matching: find.byType(Container),
            )
            .evaluate()) {
      if (el == topEl) continue;
      final c = el.widget as Container;
      if (_isRailFace(c.decoration as BoxDecoration?)) {
        shadow = c;
        break;
      }
    }
    expect(shadow, isNotNull, reason: 'az arnyeklap megtalalhato');
    final shadowColor = (shadow!.decoration as BoxDecoration).color;
    expect(
      shadowColor,
      isNot(equals(topColor)),
      reason: 'kijelolt allapotban az arnyek nem lehet azonos a hatterrel',
    );
  });
}
