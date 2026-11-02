// Real-network smoke test for every hosted Meta model the app uses.
// Skipped unless a key is passed:
//   flutter test test/live --dart-define=MODEL_API_KEY=...
// It never prints the key.
import 'dart:io';

import 'package:engrammo/models/meta_image.dart';
import 'package:engrammo/models/meta_task.dart';
import 'package:engrammo/services/meta_ai_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

const _key = String.fromEnvironment('MODEL_API_KEY');

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    // flutter_test blocks real HTTP by default; this suite needs it.
    HttpOverrides.global = null;
    SharedPreferences.setMockInitialValues({});
    MetaAIService.consentForTest = true;
  });

  group(
    'LIVE Meta Model API',
    skip: _key.isEmpty ? 'pass --dart-define=MODEL_API_KEY=...' : false,
    () {
      test('Muse Spark task is live', () async {
        final c = http.Client();
        final t = await MetaAIService.generateTask(
          const MetaTaskRequest(
            kind: 'number',
            difficulty: 2,
            seed: 'smoke',
            locale: 'en',
          ),
          client: c,
          apiKeyOverride: _key,
        );
        c.close();
        expect(t.fallback, isFalse, reason: MetaAIService.lastCalls.first.note);
      }, timeout: const Timeout(Duration(minutes: 2)));

      test('Muse Image generation is live', () async {
        final c = http.Client();
        final img = await MetaAIService.generateImage(
          const MetaImageRequest(
            prompt: 'a cozy desk with a lamp, a mug and a plant',
          ),
          client: c,
          apiKeyOverride: _key,
        );
        c.close();
        expect(
          img.fallback,
          isFalse,
          reason: MetaAIService.lastCalls.first.note,
        );
        expect(img.url, isNotEmpty);
      }, timeout: const Timeout(Duration(minutes: 2)));

      test('Picture recall round is live', () async {
        final c = http.Client();
        final round = await MetaAIService.pictureRecallRound(
          seed: 'smoke',
          count: 3,
          client: c,
          apiKeyOverride: _key,
        );
        c.close();
        expect(round.live, isTrue);
        expect(round.objects.length, greaterThanOrEqualTo(2));
      }, timeout: const Timeout(Duration(minutes: 2)));

      test('Muse Wonder route preview is live', () async {
        final c = http.Client();
        final answer = await MetaAIService.wonderRoutePreview(
          route: 'my room',
          stations: const ['door', 'desk', 'window'],
          client: c,
          apiKeyOverride: _key,
        );
        c.close();
        expect(answer.fallback, isFalse);
      }, timeout: const Timeout(Duration(minutes: 2)));
    },
  );
}
