import 'package:engrammo/screens/learning_path.dart';
import 'package:engrammo/services/app_feedback.dart';
import 'package:engrammo/services/app_settings.dart';
import 'package:engrammo/widgets/synapse_navbar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _tabs = [
  SynapseTab(HugeIcons.strokeRoundedHome01, 'Home'),
  SynapseTab(HugeIcons.strokeRoundedTrophy, 'League'),
  SynapseTab(HugeIcons.strokeRoundedSwords, 'Arena'),
  SynapseTab(HugeIcons.strokeRoundedDumbbell01, 'Practice'),
  SynapseTab(HugeIcons.strokeRoundedUser02, 'Profile'),
];

/// A csúszó háttérkör (blob) vízszintes helyzete.
double blobLeft(WidgetTester tester) {
  final all = tester.widgetList<Positioned>(find.byType(Positioned));
  final blob = all.firstWhere(
    (p) => p.top == -10 && p.left != null,
    orElse: () => throw StateError('blob Positioned nem található'),
  );
  return blob.left!;
}

Offset iconCenter(WidgetTester tester, int i, int count) {
  final navCenter = tester.getCenter(find.byType(SynapseNavBar));
  const cellW = SynapseNavBar.buttonSize + SynapseNavBar.itemGap;
  final rowW =
      count * SynapseNavBar.buttonSize + (count - 1) * SynapseNavBar.itemGap;
  return Offset(
    navCenter.dx - rowW / 2 + i * cellW + SynapseNavBar.buttonSize / 2,
    navCenter.dy,
  );
}

/// Koppintás után a blobnak fokozatosan kell átcsúsznia, nem ugrania.
Future<void> expectSlide(
  WidgetTester tester, {
  required int tapIndex,
  required int tabCount,
}) async {
  final startLeft = blobLeft(tester);

  await tester.tapAt(iconCenter(tester, tapIndex, tabCount));
  await tester.pump();

  // Közvetlenül koppintás után még a régi helyen kell lennie (nincs ugrás).
  expect(blobLeft(tester), moreOrLessEquals(startLeft));

  // Mintavétel repülés közben: szigorúan monoton csúszás a két végpont közt.
  final samples = <double>[];
  for (var k = 0; k < 4; k++) {
    await tester.pump(const Duration(milliseconds: 40));
    samples.add(blobLeft(tester));
  }
  // Korlátos lecsengés pumpAndSettle helyett (a céltab is animálhat).
  for (var k = 0; k < 6; k++) {
    await tester.pump(const Duration(milliseconds: 50));
  }
  final endLeft = blobLeft(tester);

  expect(endLeft, isNot(moreOrLessEquals(startLeft)));
  final lo = startLeft < endLeft ? startLeft : endLeft;
  final hi = startLeft < endLeft ? endLeft : startLeft;
  for (final s in samples) {
    expect(s, greaterThan(lo));
    expect(s, lessThan(hi));
  }
  for (var k = 1; k < samples.length; k++) {
    if (endLeft > startLeft) {
      expect(samples[k], greaterThan(samples[k - 1]));
    } else {
      expect(samples[k], lessThan(samples[k - 1]));
    }
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    AppFeedback.resetForTest();
  });

  tearDown(() async {
    await appSettings.setHaptics(true);
  });

  testWidgets('Koppintásra a háttér fokozatosan csúszik, nem ugrik', (
    tester,
  ) async {
    await appSettings.setHaptics(true);
    var selected = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: StatefulBuilder(
            builder: (context, setState) => SynapseNavBar(
              index: selected,
              onSelect: (i) => setState(() => selected = i),
              tabs: _tabs,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Távolság: 2 cella -> ~220 ms animáció.
    await expectSlide(tester, tapIndex: 2, tabCount: _tabs.length);
  });

  testWidgets('A főoldalon tabváltáskor is csúszik a háttér (0 -> 1)', (
    tester,
  ) async {
    await appSettings.setHaptics(true);
    await tester.pumpWidget(const MaterialApp(home: LearningPathPage()));
    await tester.pumpAndSettle();

    // A 0 -> 1 váltásnál a segítőgomb eltűnik a navbar mellől: a navbarnak
    // ilyenkor is meg kell őriznie az állapotát, és csúsznia kell.
    await expectSlide(tester, tapIndex: 1, tabCount: _tabs.length);
  });
}
