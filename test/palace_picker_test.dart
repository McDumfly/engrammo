import 'dart:convert';

import 'package:engrammo/l10n/app_localizations.dart';
import 'package:engrammo/models/fsrs_card.dart';
import 'package:engrammo/models/room_palace.dart';
import 'package:engrammo/services/active_palace_store.dart';
import 'package:engrammo/widgets/palace_picker_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<void> seedRoom() async {
    final room = RoomPalace(
      id: 'room:1',
      createdAt: DateTime.utc(2026, 11, 1, 12),
      imageRef: 'data:image/jpeg;base64,AAA',
      stations: const ['desk', 'lamp', 'sofa'],
      items: const ['apple', 'hammer', 'key'],
      links: const ['l1', 'l2', 'l3'],
      live: true,
      card: FsrsCard(
        cardId: 'room:1',
        taskId: 'room_palace',
        due: DateTime.utc(2026),
      ),
    );
    SharedPreferences.setMockInitialValues({
      'room_palaces_v1': [jsonEncode(room.toJson())],
    });
    ActivePalaceStore.last = null;
    AppLocalizations.useCode(AppLocalizations.englishCode);
  }

  testWidgets('picker lists the room and three practice palaces', (
    tester,
  ) async {
    await seedRoom();
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: SizedBox())),
    );
    showPalacePicker(tester.element(find.byType(Scaffold)));
    await tester.pumpAndSettle();
    expect(find.text('Your rooms'), findsOneWidget);
    expect(find.text('3 stations'), findsOneWidget);
    expect(find.textContaining('Practice palace:'), findsNWidgets(3));
    expect(find.text('Build your own from a photo'), findsOneWidget);

    await tester.tap(find.text('Practice palace: Cozy flat'));
    await tester.pumpAndSettle();
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('active_palace_id_v1'), 'route:0');
  });
}
