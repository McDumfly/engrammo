import 'package:engrammo/models/fsrs_card.dart';
import 'package:engrammo/models/room_palace.dart';
import 'package:engrammo/services/memory_store.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

RoomPalace _palace(String id) => RoomPalace(
  id: id,
  createdAt: DateTime.utc(2026, 11, 1),
  imageRef: 'data:image/jpeg;base64,AAA',
  stations: const ['desk', 'lamp'],
  items: const ['apple', 'hammer'],
  links: const ['one', 'two'],
  card: FsrsCard(cardId: id, taskId: 'room_palace', due: DateTime.utc(2026)),
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('upsert 8 keeps the newest 6, newest first', () async {
    for (var i = 0; i < 8; i++) {
      await MemoryStore.upsertRoomPalace(_palace('room:$i'));
    }
    final loaded = await MemoryStore.loadRoomPalaces();
    expect(loaded.length, 6);
    expect(loaded.first.id, 'room:7');
    expect(loaded.last.id, 'room:2');
  });

  test('upsert with the same id replaces it', () async {
    await MemoryStore.upsertRoomPalace(_palace('room:a'));
    await MemoryStore.upsertRoomPalace(_palace('room:a').copyWith(live: true));
    final loaded = await MemoryStore.loadRoomPalaces();
    expect(loaded.length, 1);
    expect(loaded.first.live, isTrue);
  });

  test('delete removes the palace', () async {
    await MemoryStore.upsertRoomPalace(_palace('room:a'));
    await MemoryStore.upsertRoomPalace(_palace('room:b'));
    await MemoryStore.deleteRoomPalace('room:a');
    final loaded = await MemoryStore.loadRoomPalaces();
    expect(loaded.map((p) => p.id), ['room:b']);
  });
}
