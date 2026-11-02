import 'package:engrammo/models/fsrs_card.dart';
import 'package:engrammo/models/room_palace.dart';
import 'package:flutter_test/flutter_test.dart';

RoomPalace _sample() {
  const id = 'room:123';
  return RoomPalace(
    id: id,
    createdAt: DateTime.utc(2026, 11, 1, 12),
    imageRef: 'data:image/jpeg;base64,AAA',
    stations: const ['desk', 'lamp', 'chair'],
    boxes: const [
      [0.1, 0.1, 0.3, 0.3],
      [0.5, 0.1, 0.7, 0.4],
    ],
    masks: const ['<|mask;desk|>', ''],
    items: const ['apple', 'hammer'],
    links: const ['link one', 'link two'],
    live: true,
    card: FsrsCard(cardId: id, taskId: 'room_palace', due: DateTime.utc(2026)),
  );
}

void main() {
  test('toJson/fromJson round-trip keeps boxes and masks', () {
    final p = _sample();
    final back = RoomPalace.fromJson(p.toJson());
    expect(back, p);
    expect(back.boxes, const [
      [0.1, 0.1, 0.3, 0.3],
      [0.5, 0.1, 0.7, 0.4],
    ]);
    expect(back.masks, ['<|mask;desk|>', '']);
    expect(back.live, isTrue);
  });

  test('fromJson({}) does not throw', () {
    final p = RoomPalace.fromJson({});
    expect(p.stations, isEmpty);
    expect(p.boxes, isEmpty);
    expect(p.items, isEmpty);
    expect(p.links, isEmpty);
    expect(p.card.taskId, 'room_palace');
  });

  test('roomGrade maps recall ratios to FSRS grades', () {
    expect(roomGrade(5, 5), 4);
    expect(roomGrade(4, 5), 3);
    expect(roomGrade(3, 5), 2);
    expect(roomGrade(2, 5), 1);
    expect(roomGrade(0, 0), 1);
  });

  test('roomPalaceName joins the first two stations', () {
    expect(roomPalaceName(_sample()), 'desk · lamp');
    expect(
      roomPalaceName(_sample().copyWith(stations: const ['desk'])),
      'desk',
    );
  });
}
