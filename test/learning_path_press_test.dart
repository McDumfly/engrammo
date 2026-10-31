import 'package:engrammo/screens/learning_path.dart';
import 'package:engrammo/widgets/app_buttons.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('állomás lenyomásra lesüllyed, felengedésre visszaugrik', (
    WidgetTester tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(const MaterialApp(home: LearningPathPage()));
    await tester.pumpAndSettle();

    final badgeKey = const ValueKey('path-lesson-0-0-0');
    await tester.ensureVisible(find.byKey(badgeKey));
    await tester.pumpAndSettle();

    AnimatedPositioned pos() => tester.widget<AnimatedPositioned>(
      find.descendant(
        of: find.byKey(badgeKey),
        matching: find.byType(AnimatedPositioned),
      ),
    );
    EngramPress3D press() => tester.widget<EngramPress3D>(
      find.descendant(
        of: find.byKey(badgeKey),
        matching: find.byType(EngramPress3D),
      ),
    );

    final depth = press().depth;
    expect(pos().top, 0);
    expect(pos().bottom, depth);

    final gesture = await tester.startGesture(
      tester.getCenter(find.byKey(badgeKey)),
    );
    await tester.pumpAndSettle();
    expect(pos().top, depth);
    expect(pos().bottom, 0);

    await gesture.up();
    await tester.pump();
    expect(pos().top, 0);
    expect(pos().bottom, depth);
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('lesson-coach-next')),
      300,
    );
    expect(find.byKey(const ValueKey('lesson-coach-next')), findsOneWidget);
  });

  testWidgets('gyors koppintásra gyorsabb, lassúra normál az animáció', (
    WidgetTester tester,
  ) async {
    const pressMs = 200;
    const releaseMs = 200;
    const minMs = 50;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 120,
              height: 64,
              child: EngramPress3D(
                onTap: () {},
                shadowColor: Colors.black,
                pressDuration: const Duration(milliseconds: pressMs),
                releaseDuration: const Duration(milliseconds: releaseMs),
                minDuration: const Duration(milliseconds: minMs),
                top: Container(color: Colors.blue),
              ),
            ),
          ),
        ),
      ),
    );

    AnimatedPositioned pos() =>
        tester.widget<AnimatedPositioned>(find.byType(AnimatedPositioned));

    final fast = await tester.startGesture(
      tester.getCenter(find.byType(EngramPress3D)),
    );
    await tester.pump();
    expect(pos().top, 4);
    await fast.up();
    await tester.pump();
    expect(pos().top, 0);
    expect(
      pos().duration,
      const Duration(milliseconds: minMs),
      reason: 'gyors felengedésre a minimum idő fut',
    );
    await tester.pumpAndSettle();

    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 300)),
    );
    final slow = await tester.startGesture(
      tester.getCenter(find.byType(EngramPress3D)),
    );
    await tester.pump();
    expect(pos().duration, const Duration(milliseconds: pressMs));
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 250)),
    );
    await slow.up();
    await tester.pump();
    expect(
      pos().duration,
      const Duration(milliseconds: releaseMs),
      reason: 'hosszú nyomásra a teljes idő fut',
    );
  });
}
