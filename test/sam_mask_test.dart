import 'dart:convert';
import 'dart:typed_data';

import 'package:engrammo/models/sam_mask.dart';
import 'package:engrammo/services/meta_ai_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('SAM mask tokens', () {
    test('parses a lossless token with dimensions first', () {
      final spec = parseSamMaskToken(
        '<|mask;x=0;y=0;data=2,3,~!!!!.!0^zlTde]:)]`W|>',
      );
      expect(spec, isNotNull);
      expect(spec!.encoding, 'lossless');
      expect(spec.width, 3);
      expect(spec.height, 2);
      expect(spec.payload.startsWith('~'), isTrue);
    });

    test('parses a one_bit token with confidence and shuffled fields', () {
      final spec = parseSamMaskToken(
        '<0f>1<|mask;x=0;y=0;c=0.96;data=5,5,!!!!!(QO(0lu8?|>',
      );
      expect(spec, isNotNull);
      expect(spec!.encoding, 'one_bit');
      expect(spec.width, 5);
      expect(spec.height, 5);
    });

    test('rejects malformed tokens', () {
      expect(parseSamMaskToken(''), isNull);
      expect(parseSamMaskToken('hello'), isNull);
      expect(parseSamMaskToken('<|mask;x=0;y=0|>'), isNull);
      expect(parseSamMaskToken('<|mask;x=0;y=0;data=2,3|>'), isNull);
      expect(parseSamMaskToken('<|mask;x=0;y=0;data=0,3,~x|>'), isNull);
      expect(parseSamMaskToken('<|mask;x=0;y=0;data=2,3,?x|>'), isNull);
      // Absurd dimensions never allocate.
      expect(parseSamMaskToken('<|mask;x=0;y=0;data=99999,9,~x|>'), isNull);
    });
  });

  group('SAM mask decode (conformance vectors)', () {
    test('lossless 3x2 vector', () {
      final raster = decodeSamMaskToken(
        '<|mask;x=0;y=0;data=2,3,~!!!!.!0^zlTde]:)]`W|>',
      );
      expect(raster, isNotNull);
      expect(raster!.join(','), '0,0,1,1,0,1');
    });

    test('one_bit 5x5 vector', () {
      final raster = decodeSamMaskToken(
        '<|mask;x=0;y=0;data=5,5,!!!!!(QO(0lu8?|>',
      );
      expect(raster, isNotNull);
      expect(
        raster!.join(','),
        '1,0,0,1,0,0,0,1,1,0,0,0,0,0,0,1,0,1,1,1,1,0,0,0,1',
      );
    });

    test('captured lossless 11x11 vector', () {
      final raster = decodeSamMaskToken(
        '<|mask;x=0;y=0;data=11,11,~!!!!r!kCq#\$.pF[_cZIw.?wO3R8-&NJofiCI\$_J0'
        'aA.1VC*YyK_\'z*(LEG8!+H9evY.82Z-4.@C[.9C@T86o\$3E=-&8w3W=]xS.|>',
      );
      expect(raster, isNotNull);
      expect(raster!.length, 121);
      expect(
        raster.map((e) => e.toString()).join(),
        '00001100000'
        '00111111100'
        '01111111110'
        '01111111110'
        '11111111111'
        '11111111111'
        '01111111111'
        '01111111111'
        '01111111110'
        '00111111110'
        '00001110000',
      );
    });

    test('invalid payloads decode to null, never throw', () {
      expect(decodeSamMaskToken(''), isNull);
      // Test-suite placeholder, not a real payload.
      expect(
        decodeSamMaskToken('<|mask;x=0;y=0;data=10,10,~AAA|>'),
        isNull,
      );
      expect(
        decodeSamMaskToken('<|mask;x=0;y=0;data=2,3,~!!!!.!0^zlTdeXX|>'),
        isNull,
      );
      // Non-canonical one_bit spelling is rejected.
      expect(
        decodeSamMask(
          const SamMaskSpec(
            encoding: 'one_bit',
            payload: '!!!!!(QO(0lu8!',
            width: 5,
            height: 5,
          ),
        ),
        isNull,
      );
    });
  });

  group('raster helpers', () {
    test('runs skip empty rows and split gaps', () {
      // 4x2: row0 = 1 1 0 1, row1 = 0 0 0 0.
      final runs = samMaskRuns(Uint8List.fromList([1, 1, 0, 1, 0, 0, 0, 0]), 4, 2);
      expect(runs.length, 2);
      expect((runs[0].row, runs[0].start, runs[0].end), (0, 0, 1));
      expect((runs[1].row, runs[1].start, runs[1].end), (0, 3, 3));
    });

    test('centroid sits on the filled mass, box center when empty', () {
      final c = samMaskCentroid(
        Uint8List.fromList([0, 0, 0, 1, 1, 1, 0, 0, 0]),
        3,
        3,
      );
      expect(c.x, closeTo(0.5, 1e-9));
      expect(c.y, closeTo(0.5, 1e-9));
      final empty = samMaskCentroid(Uint8List.fromList([0, 0, 0, 0]), 2, 2);
      expect((empty.x, empty.y), (0.5, 0.5));
    });
  });

  group('refinePictureMasks (mock SAM server)', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
      MetaAIService.consentForTest = true;
      MetaAIService.clearImageCaches();
    });

    tearDown(() {
      MetaAIService.consentForTest = null;
    });

    Map<String, dynamic> samPayload(String lane) => {
      'id': 'resp_teszt',
      'status': 'completed',
      'model': 'sam-3.1',
      'output': [
        {
          'type': 'message',
          'content': [
            {'type': 'output_text', 'text': lane},
          ],
        },
      ],
    };

    test('largest box keeps its own paired mask', () async {
      // Small match first, large match second — the cover must take the
      // large box TOGETHER with the large match's shape token (real
      // conformance payloads, so the UI can decode the carried token).
      const lane =
          '<0f>0<|box;x1=10;y1=20;x2=110;y2=120;w=500;h=500|>'
          '<|mask;x=0;y=0;data=2,3,~!!!!.!0^zlTde]:)]`W|>,'
          '1<|box;x1=0;y1=0;x2=400;y2=400;w=500;h=500|>'
          '<|mask;x=0;y=0;data=5,5,!!!!!(QO(0lu8?|>';
      final client = MockClient(
        (_) async => http.Response(jsonEncode(samPayload(lane)), 200),
      );
      final refined = await MetaAIService.refinePictureMasks(
        imageRef: 'https://img/szoba.png',
        objects: const ['door'],
        client: client,
        apiKeyOverride: 'teszt-kulcs',
      );
      expect(refined.boxes.length, 1);
      expect(refined.masks.length, 1);
      // Inclusive [0,0,400,400] on a 500px image.
      expect(refined.boxes[0][0], closeTo(0.0, 1e-9));
      expect(refined.boxes[0][1], closeTo(0.0, 1e-9));
      expect(refined.boxes[0][2], closeTo(401 / 500, 1e-9));
      expect(refined.boxes[0][3], closeTo(401 / 500, 1e-9));
      // The large match's own token — and it really decodes.
      expect(refined.masks[0], contains('data=5,5,!!!!!(QO(0lu8?'));
      expect(decodeSamMaskToken(refined.masks[0])!.length, 25);
    });

    test('a miss falls back to the positional box without a mask', () async {
      final client = MockClient(
        (_) async => http.Response(jsonEncode(samPayload('')), 200),
      );
      var items = 0;
      final refined = await MetaAIService.refinePictureMasks(
        imageRef: 'https://img/ures.png',
        objects: const ['lamp', 'rug'],
        fallbackBoxes: const [
          [0.1, 0.1, 0.3, 0.3],
          [0.5, 0.5, 0.2, 0.2],
        ],
        client: client,
        apiKeyOverride: 'teszt-kulcs',
        onItem: (_, _) => items++,
      );
      expect(refined.boxes, const [
        [0.1, 0.1, 0.3, 0.3],
        [0.5, 0.5, 0.2, 0.2],
      ]);
      expect(refined.masks, const ['', '']);
      expect(items, 2);
    });

    test('empty without an image or without objects', () async {
      final client = MockClient(
        (_) async => http.Response(jsonEncode(samPayload('')), 200),
      );
      final noImage = await MetaAIService.refinePictureMasks(
        imageRef: 'palace:nem-kep',
        objects: const ['door'],
        client: client,
        apiKeyOverride: 'teszt-kulcs',
      );
      expect(noImage.boxes, isEmpty);
      expect(noImage.masks, isEmpty);
      final noObjects = await MetaAIService.refinePictureMasks(
        imageRef: 'https://img/szoba.png',
        objects: const [],
        client: client,
        apiKeyOverride: 'teszt-kulcs',
      );
      expect(noObjects.boxes, isEmpty);
      expect(noObjects.masks, isEmpty);
    });
  });
}
