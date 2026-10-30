import 'package:engrammo/models/meta_task.dart';
import 'package:engrammo/services/meta_ai_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    MetaAIService.secureStoreForTest = {};
  });

  tearDown(() {
    MetaAIService.secureStoreForTest = null;
  });

  group('Meta API bázis-URL https-kényszer', () {
    test('alapértelmezett cím https', () {
      expect(MetaAIService.resolveBaseUrl(), 'https://api.meta.ai/v1');
    });

    test('explicit https-cím átmegy', () {
      expect(
        MetaAIService.resolveBaseUrl('https://példa.hu/v1'),
        'https://példa.hu/v1',
      );
    });

    test('http-cím hangosan elutasítva', () {
      expect(
        () => MetaAIService.resolveBaseUrl('http://api.meta.ai/v1'),
        throwsStateError,
      );
    });

    test('nem URL / nem abszolút cím elutasítva', () {
      expect(() => MetaAIService.resolveBaseUrl(''), throwsStateError);
      expect(
        () => MetaAIService.resolveBaseUrl('nem-url'),
        throwsStateError,
      );
      expect(
        () => MetaAIService.resolveBaseUrl('ftp://x.hu/v1'),
        throwsStateError,
      );
    });

    test('élő hívás http-címmel nem indul, hanem dob', () async {
      await expectLater(
        MetaAIService.generateTask(
          const MetaTaskRequest(kind: 'number', difficulty: 2),
          apiKeyOverride: 'teszt-kulcs',
          baseUrlOverride: 'http://api.meta.ai/v1',
        ),
        throwsStateError,
      );
    });
  });
}
