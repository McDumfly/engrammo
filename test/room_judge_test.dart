import 'dart:convert';

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

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    MetaAIService.consentForTest = true;
  });

  tearDown(() {
    MetaAIService.consentForTest = null;
  });

  group('judgeRecall', () {
    test('accepts a correct verdict', () async {
      final client = MockClient(
        (_) async => http.Response(
          jsonEncode(_chat(jsonEncode({'verdict': 'correct'}))),
          200,
        ),
      );
      final verdict = await MetaAIService.judgeRecall(
        expected: 'sejtmag',
        answer: 'nucleus',
        client: client,
        apiKeyOverride: 'teszt-kulcs',
      );
      expect(verdict, 'correct');
    });

    test('garbage verdict becomes wrong', () async {
      final client = MockClient(
        (_) async => http.Response(
          jsonEncode(_chat(jsonEncode({'verdict': 'maybe'}))),
          200,
        ),
      );
      final verdict = await MetaAIService.judgeRecall(
        expected: 'sejtmag',
        answer: 'riboszóma',
        client: client,
        apiKeyOverride: 'teszt-kulcs',
      );
      expect(verdict, 'wrong');
    });

    test('HTTP 500 becomes wrong', () async {
      final client = MockClient((_) async => http.Response('hiba', 500));
      final verdict = await MetaAIService.judgeRecall(
        expected: 'sejtmag',
        answer: 'riboszóma',
        client: client,
        apiKeyOverride: 'teszt-kulcs',
      );
      expect(verdict, 'wrong');
    });

    test('no key becomes wrong without HTTP', () async {
      final client = MockClient((_) async {
        throw StateError('must not call');
      });
      final verdict = await MetaAIService.judgeRecall(
        expected: 'sejtmag',
        answer: 'riboszóma',
        client: client,
        apiKeyOverride: '',
      );
      expect(verdict, 'wrong');
    });
  });
}
