import 'dart:typed_data';

import 'package:engrammo/models/fsrs_card.dart';
import 'package:engrammo/models/room_palace.dart';
import 'package:engrammo/screens/room_palace_page.dart';
import 'package:engrammo/services/memory_store.dart';
import 'package:engrammo/services/meta_ai_service.dart';
import 'package:engrammo/services/room_photo.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    MetaAIService.secureStoreForTest = {};
    MetaAIService.consentForTest = null;
  });

  tearDown(() {
    MetaAIService.secureStoreForTest = null;
    MetaAIService.consentForTest = null;
  });

  testWidgets('review recall accepts the placed item', (tester) async {
    final photo = squareJpegDataUrl(
      Uint8List.fromList(img.encodePng(img.Image(width: 10, height: 10))),
    );
    await MemoryStore.upsertRoomPalace(
      RoomPalace(
        id: 'room:test',
        createdAt: DateTime.utc(2026, 11, 1),
        imageRef: photo,
        stations: const ['desk', 'lamp', 'chair'],
        items: const ['apple', 'hammer'],
        links: const ['first link', 'second link'],
        card: FsrsCard(
          cardId: 'room:test',
          taskId: 'room_palace',
          due: DateTime.now(),
        ),
      ),
    );

    await tester.pumpWidget(
      const MaterialApp(home: RoomPalacePage(reviewId: 'room:test')),
    );
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'apple');
    await tester.ensureVisible(find.text('Check'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Check'));
    await tester.pump();

    expect(find.text('Yes — apple!'), findsOneWidget);
  });
}
