import 'package:engrammo/l10n/app_localizations.dart';
import 'package:engrammo/services/auth_service.dart';
import 'package:engrammo/services/cloud_sync.dart';
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
    MetaAIService.consentForTest = null;
  });

  tearDown(() {
    AppLocalizations.useCode('en');
    EnvLoader.resetForTest();
    MetaAIService.secureStoreForTest = null;
    MetaAIService.consentForTest = null;
  });

  group('offline teacher answer follows locale', () {
    test('English output is byte-identical to the legacy text', () {
      expect(
        MetaAIService.localTeacherAnswer('no-such-target', locale: 'en'),
        'How to remember your material: Test yourself with feedback. '
        'One win today beats ten rereads: recall it once now, then again '
        'tonight.',
      );
    });

    test('Hungarian output uses the localized template', () {
      expect(
        MetaAIService.localTeacherAnswer('no-such-target', locale: 'hu'),
        'Így jegyezd meg (anyag): Teszteld magad visszajelzéssel. '
        'Egy mai siker többet ér tíz újraolvasásnál: idézd fel egyszer most, '
        'aztán este újra.',
      );
    });

    test('Hungarian material line is localized', () {
      final answer = MetaAIService.localTeacherAnswer(
        'no-such-target',
        userMaterial: 'bevasarlolista',
        locale: 'hu',
      );
      expect(answer, contains('Saját anyagod: "bevasarlolista"'));
      expect(answer, isNot(contains('Your material')));
    });
  });

  group('offline diagnose answer follows locale', () {
    test('English names branch is byte-identical to the legacy text', () {
      expect(
        MetaAIService.localDiagnoseAnswer('names', '', locale: 'en'),
        'Forgetting that usually means it was never encoded: attention was '
        'split at the hello. Fix: next time stop your inner rehearsal, '
        'repeat the name back at once, and stick one picture hook onto one '
        'facial feature.',
      );
    });

    test('Hungarian branches are localized', () {
      final names = MetaAIService.localDiagnoseAnswer(
        'names',
        '',
        locale: 'hu',
      );
      expect(names, contains('megoszlott a figyelmed'));
      expect(names, isNot(contains('Forgetting')));
      final fallback = MetaAIService.localDiagnoseAnswer(
        'no-such-target',
        '',
        locale: 'hu',
      );
      expect(fallback, contains('csukd be a forrást'));
    });
  });

  group('offline log note follows locale', () {
    test('Hungarian note without a key', () async {
      AppLocalizations.useCode('hu');
      MetaAIService.consentForTest = true;
      final answer = await MetaAIService.askCoach('szia', topic: 'path');
      expect(answer.fallback, isTrue);
      final note = MetaAIService.lastCalls.first.note;
      expect(note, contains('nincs AI-kulcs'));
      expect(note, contains('Beállítások'));
    });
  });

  group('connection and backend errors are localized', () {
    test('NoConnectionException maps to the localized key', () {
      AppLocalizations.useCode('en');
      expect(
        AuthService.messageFor(const NoConnectionException()),
        'No connection — try again later.',
      );
      AppLocalizations.useCode('hu');
      expect(
        AuthService.messageFor(const NoConnectionException()),
        'Nincs kapcsolat — próbáld újra később.',
      );
    });

    test('AuthBackendUnavailable maps to the localized key', () {
      AppLocalizations.useCode('hu');
      expect(
        AuthService.messageFor(const AuthBackendUnavailable()),
        'Nincs Firebase-háttér: futtasd a `flutterfire configure` parancsot.',
      );
    });

    test('round label is localized', () {
      expect(trFor('en', 'btl_round', {'round': '2'}), 'R2');
      expect(trFor('hu', 'btl_round', {'round': '2'}), '2. kör');
    });
  });
}
