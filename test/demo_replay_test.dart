import 'dart:convert';

import 'package:engrammo/models/room_palace.dart' show walkOrder;
import 'package:engrammo/services/demo_replay.dart';
import 'package:flutter_test/flutter_test.dart';

/// Honest replay tests: the fixture JSON is written inside the test
/// itself, never a fake asset. The real asset files do not exist yet,
/// so [DemoReplay.load] must return null and the app behaves as today.
Map<String, dynamic> _fixture() {
  return {
    'v': 1,
    'recordedAt': '2026-11-02T10:00:00.000Z',
    'locale': 'en',
    'scan': {
      'events': [
        [200, 'labels', 3, 3],
        [1500, 'sam', 1, 3],
        [2500, 'sam', 2, 3],
        [3500, 'sam', 3, 3],
      ],
      'labels': ['desk', 'lamp', 'sofa'],
      'boxes': [
        [0.1, 0.1, 0.2, 0.2],
        [0.4, 0.1, 0.2, 0.2],
        [0.7, 0.1, 0.2, 0.2],
      ],
      'masks': ['m-desk', 'm-lamp', 'm-sofa'],
      'totalMs': 41000,
    },
    'items': ['apple', 'key', 'candle'],
    'links': ['link one', 'link two', 'link three'],
    'dreams': [
      'data:image/jpeg;base64,AAA',
      'data:image/jpeg;base64,BBB',
      'data:image/jpeg;base64,CCC',
    ],
    'receipt': [
      {
        'model': 'muse-spark-1.3',
        'kind': 'room:links',
        'success': true,
        'fallback': false,
      },
      {
        'model': 'sam-3.1',
        'kind': 'segment',
        'success': true,
        'fallback': false,
      },
      {
        'model': 'muse-image-1.0',
        'kind': 'image',
        'success': true,
        'fallback': false,
      },
    ],
  };
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('parses the recorded run', () {
    final raw = jsonEncode(_fixture());
    final replay = DemoReplay.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    expect(replay.locale, 'en');
    expect(replay.items, ['apple', 'key', 'candle']);
    expect(replay.links, hasLength(3));
    expect(replay.dreams, hasLength(3));
    expect(replay.receipt, hasLength(3));
    expect(replay.recordedAt.year, 2026);
  });

  test('labels, boxes and masks stay aligned', () {
    final replay = DemoReplay.fromJson(_fixture());
    expect(replay.labels.length, replay.boxes.length);
    expect(replay.labels.length, replay.masks.length);
  });

  test('linksFor rejects a different list', () {
    final replay = DemoReplay.fromJson(_fixture());
    expect(replay.linksFor(['apple', 'key', 'candle']), isNotNull);
    expect(replay.linksFor(['apple', 'key']), isNull);
    expect(replay.linksFor(['apple', 'key', 'other']), isNull);
  });

  test('missing asset loads null, app behaves as today', () async {
    expect(await DemoReplay.load('en'), isNull);
    expect(await DemoReplay.load('hu'), isNull);
  });

  test('replay scan yields outlined stations, not Spot fallback', () async {
    final replay = DemoReplay.fromJson(_fixture());
    final round = await replay.playScan(
      dataUrl: 'data:image/jpeg;base64,PHOTO',
      speed: 1000,
    );
    expect(round.live, isTrue);
    expect(round.imageUrl, 'data:image/jpeg;base64,PHOTO');
    expect(round.objects, ['desk', 'lamp', 'sofa']);
    // Same downstream filtering as the live path: aligned geometry
    // survives, so the flow never falls back to "Spot 1..4".
    final ordered = walkOrder(round.objects, round.boxes, round.masks);
    expect(ordered.stations.length, 3);
    expect(ordered.boxes.length, 3);
    expect(ordered.masks.length, 3);
    expect(ordered.stations, contains('desk'));
  });
}
