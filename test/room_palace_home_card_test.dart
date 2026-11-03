import 'dart:typed_data';

import 'package:engrammo/models/fsrs_card.dart';
import 'package:engrammo/models/room_palace.dart';
import 'package:engrammo/services/memory_store.dart';
import 'package:engrammo/services/room_photo.dart';
import 'package:engrammo/widgets/room_palace_home_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('with no palace the card keeps the invite look', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: RoomPalaceHomeCard())),
    );
    await tester.pump(const Duration(milliseconds: 800));
    expect(find.text('Room Palace'), findsOneWidget);
    expect(find.text('Start'), findsOneWidget);
  });

  testWidgets('with a palace the card shows its cover and review pill', (
    tester,
  ) async {
    final photo = squareJpegDataUrl(
      Uint8List.fromList(img.encodePng(img.Image(width: 10, height: 10))),
    );
    await MemoryStore.upsertRoomPalace(
      RoomPalace(
        id: 'room:mine',
        createdAt: DateTime.utc(2026, 11, 1),
        imageRef: photo,
        stations: const ['desk'],
        items: const ['apple'],
        links: const ['first link'],
        card: FsrsCard(
          cardId: 'room:mine',
          taskId: 'room_palace',
          due: DateTime.now(),
        ),
      ),
    );
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: RoomPalaceHomeCard())),
    );
    await tester.pump(const Duration(milliseconds: 800));
    await tester.pump(const Duration(milliseconds: 800));
    expect(find.text('Your room palace'), findsOneWidget);
    expect(find.text('Review'), findsOneWidget);
    expect(find.textContaining('1 items · review'), findsOneWidget);
    // The invite look is gone.
    expect(find.text('Room Palace'), findsNothing);
    expect(find.text('Start'), findsNothing);
  });
}
