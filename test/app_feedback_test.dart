import 'package:engrammo/services/app_feedback.dart';
import 'package:engrammo/services/app_settings.dart';
import 'package:engrammo/widgets/app_buttons.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

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

  test('Az azonnali ismétlés nem rezeg duplán', () async {
    await appSettings.setHaptics(true);
    AppFeedback.resetForTest();
    await AppFeedback.light();
    await AppFeedback.light();
    expect(calls, hasLength(1));
  });

  test('Kis szünet után újra rezeg', () async {
    await appSettings.setHaptics(true);
    AppFeedback.resetForTest();
    await AppFeedback.light();
    await Future<void>.delayed(const Duration(milliseconds: 150));
    await AppFeedback.light();
    expect(calls, hasLength(2));
  });

  test('Kikapcsolt rezgés mellett semmi nem megy ki', () async {
    await appSettings.setHaptics(false);
    AppFeedback.resetForTest();
    await AppFeedback.light();
    await AppFeedback.medium();
    expect(calls, isEmpty);
  });

  testWidgets('Az EngramButton egyszer rezeg, a kezelő rárezgése elnyelődik', (
    tester,
  ) async {
    await appSettings.setHaptics(true);
    AppFeedback.resetForTest();
    var pressed = false;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: EngramButton(
            label: 'TAP',
            onPressed: () {
              pressed = true;
              AppFeedback.light();
            },
          ),
        ),
      ),
    );
    await tester.tap(find.text('TAP'));
    await tester.pumpAndSettle();
    expect(pressed, isTrue);
    expect(calls, hasLength(1));
  });

  testWidgets('A haptic:false gomb nem rezeg, a kezelőé az egyetlen', (
    tester,
  ) async {
    await appSettings.setHaptics(true);
    AppFeedback.resetForTest();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: EngramButton(
            label: 'TAP',
            haptic: false,
            onPressed: () => AppFeedback.medium(),
          ),
        ),
      ),
    );
    await tester.tap(find.text('TAP'));
    await tester.pumpAndSettle();
    expect(calls, hasLength(1));
  });
}
