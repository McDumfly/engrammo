import 'package:engrammo/services/env_loader.dart';
import 'package:engrammo/services/meta_ai_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    EnvLoader.resetForTest();
    MetaAIService.secureStoreForTest = {};
  });

  tearDown(() {
    EnvLoader.resetForTest();
    MetaAIService.secureStoreForTest = null;
  });

  test('a .env sima indításnál is kulcsot ad, mentés nélkül', () async {
    EnvLoader.loadFromStringForTest('MODEL_API_KEY=LLM_teszt-kulcs\n');
    expect(EnvLoader.apiKey, 'LLM_teszt-kulcs');
    expect(await MetaAIService.storedApiKey(), isEmpty);
    expect(await MetaAIService.effectiveApiKey(), 'LLM_teszt-kulcs');
    expect(await MetaAIService.hasAnyKey(), isTrue);
  });

  test('megjegyzés és idézőjel nem töri a fájlt', () {
    EnvLoader.loadFromStringForTest('# megjegyzés\nMODEL_API_KEY="LLM_x"\n');
    expect(EnvLoader.apiKey, 'LLM_x');
  });

  test('üres fájlnál marad az offline tartalék', () async {
    EnvLoader.loadFromStringForTest('# üres\n');
    expect(await MetaAIService.effectiveApiKey(), isEmpty);
    expect(await MetaAIService.hasAnyKey(), isFalse);
  });
}
