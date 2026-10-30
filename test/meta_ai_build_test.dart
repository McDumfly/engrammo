import 'package:engrammo/services/memory_store.dart';
import 'package:engrammo/services/meta_ai_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('teacher / diagnose offline', () {
    test('magyarázat kulcs nélkül a rögzített stratégiát adja', () async {
      final answer = await MetaAIService.explainTechnique(
        targetId: 'phone-numbers',
        userMaterial: '06301234567',
        locale: 'en',
      );
      expect(answer.fallback, isTrue);
      expect(answer.text, contains('06301234567'));
      expect(answer.text, contains('groups of 3'));
      expect(MetaAIService.lastCalls.first.kind, 'teacher:phone-numbers');
    });

    test('localized: explanation follows locale hu', () async {
      final answer = await MetaAIService.explainTechnique(
        targetId: 'phone-numbers',
        userMaterial: '06301234567',
        locale: 'hu',
      );
      expect(answer.fallback, isTrue);
      expect(answer.text, contains('06301234567'));
      expect(answer.text, contains('csoportokra'));
      expect(answer.text, isNot(contains('groups of 3')));
    });

    test('diagnózis célonként okot és javítást ad', () async {
      final names = await MetaAIService.diagnoseForgetting(
        targetId: 'names',
        forgotNote: 'Anna from the party',
        locale: 'en',
      );
      expect(names.fallback, isTrue);
      expect(names.text, contains('Anna from the party'));
      final deadlines =
          MetaAIService.localDiagnoseAnswer('deadlines', 'the bill', locale: 'en');
      expect(deadlines, contains('if-then'));
      final poems = MetaAIService.localDiagnoseAnswer(
        'poems-verses',
        'verse 3',
        locale: 'en',
      );
      expect(poems, contains('retrieval'));
      expect(MetaAIService.lastCalls.first.kind, 'diagnose:names');
    });

    test('localized: diagnose follows locale hu', () {
      final deadlines = MetaAIService.localDiagnoseAnswer(
        'deadlines',
        'the bill',
        locale: 'hu',
      );
      expect(deadlines, contains('the bill'));
      expect(deadlines, contains('ha-akkor'));
      expect(deadlines, isNot(contains('if-then')));
      final poems = MetaAIService.localDiagnoseAnswer(
        'poems-verses',
        'verse 3',
        locale: 'hu',
      );
      expect(poems, contains('verse 3'));
      expect(poems, contains('felidézés'));
      expect(poems, isNot(contains('retrieval')));
    });

    test('üres felejtés-leírásra is van kegyes válasz', () async {
      final answer = await MetaAIService.diagnoseForgetting(
        targetId: 'names',
        forgotNote: '   ',
      );
      expect(answer.fallback, isTrue);
      expect(answer.text, isNotEmpty);
    });

    test('a tanító- és diagnózis-prompt őrzi a határokat', () {
      final teacher = MetaAIService.teacherRequestBody(
        targetId: 'faces',
        userMaterial: 'Mr. Baker',
        locale: 'en',
      );
      final system =
          (teacher['messages'] as List)[0]['content'] as String;
      expect(system, contains('Mr. Baker'));
      expect(system, contains('Never give medical advice'));
      final diagnose = MetaAIService.diagnoseRequestBody(
        targetId: 'faces',
        forgotNote: 'a name',
        locale: 'en',
      );
      final dSystem =
          (diagnose['messages'] as List)[0]['content'] as String;
      expect(dSystem, contains('Never diagnose'));
    });

    test('English-only: prompts stay English even with locale hu', () {
      final teacher = MetaAIService.teacherRequestBody(
        targetId: 'faces',
        userMaterial: 'Mr. Baker',
        locale: 'hu',
      );
      final system =
          (teacher['messages'] as List)[0]['content'] as String;
      expect(system, contains('Mr. Baker'));
      expect(system, contains('Never give medical advice'));
      expect(system, isNot(contains('Soha')));
      final diagnose = MetaAIService.diagnoseRequestBody(
        targetId: 'faces',
        forgotNote: 'a name',
        locale: 'hu',
      );
      final dSystem =
          (diagnose['messages'] as List)[0]['content'] as String;
      expect(dSystem, contains('a name'));
      expect(dSystem, isNot(contains('Soha')));
    });
  });

  group('own material storage', () {
    test('célonként ment és tölt, üresen töröl', () async {
      expect(await MemoryStore.loadOwnMaterial('names'), isEmpty);
      await MemoryStore.saveOwnMaterial('names', 'Anna, Baker');
      expect(await MemoryStore.loadOwnMaterial('names'), 'Anna, Baker');
      expect(await MemoryStore.loadOwnMaterial('faces'), isEmpty);
      await MemoryStore.saveOwnMaterial('names', 'Baker only');
      expect(await MemoryStore.loadOwnMaterial('names'), 'Baker only');
      await MemoryStore.saveOwnMaterial('names', '   ');
      expect(await MemoryStore.loadOwnMaterial('names'), isEmpty);
    });
  });
}
