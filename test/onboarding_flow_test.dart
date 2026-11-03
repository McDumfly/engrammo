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

  testWidgets('a fejléc közepére koppintás nem léptet ki, a Skip igen', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(402, 874));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    var done = false;
    await tester.pumpWidget(frame(onDone: () => done = true));
    await tester.pumpAndSettle();

    // A fejléc: 12 pt felső margó + 48 pt magas sáv, a pöttyök középen.
    await tester.tapAt(const Offset(201, 36));
    await tester.pumpAndSettle();
    expect(done, isFalse);
    expect(find.byType(OnboardingPage), findsOneWidget);

    await tester.tap(find.text(tr('onboarding_skip')));
    await tester.pumpAndSettle();
    expect(done, isTrue);
    expect(await MemoryStore.loadOnboardingDone(), isTrue);
  });

  testWidgets('végiglapozva a felmérő indítható', (tester) async {
    await tester.pumpWidget(frame(onDone: () {}));
    await tester.pumpAndSettle();

    // Üdvözlő + szoba + edző + CTA = 4 lap.
    for (var i = 0; i < 4; i++) {
      await tester.drag(find.byType(PageView), const Offset(-700, 0));
      await tester.pumpAndSettle();
    }
    expect(find.text(tr('onboarding_find_my_type')), findsOneWidget);

    await tester.tap(find.text(tr('onboarding_find_my_type')));
    await tester.pumpAndSettle();
    expect(find.byType(MemoryAssessmentIntroPage), findsOneWidget);
  });

  testWidgets('húzásra lapoz a PageView', (tester) async {
    await tester.binding.setSurfaceSize(const Size(402, 874));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(frame(onDone: () {}));
    await tester.pumpAndSettle();

    await tester.drag(find.byType(PageView), const Offset(-300, 0));
    await tester.pumpAndSettle();

    expect(find.text(tr('onb_room_title')), findsOneWidget);
  });

  testWidgets('második lap a szoba, mítoszromboló a kutatások lapon', (
    tester,
  ) async {
    await tester.pumpWidget(frame(onDone: () {}));
    await tester.pumpAndSettle();

    await tester.drag(find.byType(PageView), const Offset(-700, 0));
    await tester.pumpAndSettle();
    expect(find.text(tr('onb_room_title')), findsOneWidget);

    // CTA lap: még két lapozás, majd a kutatások lap megnyitása.
    await tester.drag(find.byType(PageView), const Offset(-700, 0));
    await tester.pumpAndSettle();
    await tester.drag(find.byType(PageView), const Offset(-700, 0));
    await tester.pumpAndSettle();
    await tester.tap(find.text(tr('onb_science_link')));
    await tester.pumpAndSettle();

    expect(find.text(tr('onboarding_myth_title')), findsOneWidget);
    final body = tr('onboarding_myth_body');
    expect(body, contains('photographic memory'));
    expect(body.toLowerCase(), contains('eidetic'));
    expect(body, contains('HSAM'));
  });
}
