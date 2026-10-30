import 'dart:convert';

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
    MetaAIService.secureStoreForTest = {};
    MetaAIService.consentForTest = true;
  });

  tearDown(() {
    MetaAIService.secureStoreForTest = null;
    MetaAIService.consentForTest = null;
  });

  test('elmentett kulccsal nem kell dart-define, élő ág fut', () async {
    const testKey = 'elmentett-kulcs';
    const authScheme = 'Bearer';
    await MetaAIService.setStoredApiKey(testKey);
    expect(await MetaAIService.storedApiKey(), testKey);
    expect(await MetaAIService.effectiveApiKey(), testKey);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('meta_api_key_v1'), isNull);

    final client = MockClient((request) async {
      expect(request.headers['Authorization'], '$authScheme $testKey');
      return http.Response(
        jsonEncode({
          'choices': [
            {
              'message': {
                'content': jsonEncode({
                  'prompt': 'Mentett',
                  'items': ['491625'],
                  'question': 'Mi?',
                  'options': ['491625', '491626', '491635', '491525'],
                  'correct': 0,
                  'explanation': 'Tipp',
                }),
              },
            },
          ],
        }),
        200,
      );
    });

    final task = await MetaAIService.generateTask(
      const MetaTaskRequest(kind: 'number', difficulty: 2),
      client: client,
    );
    expect(task.fallback, isFalse);
    expect(task.prompt, 'Mentett');
  });

  test('törlés után újra tartalék van', () async {
    await MetaAIService.setStoredApiKey('elmentett-kulcs');
    await MetaAIService.clearStoredApiKey();
    expect(await MetaAIService.storedApiKey(), isEmpty);
    expect(await MetaAIService.effectiveApiKey(), isEmpty);

    final task = await MetaAIService.generateTask(
      const MetaTaskRequest(kind: 'number', difficulty: 2),
    );
    expect(task.fallback, isTrue);
  });

  test('régi sima szöveges kulcs átköltözik és törlődik', () async {
    SharedPreferences.setMockInitialValues({
      'meta_api_key_v1': 'régi-plain-kulcs',
    });
    expect(MetaAIService.secureStoreForTest, isEmpty);

    expect(await MetaAIService.storedApiKey(), 'régi-plain-kulcs');
    expect(
      MetaAIService.secureStoreForTest!['meta_api_key_v1'],
      'régi-plain-kulcs',
    );
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('meta_api_key_v1'), isNull);
  });
}
