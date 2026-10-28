import 'package:engrammo/services/app_feedback.dart';
import 'package:engrammo/services/app_settings.dart';
import 'package:engrammo/widgets/synapse_navbar.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final calls = <String>[];

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    calls.clear();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (call) async {
      if (call.method == 'HapticFeedback.vibrate') {
        calls.add('${call.arguments}');
      }
      return null;
    });
  });

  tearDown(() async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, null);
    await appSettings.setHaptics(true);
  });

  Future<void> pumpNav(WidgetTester tester, ValueChanged<int> onSelect) {
    return tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SynapseNavBar(
            index: 0,
            onSelect: onSelect,
            tabs: _tabs,
          ),
        ),
      ),
    );
  }

  /// Az első ikon közepe: a sávsor középre igazított, ismert szélességű.
  Offset firstIconCenter(WidgetTester tester) {
    final navCenter = tester.getCenter(find.byType(SynapseNavBar));
    final rowW =
        _tabs.length * SynapseNavBar.buttonSize +
        (_tabs.length - 1) * SynapseNavBar.itemGap;
    return Offset(
      navCenter.dx - rowW / 2 + SynapseNavBar.buttonSize / 2,
      navCenter.dy,
    );
  }

  testWidgets('Végighúzáskor ikonváltásnál rezeg, még elengedés előtt', (
    tester,
  ) async {
    await appSettings.setHaptics(true);
    AppFeedback.resetForTest();
    var selected = 0;
    await pumpNav(tester, (i) => selected = i);
    await tester.pumpAndSettle();

    final start = firstIconCenter(tester);
    final gesture = await tester.startGesture(start);
    // Áthúzzuk az ujjat a szomszédos ikon cellájába (cella ~60 px).
    await gesture.moveBy(const Offset(70, 0));
    await tester.pump();

    expect(
      calls,
      isNotEmpty,
      reason: 'ikonváltáskor húzás közben is rezegnie kell',
    );

    await gesture.up();
    await tester.pumpAndSettle();
    expect(selected, 1);
  });

  testWidgets('Egy ikonon belül húzva nem rezeg fölöslegesen', (tester) async {
    await appSettings.setHaptics(true);
    AppFeedback.resetForTest();
    var selected = 0;
    await pumpNav(tester, (i) => selected = i);
    await tester.pumpAndSettle();

    final start = firstIconCenter(tester);
    final gesture = await tester.startGesture(start);
    // Kis mozdulat, maradunk az első ikon celláján belül.
    await gesture.moveBy(const Offset(10, 0));
    await tester.pump();

    expect(calls, isEmpty, reason: 'azonos ikonon belül nincs rezgés');

    await gesture.up();
    await tester.pumpAndSettle();
    expect(selected, 0);
  });
}
