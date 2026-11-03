import 'dart:convert';

import 'package:engrammo/l10n/app_localizations.dart';
import 'package:engrammo/models/active_palace.dart';
import 'package:engrammo/models/fsrs_card.dart';
import 'package:engrammo/models/room_palace.dart';
import 'package:engrammo/services/active_palace_store.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

RoomPalace _room(
  String id, {
  List<String> stations = const ['desk', 'lamp', 'sofa'],
  bool sample = false,
}) {
  return RoomPalace(
    id: id,
    createdAt: DateTime.utc(2026, 11, 1, 12),
    imageRef: 'data:image/jpeg;base64,AAA',
    stations: stations,
    items: const ['apple', 'hammer', 'key'],
    links: const ['l1', 'l2', 'l3'],
    live: true,
    card: FsrsCard(cardId: id, taskId: 'room_palace', due: DateTime.utc(2026)),
    sample: sample,
  );
}

String _json(RoomPalace p) => jsonEncode(p.toJson());

Future<void> _seed({
  List<RoomPalace> palaces = const [],
  String? activeId,
}) async {
  SharedPreferences.setMockInitialValues({
    'room_palaces_v1': [for (final p in palaces) _json(p)],
    'active_palace_id_v1': ?activeId,
  });
  ActivePalaceStore.last = null;
  AppLocalizations.useCode(AppLocalizations.englishCode);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('fromRoute names the practice palace with its stations', () {
    final p = ActivePalace.fromRoute(0);
    expect(p.id, 'route:0');
    expect(p.title, 'Cozy flat');
    expect(p.stations, hasLength(10));
    expect(p.imageRef, isEmpty);
    expect(p.own, isFalse);
    expect(p.routeIndex, 0);
  });

  test('fromRoom guards boxes and masks by station count', () {
    final p = ActivePalace.fromRoom(
      _room('room:1', stations: const ['a', 'b', 'c']),
    );
    expect(p.own, isTrue);
    expect(p.title, 'Your room palace');
    // No boxes stored: guard keeps empty lists, never a mismatch.
    expect(p.boxes, isEmpty);
    expect(p.masks, isEmpty);
  });

  test('roomPalaceName uses the same titles', () {
    expect(roomPalaceName(_room('room:1')), 'Your room palace');
    expect(
      roomPalaceName(_room('room:1'), 'en', 2),
      'Your room palace · Nov 1',
    );
    expect(roomPalaceName(_room('room:2', sample: true)), 'Sample room');
    expect(roomPalaceName(_room('room:3', stations: const ['a'])), 'a');
  });

  test('load prefers the saved route id over rooms', () async {
    await _seed(palaces: [_room('room:1')], activeId: 'route:2');
    final p = await ActivePalaceStore.load('en');
    expect(p, isNotNull);
    expect(p!.id, 'route:2');
    expect(p.title, 'City park');
  });

  test('load uses the saved room id while it still exists', () async {
    await _seed(
      palaces: [_room('room:1'), _room('room:2')],
      activeId: 'room:2',
    );
    final p = await ActivePalaceStore.load('en');
    expect(p!.id, 'room:2');
    expect(p.own, isTrue);
  });

  test('load falls back to the newest non-sample room', () async {
    await _seed(
      palaces: [
        _room('room:new', sample: false),
        _room('room:old', sample: true),
      ],
      activeId: 'room:gone',
    );
    final p = await ActivePalaceStore.load('en');
    expect(p!.id, 'room:new');
  });

  test('load returns null with no usable palace', () async {
    await _seed(
      palaces: [
        _room('room:tiny', stations: const ['a', 'b']),
      ],
    );
    expect(await ActivePalaceStore.load('en'), isNull);
    expect(ActivePalaceStore.last, isNull);
  });
}
