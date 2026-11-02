import 'dart:convert';

import 'package:engrammo/l10n/app_localizations.dart';
import 'package:engrammo/services/meta_ai_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

Map<String, dynamic> _chat(String content) => {
  'choices': [
    {
      'message': {'content': content},
    },
  ],
};

http.Response _concepts(List<String> concepts) =>
    http.Response(jsonEncode(_chat(jsonEncode({'concepts': concepts}))), 200);

http.Response _samLane() => http.Response(
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
                '<0f>0<|box;x1=10;y1=10;x2=110;y2=110;w=500;h=500|>'
                '<|mask;x=0;y=0;data=10,10,~AAA|>',
          },
        ],
      },
    ],
  }),
  200,
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    MetaAIService.consentForTest = true;
    MetaAIService.debugClearConceptCache();
    AppLocalizations.useCode('en');
  });

  tearDown(() {
    MetaAIService.consentForTest = null;
    MetaAIService.debugClearConceptCache();
    AppLocalizations.useCode('en');
  });

  group('englishConcepts', () {
    test('en locale makes no HTTP call', () async {
      final client = MockClient((_) async {
        throw StateError('must not call');
      });
      final out = await MetaAIService.englishConcepts(
        const ['komód', 'ablak'],
        locale: 'en',
        client: client,
        apiKeyOverride: 'teszt-kulcs',
      );
      expect(out, ['komód', 'ablak']);
    });

    test('hu maps once, then serves from cache without HTTP', () async {
      var calls = 0;
      final client = MockClient((req) async {
        calls++;
        return _concepts(['dresser', 'window']);
      });
      final first = await MetaAIService.englishConcepts(
        const ['komód', 'ablak'],
        locale: 'hu',
        client: client,
        apiKeyOverride: 'teszt-kulcs',
      );
      expect(first, ['dresser', 'window']);
      expect(calls, 1);
      final second = await MetaAIService.englishConcepts(
        const ['komód', 'ablak'],
        locale: 'hu',
        client: client,
        apiKeyOverride: 'teszt-kulcs',
      );
      expect(second, ['dresser', 'window']);
      expect(calls, 1);
    });

    test('malformed reply leaves labels unchanged', () async {
      final client = MockClient((_) async {
        return http.Response(jsonEncode(_chat('{"nope": []}')), 200);
      });
      final out = await MetaAIService.englishConcepts(
        const ['komód'],
        locale: 'hu',
        client: client,
        apiKeyOverride: 'teszt-kulcs',
      );
      expect(out, ['komód']);
    });
  });

  group('refinePictureMasks with Hungarian UI', () {
    test('SAM request carries the English concept', () async {
      AppLocalizations.useCode('hu');
      String? samConcept;
      final client = MockClient((req) async {
        if (req.url.path.endsWith('/responses')) {
          final sent = jsonDecode(req.body) as Map<String, dynamic>;
          final input = sent['input'] as List;
          final msg = input.first as Map<String, dynamic>;
          final content = msg['content'] as List;
          samConcept =
              (content.first as Map<String, dynamic>)['text'] as String?;
          return _samLane();
        }
        return _concepts(['dresser']);
      });
      final refined = await MetaAIService.refinePictureMasks(
        imageRef: 'https://img.test/room.png',
        objects: const ['komód'],
        client: client,
        apiKeyOverride: 'teszt-kulcs',
      );
      expect(samConcept, 'dresser');
      expect(refined.boxes.length, 1);
    });
  });
}
