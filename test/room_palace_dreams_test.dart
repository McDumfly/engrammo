import 'package:engrammo/models/fsrs_card.dart';
import 'package:engrammo/models/room_palace.dart';
import 'package:engrammo/screens/benchmark.dart' show MaskedPicture;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

RoomPalace _sample({List<String> dreams = const []}) {
  const id = 'room:dreams';
  return RoomPalace(
    id: id,
    createdAt: DateTime.utc(2026, 11, 1, 12),
    imageRef: 'data:image/jpeg;base64,AAA',
    stations: const ['desk', 'lamp'],
    items: const ['apple', 'hammer'],
    links: const ['link one', 'link two'],
    live: true,
    card: FsrsCard(cardId: id, taskId: 'room_palace', due: DateTime.utc(2026)),
    dreams: dreams,
  );
}

void main() {
  test('RoomPalace.fromJson without dreams gives empty dreams', () {
    final back = RoomPalace.fromJson(_sample().toJson()..remove('dreams'));
    expect(back.dreams, isEmpty);
  });

  test('toJson/fromJson round-trip keeps dreams', () {
    const dreams = ['data:image/jpeg;base64,AAA', ''];
    final back = RoomPalace.fromJson(_sample(dreams: dreams).toJson());
    expect(back.dreams, dreams);
    expect(back, _sample(dreams: dreams));
  });

  testWidgets('MaskedPicture highlight with 2 boxes pumps clean', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: MaskedPicture(
            imageUrl: '',
            scene: '',
            objects: const ['desk', 'lamp'],
            boxes: const [
              [0.1, 0.1, 0.3, 0.3],
              [0.5, 0.1, 0.7, 0.4],
            ],
            masks: const [],
            revealed: const {},
            masked: false,
            highlight: true,
          ),
        ),
      ),
    );
    await tester.pump(const Duration(seconds: 1));
    expect(tester.takeException(), isNull);
  });
}
