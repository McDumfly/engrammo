import 'package:engrammo/l10n/app_localizations.dart';
import 'package:engrammo/screens/memory_profile.dart';
import 'package:engrammo/screens/onboarding.dart';
import 'package:engrammo/services/memory_store.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    MemoryStore.clearMemoryCache();
    AppLocalizations.useCode(AppLocalizations.englishCode);
  });

  Widget frame({required VoidCallback onDone}) => MaterialApp(
    home: Scaffold(body: OnboardingPage(onDone: onDone)),
  );

  testWidgets('átugrás menti a jelzőt és befejez', (tester) async {
    var done = false;
    await tester.pumpWidget(frame(onDone: () => done = true));
    await tester.pumpAndSettle();

    await tester.tap(find.text(tr('onboarding_skip')));
    await tester.pumpAndSettle();

    expect(done, isTrue);
    expect(await MemoryStore.loadOnboardingDone(), isTrue);
  });

  testWidgets('végiglapozva a felmérő indítható', (tester) async {
    await tester.pumpWidget(frame(onDone: () {}));
    await tester.pumpAndSettle();

    // 1 üdvözlő + 10 primer + 1 CTA = 12 lap.
    for (var i = 0; i < 12; i++) {
      await tester.drag(
        find.byType(PageView),
        const Offset(-700, 0),
      );
      await tester.pumpAndSettle();
    }
    expect(find.text(tr('onboarding_find_my_type')), findsOneWidget);

    await tester.tap(find.text(tr('onboarding_find_my_type')));
    await tester.pumpAndSettle();
    expect(find.byType(MemoryAssessmentIntroPage), findsOneWidget);
  });

  testWidgets('az első primer mítoszromboló (fotografikus, eidetikus, HSAM)',
      (tester) async {
    await tester.pumpWidget(frame(onDone: () {}));
    await tester.pumpAndSettle();

    await tester.drag(find.byType(PageView), const Offset(-700, 0));
    await tester.pumpAndSettle();

    expect(find.text(tr('onboarding_myth_title')), findsOneWidget);
    final body = tr('onboarding_myth_body');
    expect(body, contains('photographic memory'));
    expect(body.toLowerCase(), contains('eidetic'));
    expect(body, contains('HSAM'));
  });
}
