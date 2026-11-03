import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:engrammo/l10n/app_localizations.dart';
import 'package:engrammo/services/bot_arena_store.dart';
import 'package:engrammo/services/connectivity_service.dart';
import 'package:engrammo/widgets/connectivity_gate.dart';

void main() {
  setUp(connectivityService.resetForTest);
  tearDown(connectivityService.resetForTest);

  group('probeInternet', () {
    test('204 a gstatic-től = van net', () async {
      final client = MockClient((_) async => http.Response('', 204));
      expect(await ConnectivityService.probeInternet(client: client), isTrue);
    });

    test('mindkét gazda elérhetetlen = nincs net', () async {
      final client = MockClient(
        (_) async => throw http.ClientException('no net'),
      );
      expect(await ConnectivityService.probeInternet(client: client), isFalse);
    });

    test('blokkolva a gstatic, de a Meta API elérhető = van net', () async {
      final client = MockClient((request) async {
        if (request.url.host.contains('gstatic')) {
          throw http.ClientException('blocked');
        }
        return http.Response('{}', 404);
      });
      expect(await ConnectivityService.probeInternet(client: client), isTrue);
    });
  });

  group('ConnectivityGate', () {
    testWidgets('online állapotban a gyereket mutatja', (tester) async {
      ConnectivityService.testOverride = true;
      await tester.pumpWidget(
        const MaterialApp(home: ConnectivityGate(child: Text('app here'))),
      );
      expect(find.text('app here'), findsOneWidget);
      expect(find.text('Connect to the internet'), findsNothing);
    });

    testWidgets('gate lets you in without connection', (tester) async {
      ConnectivityService.testOverride = false;
      await tester.pumpWidget(
        const MaterialApp(home: ConnectivityGate(child: Text('app here'))),
      );
      await tester.pumpAndSettle();
      // No blocking gate: the child is visible AND the banner is shown.
      expect(find.text('app here'), findsOneWidget);
      expect(find.text(tr('offline_banner')), findsOneWidget);
    });

    testWidgets('banner slides away when back online', (tester) async {
      ConnectivityService.testOverride = false;
      await tester.pumpWidget(
        const MaterialApp(home: ConnectivityGate(child: Text('app here'))),
      );
      await tester.pumpAndSettle();
      expect(find.text(tr('offline_banner')), findsOneWidget);

      ConnectivityService.testOverride = true;
      connectivityService.check();
      await tester.pumpAndSettle();
      expect(find.text(tr('offline_banner')), findsNothing);
      expect(find.text('app here'), findsOneWidget);
    });

    testWidgets('offline kivétel: bot-párbaj indítható', (tester) async {
      ConnectivityService.testOverride = false;
      botArena.resetForTest();
      SharedPreferences.setMockInitialValues({});
      await tester.pumpWidget(
        const MaterialApp(home: OfflineBattleEntryPage()),
      );
      await tester.pumpAndSettle();
      expect(find.text('Offline practice'), findsOneWidget);
      expect(find.text('Start bot duel'), findsOneWidget);
      botArena.resetForTest();
    });
  });
}
