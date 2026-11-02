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

  group('parseRoomLinks', () {
    test('accepts fenced JSON', () {
      final links = MetaAIService.parseRoomLinks(
        '```json\n${jsonEncode({
          'links': ['first scene', 'second scene'],
        })}\n```',
        2,
      );
      expect(links, ['first scene', 'second scene']);
    });

    test('rejects count mismatch, empty strings and banned tokens', () {
      expect(
        MetaAIService.parseRoomLinks(
          jsonEncode({
            'links': ['only one'],
          }),
          2,
        ),
        isNull,
      );
      expect(
        MetaAIService.parseRoomLinks(
          jsonEncode({
            'links': ['fine scene', '  '],
          }),
          2,
        ),
        isNull,
      );
      expect(
        MetaAIService.parseRoomLinks(
          jsonEncode({
            'links': ['fine scene', 'gives you photographic memory fast'],
          }),
          2,
        ),
        isNull,
      );
    });
  });

  group('roomPalaceLinks', () {
    const stations = ['desk', 'lamp'];
    const items = ['apple', 'hammer'];

    test('live answer is not a fallback', () async {
      final client = MockClient(
        (_) async => http.Response(
          jsonEncode(
            _chat(
              jsonEncode({
                'links': ['scene one', 'scene two'],
              }),
            ),
          ),
          200,
        ),
      );
      final answer = await MetaAIService.roomPalaceLinks(
        stations: stations,
        items: items,
        client: client,
        apiKeyOverride: 'teszt-kulcs',
      );
      expect(answer.fallback, isFalse);
      expect(answer.links, ['scene one', 'scene two']);
    });

    test('HTTP 500 falls back to one template link per item', () async {
      final client = MockClient((_) async => http.Response('hiba', 500));
      final answer = await MetaAIService.roomPalaceLinks(
        stations: stations,
        items: items,
        client: client,
        apiKeyOverride: 'teszt-kulcs',
      );
      expect(answer.fallback, isTrue);
      expect(answer.links.length, items.length);
      expect(answer.links[0], contains('apple'));
      expect(answer.links[1], contains('hammer'));
      expect(answer.links[0], isNot(equals(answer.links[1])));
    });

    test('no key falls back to the local template', () async {
      final answer = await MetaAIService.roomPalaceLinks(
        stations: stations,
        items: items,
        apiKeyOverride: '',
      );
      expect(answer.fallback, isTrue);
      expect(answer.links.length, items.length);
      expect(answer.links.first, contains('apple'));
      expect(answer.links[0], isNot(equals(answer.links[1])));
    });
  });
}
