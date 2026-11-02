import 'dart:convert';

import 'package:engrammo/models/meta_image.dart';
import 'package:engrammo/models/meta_segment.dart';
import 'package:engrammo/services/meta_ai_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Regression tests for the Settings call-log errors (2026-11-01):
// Wonder 404 (wrong model id), SAM "empty/unparseable" (wrong prompt +
// JSON parsing against the special-token grammar), open-weight models
// called over the API, and missing retries on transient network
// failures. (The voice-transcribe leg was removed with the feature on
// 2026-11-01: word practice is tap-only now.)
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    MetaAIService.consentForTest = true;
    MetaAIService.clearImageCaches();
  });

  tearDown(() {
    MetaAIService.consentForTest = null;
    MetaAIService.clearImageCaches();
  });

  group('Meta katalógus-azonosítók', () {
    test('wonder pontos néven szerepel (404 ellen)', () {
      // A `muse-` előtag hiánya HTTP 404 model_not_found választ ad.
      expect(MetaAIService.wonderModel, 'muse-wonder-1.0');
      expect(
        MetaAIService.wonderPreviewRequestBody(
          route: 'r',
          stations: const ['a'],
        )['model'],
        'muse-wonder-1.0',
      );
    });
  });

  group('wonder route preview (élő ág mockkal)', () {
    test('helyes modellel kér, állomásonként egy nézőponttal tér vissza',
        () async {
      String? sentModel;
      final client = MockClient((req) async {
        final sent = jsonDecode(req.body) as Map<String, dynamic>;
        sentModel = sent['model'] as String?;
        return http.Response(
          jsonEncode({
            'choices': [
              {
                'message': {
                  'content': jsonEncode({
                    'viewpoints': ['by the door', 'past the lamp'],
                  }),
                },
              },
            ],
          }),
          200,
        );
      });
      final answer = await MetaAIService.wonderRoutePreview(
        route: 'home',
        stations: const ['door', 'lamp'],
        client: client,
        apiKeyOverride: 'teszt-kulcs',
      );
      expect(sentModel, 'muse-wonder-1.0');
      expect(answer.fallback, isFalse);
      expect(answer.viewpoints, ['by the door', 'past the lamp']);
    });
  });

  group('nyílt súlyú modellek: mindig helyi, hálózat nélkül', () {
    test('glimmer kulccsal sem hív hálózatot', () async {
      var called = false;
      final client = MockClient((_) async {
        called = true;
        return http.Response('nope', 404);
      });
      final answer = await MetaAIService.glimmerTake(
        gameId: 'verbal',
        score: 9,
        best: 12,
        client: client,
        apiKeyOverride: 'teszt-kulcs',
      );
      expect(called, isFalse);
      expect(answer.fallback, isTrue);
      expect(answer.text, isNotEmpty);
      final entry = MetaAIService.lastCalls.first;
      expect(entry.success, isTrue);
      expect(entry.note, contains('no Meta API endpoint'));
    });

    test('spark open kulccsal sem hív hálózatot', () async {
      var called = false;
      final client = MockClient((_) async {
        called = true;
        return http.Response('nope', 404);
      });
      final answer = await MetaAIService.openPracticeTip(
        gameId: 'spatial',
        level: 4,
        client: client,
        apiKeyOverride: 'teszt-kulcs',
      );
      expect(called, isFalse);
      expect(answer.fallback, isTrue);
      expect(answer.text, isNotEmpty);
      final entry = MetaAIService.lastCalls.first;
      expect(entry.success, isTrue);
      expect(entry.note, contains('no Meta API endpoint'));
    });
  });

  group('átmeneti hálózati hibák újrapróbálása', () {
    test('kép ClientException után egyszer újrapróbál', () async {
      var calls = 0;
      final client = MockClient((_) async {
        calls++;
        if (calls == 1) throw http.ClientException('connection abort');
        return http.Response(
          jsonEncode({
            'data': [
              {'url': 'https://img.test/retry.png'},
            ],
          }),
          200,
        );
      });
      final img = await MetaAIService.generateImage(
        const MetaImageRequest(prompt: 'egyedi retry-kép'),
        client: client,
        apiKeyOverride: 'teszt-kulcs',
      );
      expect(calls, 2);
      expect(img.fallback, isFalse);
      expect(img.url, 'https://img.test/retry.png');
    });

    test('SAM ClientException után egyszer újrapróbál', () async {
      var calls = 0;
      final client = MockClient((_) async {
        calls++;
        if (calls == 1) throw http.ClientException('connection abort');
        return http.Response(
          jsonEncode({
            'id': 'resp_teszt',
            'status': 'completed',
            'output': [
              {
                'type': 'message',
                'content': [
                  {
                    'type': 'output_text',
                    'text':
                        '<0f>0<|box;x1=0;y1=0;x2=99;y2=99;w=500;h=500|>'
                        '<|mask;x=0;y=0;data=1,1,~X|>',
                  },
                ],
              },
            ],
          }),
          200,
        );
      });
      final seg = await MetaAIService.segment(
        const MetaSegmentRequest(
          imageRef: 'https://img.test/retry-sam.png',
          concept: 'door',
        ),
        client: client,
        apiKeyOverride: 'teszt-kulcs',
      );
      expect(calls, 2);
      expect(seg.fallback, isFalse);
      expect(seg.boxes.length, 1);
    });
  });

  group('SAM nulla találat: élő válasz, tartalék tartalom', () {
    test('üres sáv success + fallback, hiba nélkül', () async {
      final client = MockClient((_) async {
        return http.Response(
          jsonEncode({
            'id': 'resp_teszt',
            'status': 'completed',
            'model': 'sam-3.1',
            'output': [
              {
                'type': 'message',
                'content': [
                  {'type': 'output_text', 'text': ''},
                ],
              },
            ],
          }),
          200,
        );
      });
      final seg = await MetaAIService.segment(
        const MetaSegmentRequest(imageRef: 'https://img.test/nincs.png'),
        client: client,
        apiKeyOverride: 'teszt-kulcs',
      );
      expect(seg.fallback, isTrue);
      final entry = MetaAIService.lastCalls.first;
      expect(entry.success, isTrue);
      expect(entry.note, contains('no matches'));
    });
  });
}
