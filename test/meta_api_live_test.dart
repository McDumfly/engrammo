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
    MetaAIService.consentForTest = true;
  });

  tearDown(() {
    MetaAIService.consentForTest = null;
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
      expect(body['reasoning_effort'], 'minimal');
      expect(body['max_completion_tokens'], 3000);
      expect(body.containsKey('max_tokens'), isFalse);
      final messages = body['messages'] as List;
      expect(messages.length, 2);
      expect((messages[1] as Map)['content'] as String, contains('number'));
    });

    test('érvényes JSON-ból élő feladat', () {
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

    // One <0f> line, two matches — the documented SAM 3.1 wire grammar
    // (https://dev.meta.ai/docs/sam/reading-segmentation).
    const samLane =
        '<0f>0<|box;x1=10;y1=20;x2=110;y2=120;w=500;h=500|>'
        '<|mask;x=0;y=0;data=10,10,~AAA|>,'
        '1<|box;x1=200;y1=20;x2=300;y2=120;w=500;h=500|>'
        '<|mask;x=0;y=0;data=10,10,~BBB|>';

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

    test('kérés törzse responses formátum, rövid fogalommal', () {
      final body = MetaAIService.segmentRequestBody(
        const MetaSegmentRequest(
          imageRef: 'https://img/palota.png',
          concept: 'oak door',
        ),
      );
      expect(body['model'], 'sam-3.1');
      final input = body['input'] as List;
      final item = input.first as Map;
      expect(item['type'], 'message');
      final content = item['content'] as List;
      final text = content.whereType<Map>().firstWhere(
        (e) => e['type'] == 'input_text',
      )['text'];
      // Egy rövid főnévi fogalom — nincs JSON-utasítás, nincs kérdés.
      expect(text, 'oak door');
      expect(
        content.any(
          (e) =>
              e is Map &&
              e['type'] == 'input_image' &&
              (e['image_url'] as String).contains('https://img/palota.png'),
        ),
        isTrue,
      );
    });

    test('kép nélküli névvel a fogalom megy szövegként', () {
      final body = MetaAIService.segmentRequestBody(req);
      expect(body['model'], 'sam-3.1');
      expect(body['input'], 'object');
    });

    test('geometria-nyelvtan dobozokra és maszkokra nyílik', () {
      final seg = MetaAIService.parseSegmentOutput(samPayload(samLane));
      expect(seg, isNotNull);
      expect(seg!.fallback, isFalse);
      expect(seg.labels, isEmpty);
      expect(seg.boxes.length, 2);
      expect(seg.masks.length, 2);
      expect(seg.masks[0], contains('<|mask;'));
      // 500-as képen a [10,20,110,120] inkluzív doboz normalizálva.
      expect(seg.boxes[0][0], closeTo(0.02, 1e-9));
      expect(seg.boxes[0][1], closeTo(0.04, 1e-9));
      expect(seg.boxes[0][2], closeTo(101 / 500, 1e-9));
      expect(seg.boxes[0][3], closeTo(101 / 500, 1e-9));
    });

    test('hibás rekord kimarad, a jó megmarad', () {
      final seg = MetaAIService.parseSegmentOutput(
        samPayload(
          '<0f>0<|box;x1=oops|><|mask;x=0;y=0;data=1,1,~X|>,'
          '1<|box;x1=0;y1=0;x2=99;y2=99;w=500;h=500|>'
          '<|mask;x=0;y=0;data=1,1,~Y|>',
        ),
      );
      expect(seg, isNotNull);
      expect(seg!.boxes.length, 1);
      expect(seg.masks.length, 1);
    });

    test('nulla találat érvényes üres válasz, nem hiba', () {
      final seg = MetaAIService.parseSegmentOutput({
        'id': 'resp_teszt',
        'status': 'completed',
        'output': [
          {
            'type': 'message',
            'content': [
              {'type': 'output_text', 'text': ''},
            ],
          },
        ],
      });
      expect(seg, isNotNull);
      expect(seg!.fallback, isTrue);
      expect(seg.boxes, isEmpty);
    });

    test('értelmezhetetlen válasz null', () {
      // Nincs output-sáv: nem SAM-válasz.
      expect(MetaAIService.parseSegmentOutput({}), isNull);
      expect(
        MetaAIService.parseSegmentOutput({
          'masks': ['m1'],
          'labels': ['kapu'],
        }),
        isNull,
      );
      expect(
        MetaAIService.parseSegmentOutput({'status': 'failed', 'output': []}),
        isNull,
      );
      // Szöveges sáv, de nem geometria-nyelvtan.
      expect(
        MetaAIService.parseSegmentOutput(
          samPayload('{"masks":["m1"],"labels":["kapu"]}'),
        ),
        isNull,
      );
    });

    test('mock szerverrel élő szegmentálás', () async {
      final client = MockClient((_) async {
        return http.Response(jsonEncode(samPayload(samLane)), 200);
      });
      final seg = await MetaAIService.segment(
        const MetaSegmentRequest(
          imageRef: 'https://img/palota.png',
          concept: 'door',
        ),
        client: client,
        apiKeyOverride: 'teszt-kulcs',
      );
      expect(seg.fallback, isFalse);
      expect(seg.boxes.length, 2);
      expect(MetaAIService.lastCalls.first.success, isTrue);
      expect(MetaAIService.lastCalls.first.fallback, isFalse);
    });

    test('nulla találat élő válaszként, tartalék tartalommal', () async {
      final client = MockClient((_) async {
        return http.Response(
          jsonEncode({
            'id': 'resp_teszt',
            'status': 'completed',
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
        const MetaSegmentRequest(imageRef: 'https://img/ures.png'),
        client: client,
        apiKeyOverride: 'teszt-kulcs',
      );
      expect(seg.fallback, isTrue);
      expect(seg.boxes, isEmpty);
      expect(MetaAIService.lastCalls.first.success, isTrue);
    });

    test('kép nélküli névvel nem hív hálózatot', () async {
      var called = false;
      final client = MockClient((_) async {
        called = true;
        return http.Response('{}', 200);
      });
      final seg = await MetaAIService.segment(
        req,
        client: client,
        apiKeyOverride: 'teszt-kulcs',
      );
      expect(called, isFalse);
      expect(seg.fallback, isTrue);
    });

    test('szerverhiba nem dob, hanem üres tartalék', () async {
      final client = MockClient((_) async {
        return http.Response('baj van', 500);
      });
      final seg = await MetaAIService.segment(
        const MetaSegmentRequest(imageRef: 'https://img/szerverhiba.png'),
        client: client,
        apiKeyOverride: 'teszt-kulcs',
      );
      expect(seg.fallback, isTrue);
      expect(seg.labels, isEmpty);
      expect(seg.masks, isEmpty);
    });
  });

  group('Spark képolvasás (élő ág mockkal)', () {
    Map<String, dynamic> spotPayload(String lane) => {
      'id': 'resp_teszt',
      'status': 'completed',
      'output': [
        {
          'type': 'message',
          'content': [
            {'type': 'output_text', 'text': lane},
          ],
        },
      ],
    };

    test('kérés törzse responses + kép', () {
      final body = MetaAIService.spotLabelsRequestBody(
        imageRef: 'https://img/szoba.png',
        count: 4,
      );
      expect(body['model'], MetaAIService.taskModel);
      final input = body['input'] as List;
      final content = ((input.first as Map)['content'] as List);
      expect(
        content.any((e) => e is Map && e['type'] == 'input_image'),
        isTrue,
      );
      final text =
          content.whereType<Map>().firstWhere(
                (e) => e['type'] == 'input_text',
              )['text']
              as String;
      expect(text, contains('0-1000'));
      expect(text, contains('JSON array'));
    });

    test('minimális reasoning: különben kifut a 12 mp-es időből', () {
      final body = MetaAIService.spotLabelsRequestBody(
        imageRef: 'https://img/szoba.png',
        count: 4,
      );
      final reasoning = body['reasoning'];
      expect(reasoning, isA<Map>());
      expect((reasoning as Map)['effort'], 'minimal');
    });

    test('földelt címkék dobozokkal nyílnak', () {
      final found = MetaAIService.parseSpotLabels(
        jsonEncode([
          {
            'object_name': 'oak door',
            'bbox': [
              {'x_min': 0, 'y_min': 0, 'x_max': 500, 'y_max': 1000},
            ],
          },
          {
            'object_name': 'brass lamp',
            'bbox': [
              {'x_min': 500, 'y_min': 0, 'x_max': 1000, 'y_max': 500},
            ],
          },
        ]),
      );
      expect(found.labels, ['oak door', 'brass lamp']);
      expect(found.boxes.length, 2);
      expect(found.boxes[0], [0.0, 0.0, 0.5, 1.0]);
      expect(found.boxes[1], [0.5, 0.0, 0.5, 0.5]);
    });

    test('hiányzó doboznál nevek maradnak, doboz nincs', () {
      final found = MetaAIService.parseSpotLabels(
        jsonEncode([
          {
            'object_name': 'oak door',
            'bbox': [
              {'x_min': 0, 'y_min': 0, 'x_max': 100, 'y_max': 100},
            ],
          },
          {'object_name': 'ghost'},
        ]),
      );
      expect(found.labels, ['oak door', 'ghost']);
      expect(found.boxes, isEmpty);
    });

    test('szélső értékek vágva, hibás sorok dobva', () {
      final found = MetaAIService.parseSpotLabels(
        jsonEncode([
          {
            'object_name': 'edge',
            'bbox': [
              {'x_min': -5, 'y_min': 0, 'x_max': 1001, 'y_max': 100},
            ],
          },
          {'object_name': ''},
          {'object_name': 'edge'},
          'not-a-map',
        ]),
      );
      expect(found.labels, ['edge']);
      expect(found.boxes.length, 1);
      expect(found.boxes[0][0], 0.0);
      expect(found.boxes[0][2], 1.0);
    });

    test('mock szerverrel élő képolvasás', () async {
      final client = MockClient((_) async {
        return http.Response(
          jsonEncode(
            spotPayload(
              jsonEncode([
                {
                  'object_name': 'oak door',
                  'bbox': [
                    {'x_min': 0, 'y_min': 0, 'x_max': 100, 'y_max': 100},
                  ],
                },
              ]),
            ),
          ),
          200,
        );
      });
      final seg = await MetaAIService.spotImageLabels(
        'https://img/szoba.png',
        count: 4,
        client: client,
        apiKeyOverride: 'teszt-kulcs',
      );
      expect(seg.fallback, isFalse);
      expect(seg.labels, ['oak door']);
      expect(seg.boxes.length, 1);
    });
  });

  group('Kép-takarás kör végponttól végpontig (mockkal)', () {
    Map<String, dynamic> responsesPayload(String lane) => {
      'id': 'resp_teszt',
      'status': 'completed',
      'output': [
        {
          'type': 'message',
          'content': [
            {'type': 'output_text', 'text': lane},
          ],
        },
      ],
    };

    Map<String, dynamic> chatPayload(String content) => {
      'choices': [
        {
          'message': {'content': content},
        },
      ],
    };

    test('képfestés + olvasás sikerrel élő kör születik', () async {
      final client = MockClient((req) async {
        final path = req.url.path;
        if (path.contains('images/generations')) {
          return http.Response(
            jsonEncode({
              'data': [
                {'url': 'https://img/szoba.png'},
              ],
            }),
            200,
          );
        }
        if (path.endsWith('/responses')) {
          return http.Response(
            jsonEncode(
              responsesPayload(
                jsonEncode([
                  {
                    'object_name': 'oak door',
                    'bbox': [
                      {'x_min': 0, 'y_min': 0, 'x_max': 500, 'y_max': 1000},
                    ],
                  },
                  {
                    'object_name': 'brass lamp',
                    'bbox': [
                      {'x_min': 500, 'y_min': 0, 'x_max': 1000, 'y_max': 500},
                    ],
                  },
                ]),
              ),
            ),
            200,
          );
        }
        return http.Response(
          jsonEncode(chatPayload('{"objects": ["tölgyfa ajtó", "rézlámpa"]}')),
          200,
        );
      });
      final round = await MetaAIService.pictureRecallRound(
        seed: 'elo-kor-teszt',
        count: 2,
        locale: 'hu',
        client: client,
        apiKeyOverride: 'teszt-kulcs',
      );
      expect(round.live, isTrue);
      expect(round.imageUrl, 'https://img/szoba.png');
      expect(round.objects, ['tölgyfa ajtó', 'rézlámpa']);
    });

    test('olvashatatlan képpel is van kép, de a kör helyi marad', () async {
      final client = MockClient((req) async {
        if (req.url.path.contains('images/generations')) {
          return http.Response(
            jsonEncode({
              'data': [
                {'url': 'https://img/szoba.png'},
              ],
            }),
            200,
          );
        }
        return http.Response('{}', 200);
      });
      final round = await MetaAIService.pictureRecallRound(
        seed: 'olvashatatlan-teszt',
        count: 2,
        locale: 'hu',
        client: client,
        apiKeyOverride: 'teszt-kulcs',
      );
      expect(round.live, isFalse);
      expect(round.imageUrl, 'https://img/szoba.png');
      expect(round.objects.length, 2);
    });
  });
}
