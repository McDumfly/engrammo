import 'dart:async';
import 'dart:convert';

import 'package:engrammo/services/meta_ai_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

String _okBody(String text) => jsonEncode({
      'choices': [
        {
          'finish_reason': 'stop',
          'message': {'content': text, 'role': 'assistant'},
        },
      ],
    });

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    MetaAIService.consentForTest = true;
  });
  tearDown(() => MetaAIService.consentForTest = null);

  group('_postChat átmeneti-hiba retry (429/5xx, Timeout, ClientException)', () {
    test('429 után egyszer újrapróbál, második 200 élő válasz', () async {
      var calls = 0;
      final client = MockClient((_) async {
        calls++;
        if (calls == 1) return http.Response('rate limited', 429);
        return http.Response(_okBody('Elo valasz retry utan'), 200);
      });
      final sw = Stopwatch()..start();
      final answer = await MetaAIService.askCoach(
        'szia',
        client: client,
        apiKeyOverride: 'teszt-kulcs',
      );
      sw.stop();
      expect(calls, 2);
      expect(answer.fallback, isFalse);
      expect(answer.text, contains('retry utan'));
      expect(MetaAIService.lastCalls.first.success, isTrue);
      expect(sw.elapsedMilliseconds, greaterThanOrEqualTo(900));
    });

    test('500 után egyszer újrapróbál, második 200 élő válasz', () async {
      var calls = 0;
      final client = MockClient((_) async {
        calls++;
        if (calls == 1) return http.Response('hiba', 500);
        return http.Response(_okBody('Elo valasz 500 utan'), 200);
      });
      final answer = await MetaAIService.askCoach(
        'szia',
        client: client,
        apiKeyOverride: 'teszt-kulcs',
      );
      expect(calls, 2);
      expect(answer.fallback, isFalse);
      expect(answer.text, contains('500 utan'));
    });

    test('TimeoutException után egyszer újrapróbál', () async {
      var calls = 0;
      final client = MockClient((_) async {
        calls++;
        if (calls == 1) throw TimeoutException('időtúllépés');
        return http.Response(_okBody('Elo valasz timeout utan'), 200);
      });
      final answer = await MetaAIService.askCoach(
        'szia',
        client: client,
        apiKeyOverride: 'teszt-kulcs',
      );
      expect(calls, 2);
      expect(answer.fallback, isFalse);
      expect(answer.text, contains('timeout utan'));
    });

    test('ClientException után egyszer újrapróbál', () async {
      var calls = 0;
      final client = MockClient((_) async {
        calls++;
        if (calls == 1) throw http.ClientException('kapcsolat megszakadt');
        return http.Response(_okBody('Elo valasz client-hiba utan'), 200);
      });
      final answer = await MetaAIService.askCoach(
        'szia',
        client: client,
        apiKeyOverride: 'teszt-kulcs',
      );
      expect(calls, 2);
      expect(answer.fallback, isFalse);
      expect(answer.text, contains('client-hiba utan'));
    });

    test('tartós 500: pontosan 2 hívás után helyi tartalék', () async {
      var calls = 0;
      final client = MockClient((_) async {
        calls++;
        return http.Response('hiba', 500);
      });
      final answer = await MetaAIService.askCoach(
        'szia',
        client: client,
        apiKeyOverride: 'teszt-kulcs',
      );
      expect(calls, 2);
      expect(answer.fallback, isTrue);
      expect(MetaAIService.lastCalls.first.success, isFalse);
    });

    test('tartós Timeout: pontosan 2 hívás után helyi tartalék', () async {
      var calls = 0;
      final client = MockClient((_) async {
        calls++;
        throw TimeoutException('időtúllépés');
      });
      final answer = await MetaAIService.askCoach(
        'szia',
        client: client,
        apiKeyOverride: 'teszt-kulcs',
      );
      expect(calls, 2);
      expect(answer.fallback, isTrue);
      expect(MetaAIService.lastCalls.first.success, isFalse);
    });
  });
}
