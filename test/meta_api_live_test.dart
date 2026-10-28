import 'dart:convert';

import 'package:engrammo/models/meta_image.dart';
import 'package:engrammo/models/meta_segment.dart';
import 'package:engrammo/models/meta_task.dart';
import 'package:engrammo/services/meta_ai_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('Meta Model API konfig', () {
    test('fix cím, kulcs nélkül nincs konfig', () {
      expect(MetaAIService.defaultBaseUrl, 'https://api.meta.ai/v1');
      expect(MetaAIService.baseUrl, 'https://api.meta.ai/v1');
      expect(MetaAIService.apiKey, isEmpty);
      expect(MetaAIService.configured, isFalse);
    });

    test('valós modellnevek', () {
      expect(MetaAIService.taskModel, 'muse-spark-1.3');
      expect(MetaAIService.imageModel, 'muse-image-1.0');
      expect(MetaAIService.segmentModel, 'sam-3.1');
    });
  });

  group('Spark feladat (élő ág mockkal)', () {
    const req = MetaTaskRequest(kind: 'number', difficulty: 3);

    test('kérés törzse chat-completions formátum', () {
      final body = MetaAIService.taskRequestBody(req);
      expect(body['model'], 'muse-spark-1.3');
      final messages = body['messages'] as List;
      expect(messages.length, 2);
      expect((messages[1] as Map)['content'] as String, contains('number'));
    });

    test('érvényes JSON-ból élő feladat', () {
      // A chunk-span paradigma 4-15 jegyű számot kér: az 1 jegyű "1"
      // nem stimulus, a régi parser mégis megette.
      final task = MetaAIService.parseTaskContent(
        '{"prompt":"P","items":["491625830"],"question":"Q?",'
        '"options":["491625830","491625831","491625380","491625800"],'
        '"correct":2,"explanation":"E"}',
        req,
      );
      expect(task, isNotNull);
      expect(task!.fallback, isFalse);
      expect(task.model, 'muse-spark-1.3');
      expect(task.correct, 2);
      expect(task.paradigm, 'chunk-span');
    });

    test('kódkeret tűrése, de hibás szerkezet elutasítva', () {
      // A keret-tűrés megmarad, de a 2 opciós / tartományon kívüli
      // correct / üres inger többé nem "javítódik" csendben (a vágás
      // másik választ jelölne helyesnek, mint amit az AI gondolt) —
      // az ilyen válasz null, és a hívó a validált tartalékot adja.
      final framed = MetaAIService.parseTaskContent(
        '```json\n{"prompt":"P","items":["491625830"],"question":"Q?",'
        '"options":["491625830","491625831","491625380","491625800"],'
        '"correct":1}\n```',
        req,
      );
      expect(framed, isNotNull);
      expect(framed!.correct, 1);
      expect(
        MetaAIService.parseTaskContent(
          '```json\n{"prompt":"P","items":[],"question":"Q?",'
          '"options":["a","b"],"correct":9}\n```',
          req,
        ),
        isNull,
      );
    });

    test('értelmezhetetlen válasz null', () {
      expect(MetaAIService.parseTaskContent('hello', req), isNull);
      expect(
        MetaAIService.parseTaskContent('{"options":["csak-egy"]}', req),
        isNull,
      );
    });

    test('mock szerverrel élő feladat, naplózva', () async {
      final client = MockClient((_) async {
        return http.Response(
          jsonEncode({
            'choices': [
              {
                'message': {
                  'content': jsonEncode({
                    'prompt': 'Mock',
                    'items': ['491625830'],
                    'question': 'Mi?',
                    'options': [
                      '491625830',
                      '491625831',
                      '491625380',
                      '491625800',
                    ],
                    'correct': 0,
                    'explanation': 'Mock-tipp',
                  }),
                },
              },
            ],
          }),
          200,
        );
      });
      final task = await MetaAIService.generateTask(
        req,
        client: client,
        apiKeyOverride: 'teszt-kulcs',
      );
      expect(task.fallback, isFalse);
      expect(task.prompt, 'Mock');
      expect(MetaAIService.lastCalls.first.fallback, isFalse);
      expect(MetaAIService.lastCalls.first.success, isTrue);
    });

    test('szerverhiba esetén helyi tartalék', () async {
      final client = MockClient((_) async => http.Response('hiba', 500));
      final task = await MetaAIService.generateTask(
        req,
        client: client,
        apiKeyOverride: 'teszt-kulcs',
      );
      expect(task.fallback, isTrue);
      expect(MetaAIService.lastCalls.first.success, isFalse);
    });
  });

  group('Muse Image (élő ág mockkal)', () {
    const req = MetaImageRequest(prompt: 'palota kapu');

    test('kérés törzse images formátum', () {
      final body = MetaAIService.imageRequestBody(req);
      expect(body['model'], 'muse-image-1.0');
      expect(body['size'], '512x512');
      expect((body['prompt'] as String), contains('palota kapu'));
    });

    test('url és base64 kicsomagolás', () {
      expect(
        MetaAIService.parseImageUrl({
          'data': [
            {'url': 'https://img/p.png'},
          ],
        }),
        'https://img/p.png',
      );
      expect(
        MetaAIService.parseImageUrl({
          'data': [
            {'b64_json': 'AAA'},
          ],
        }),
        startsWith('data:image/png;base64,'),
      );
      expect(MetaAIService.parseImageUrl({'data': []}), isEmpty);
    });

    test('mock szerverrel élő kép', () async {
      final client = MockClient((_) async {
        return http.Response(
          jsonEncode({
            'data': [
              {'url': 'https://img/palota.png'},
            ],
          }),
          200,
        );
      });
      final img = await MetaAIService.generateImage(
        req,
        client: client,
        apiKeyOverride: 'teszt-kulcs',
      );
      expect(img.fallback, isFalse);
      expect(img.url, 'https://img/palota.png');
      expect(img.cacheKey, req.cacheKey);
    });
  });

  group('SAM 3.1 (élő ág mockkal)', () {
    const req = MetaSegmentRequest(
      imageRef: 'palace-1',
      points: [
        [0.5, 0.5],
      ],
    );

    test('kérés törzse responses formátum', () {
      final body = MetaAIService.segmentRequestBody(req);
      expect(body['model'], 'sam-3.1');
      expect((body['input'] as String), contains('palace-1'));
    });

    test('válaszblokk JSON kicsomagolás', () {
      final seg = MetaAIService.parseSegmentOutput({
        'output': [
          {
            'content': [
              {'text': 'Maszkok: {"masks":["m1"],"labels":["kapu"]} kész.'},
            ],
          },
        ],
      });
      expect(seg, isNotNull);
      expect(seg!.masks, ['m1']);
      expect(seg.labels, ['kapu']);
      expect(seg.fallback, isFalse);
    });

    test('üres válasz null', () {
      expect(MetaAIService.parseSegmentOutput({'output': []}), isNull);
    });

    test('mock szerverrel élő szegmentálás', () async {
      final client = MockClient((_) async {
        return http.Response(
          jsonEncode({
            'output': [
              {
                'content': [
                  {'text': '{"masks":["m1"],"labels":["kapu"]}'},
                ],
              },
            ],
          }),
          200,
        );
      });
      final seg = await MetaAIService.segment(
        req,
        client: client,
        apiKeyOverride: 'teszt-kulcs',
      );
      expect(seg.fallback, isFalse);
      expect(seg.masks, ['m1']);
    });
  });
}
