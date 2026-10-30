import 'package:engrammo/screens/settings_screen.dart';
import 'package:engrammo/services/env_loader.dart';
import 'package:engrammo/services/meta_ai_service.dart';
import 'package:engrammo/widgets/ai_help_button.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    EnvLoader.resetForTest();
    MetaAIService.secureStoreForTest = {};
    MetaAIService.consentForTest = null;
  });

  tearDown(() {
    EnvLoader.resetForTest();
    MetaAIService.secureStoreForTest = null;
    MetaAIService.consentForTest = null;
  });

  group('indítókulcs egyszer s mindenkorra eltárolódik', () {
    test('EnvLoader-kulcs consent nélkül is mentődik, másodszorra nem ír',
        () async {
      EnvLoader.loadFromStringForTest('MODEL_API_KEY=LLM_launch-kulcs\n');
      expect(await MetaAIService.storedApiKey(), isEmpty);
      expect(await MetaAIService.persistLaunchKeyIfPresent(), isTrue);
      expect(await MetaAIService.storedApiKey(), 'LLM_launch-kulcs');
      expect(await MetaAIService.hasAnyKey(), isTrue);
      expect(await MetaAIService.persistLaunchKeyIfPresent(), isFalse);
    });

    test('kulcs nélkül nem ír: a törlés sima indításnál megmarad', () async {
      EnvLoader.loadFromStringForTest('# üres\n');
      expect(await MetaAIService.persistLaunchKeyIfPresent(), isFalse);
      expect(await MetaAIService.storedApiKey(), isEmpty);
      expect(await MetaAIService.hasAnyKey(), isFalse);
    });

    test('meglévő mentett kulcsot indítókulcs nélkül nem bánt', () async {
      await MetaAIService.setStoredApiKey('kézi-kulcs');
      EnvLoader.loadFromStringForTest('# üres\n');
      expect(await MetaAIService.persistLaunchKeyIfPresent(), isFalse);
      expect(await MetaAIService.storedApiKey(), 'kézi-kulcs');
    });
  });

  group('offline-napló megmondja a valódi okot', () {
    test('kulcs nélkül kulcshiányt naplóz', () async {
      MetaAIService.consentForTest = true;
      final answer = await MetaAIService.askCoach('szia', topic: 'path');
      expect(answer.fallback, isTrue);
      final note = MetaAIService.lastCalls.first.note;
      expect(note, contains('no AI key'));
      expect(note, contains('Settings'));
      expect(note, isNot(contains('consent')));
    });

    test('kulccsal, de consent nélkül consent-hiányt naplóz', () async {
      final answer = await MetaAIService.askCoach(
        'szia',
        topic: 'path',
        apiKeyOverride: 'k',
      );
      expect(answer.fallback, isTrue);
      final note = MetaAIService.lastCalls.first.note;
      expect(note, contains('consent'));
      expect(note, contains('Allow cloud AI'));
    });
  });

  group('coach offline-banner egyérintéses javítással', () {
    Future<void> openSheet(WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: AiHelpButton(topic: AiHelpTopics.path)),
        ),
      );
      await tester.tap(find.byKey(const ValueKey('ai-help-open')));
      await tester.pumpAndSettle();
    }

    Future<void> sendFirstPrompt(WidgetTester tester) async {
      final prompt = find.text('How do I unlock the next station?');
      await tester.ensureVisible(prompt);
      await tester.pumpAndSettle();
      await tester.tap(prompt);
      await tester.pumpAndSettle();
    }

    testWidgets('kulcs nélkül kulcs-hintet mutat, ALLOW nélkül', (tester) async {
      await openSheet(tester);
      await sendFirstPrompt(tester);
      expect(
        find.byKey(const ValueKey('ai-help-offline-banner')),
        findsOneWidget,
      );
      expect(find.textContaining('no AI key'), findsOneWidget);
      expect(find.byKey(const ValueKey('ai-help-allow')), findsNothing);
    });

    testWidgets('kulccsal, de consent nélkül ALLOW kapcsolja az élő módot',
        (tester) async {
      MetaAIService.secureStoreForTest = {'meta_api_key_v1': 'k'};
      await openSheet(tester);
      await sendFirstPrompt(tester);
      expect(find.byKey(const ValueKey('ai-help-allow')), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('ai-help-allow')));
      await tester.pumpAndSettle();
      expect(await MetaAIService.cloudConsent(), isTrue);
      expect(
        find.byKey(const ValueKey('ai-help-offline-banner')),
        findsNothing,
      );
      expect(find.textContaining('send your question again'), findsOneWidget);
    });
  });

  group('beállítások mentés utáni consent-emlékeztető', () {
    testWidgets('mentett kulcs + kikapcsolt consent esetén továbblépést kér',
        (tester) async {
      SharedPreferences.setMockInitialValues({
        'memory_scores_v1': ['10', '20', '30'],
      });
      await tester.pumpWidget(
        const MaterialApp(home: SettingsScreen()),
      );
      await tester.pumpAndSettle();
      final keyField = find.byWidgetPredicate(
        (w) => w is TextField && w.obscureText,
      );
      await tester.ensureVisible(keyField);
      await tester.pumpAndSettle();
      await tester.enterText(keyField, 'LLM_uj-kulcs');
      await tester.ensureVisible(find.text('SAVE KEY'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('SAVE KEY'));
      await tester.pumpAndSettle();
      expect(await MetaAIService.storedApiKey(), 'LLM_uj-kulcs');
      expect(find.textContaining('to go live'), findsOneWidget);
    });
  });
}
