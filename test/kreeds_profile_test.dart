import 'package:engrammo/models/avatar_traits.dart';
import 'package:engrammo/screens/kreeds_profile.dart';
import 'package:engrammo/services/dicebear_generator.dart';
import 'package:engrammo/widgets/app_buttons.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('compactNumber', () {
    test('ezer alatt valtozatlanul irja ki', () {
      expect(compactNumber(999), '999');
      expect(compactNumber(12), '12');
    });

    test('ezreseknel E helyett K-t ir', () {
      expect(compactNumber(8450), '8.4K');
      expect(compactNumber(1000), '1.0K');
    });
  });

  testWidgets('gyors kartyak: friss fiok nullarol indul', (tester) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(const MaterialApp(home: KreedsProfilePage()));
    await tester.pumpAndSettle();

    expect(find.text('New learner'), findsOneWidget);
    expect(find.text('@new_learner'), findsOneWidget);
    expect(find.text('8.4K'), findsNothing);
    expect(find.text('8.4E'), findsNothing);

    await tester.scrollUntilVisible(find.text('battle'), 300);
    await tester.pumpAndSettle();

    expect(find.text('training'), findsNothing);
    expect(find.text('battle'), findsOneWidget);
    expect(find.text('1000'), findsOneWidget);

    expect(find.text('—'), findsOneWidget);
    expect(find.text('Awakening Mind I'), findsOneWidget);
    expect(find.text('Infinite Mind'), findsNothing);
    expect(find.text('#7'), findsNothing);
    expect(find.text('Gold'), findsNothing);
  });

  testWidgets('beállításokból visszatérve a név azonnal frissül', (tester) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(const MaterialApp(home: KreedsProfilePage()));
    await tester.pumpAndSettle();
    expect(find.text('New learner'), findsOneWidget);

    await tester.tap(
      find.byWidgetPredicate(
        (w) => w is HugeIcon && w.icon == HugeIcons.strokeRoundedSettings01,
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('SAVE PROFILE'), findsOneWidget);

    Finder fieldByHint(String hint) => find.byWidgetPredicate(
      (w) => w is TextField && w.decoration?.hintText == hint,
    );
    await tester.enterText(fieldByHint('Your name'), 'Teszt Elek');
    await tester.enterText(fieldByHint('username'), 'teszt_elek');
    await tester.tap(find.text('SAVE PROFILE'));
    await tester.pumpAndSettle();
    expect(find.text('Saved ✓'), findsOneWidget);

    await tester.tap(find.byType(EngramBackButton));
    await tester.pumpAndSettle();
    expect(find.text('Teszt Elek'), findsOneWidget);
    expect(find.text('@teszt_elek'), findsOneWidget);
    expect(find.text('New learner'), findsNothing);
  });

  testWidgets(
    'profilba visszalépve az avatar nem tölt újra, a névfrissítés megmarad',
    (tester) async {
      // A mentett avatar-készlet közvetlenül a mock-tárhelybe kerül, így az
      // első profil-belépés a betöltési úton (nem mentésen) keresztül jár.
      final customOpts = {
        ...AvatarTraits.defaults(),
        'eyes': 'happy',
        'mouth': 'smile',
      };
      SharedPreferences.setMockInitialValues({
        // MemoryStore avatar_opts kulcsa ('avatar_opts_v1').
        'avatar_opts_v1': [
          for (final e in customOpts.entries) '${e.key}=${e.value}',
        ],
      });
      final display = DicebearGenerator.withoutBackground(customOpts);
      // A dicebear-generálás isolate-ban fut, ezért a widget-teszt hamis
      // időzítése alól runAsync-kel kell kilépni, különben megakad.
      final warmed = await tester.runAsync(
        () => DicebearGenerator.generateAvatarSvgAsync(display),
      );
      final warmedSvg = warmed ?? '';
      expect(warmedSvg, isNotEmpty);

      // A HugeIcon is SvgPicture-t használ, ezért a betöltő tartalma alapján
      // azonosítjuk a profil-avatart: csak az hordozhatja a mentett SVG-t.
      bool showsWarmedAvatar() {
        return tester
            .widgetList<SvgPicture>(find.byType(SvgPicture))
            .any((p) => p.bytesLoader == SvgStringLoader(warmedSvg));
      }

      await tester.pumpWidget(const MaterialApp(home: KreedsProfilePage()));
      await tester.pumpAndSettle();
      expect(showsWarmedAvatar(), isTrue);

      // Navbar-szimuláció: másik fül, majd vissza a profilra.
      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: Text('masik ful'))),
      );
      await tester.pumpAndSettle();
      expect(find.text('masik ful'), findsOneWidget);

      await tester.pumpWidget(const MaterialApp(home: KreedsProfilePage()));
      // A visszalépés első képkockáján már a mentett avatarnak kell
      // látszania, nem helyőrzőnek vagy az alapértelmezett avatarnak.
      expect(showsWarmedAvatar(), isTrue);

      // Névcsere a beállításokban: azonnal látszik, az avatar nem változik.
      await tester.pumpAndSettle();
      await tester.tap(
        find.byWidgetPredicate(
          (w) => w is HugeIcon && w.icon == HugeIcons.strokeRoundedSettings01,
        ),
      );
      await tester.pumpAndSettle();
      Finder fieldByHint(String hint) => find.byWidgetPredicate(
        (w) => w is TextField && w.decoration?.hintText == hint,
      );
      await tester.enterText(fieldByHint('Your name'), 'Friss Nev');
      await tester.tap(find.text('SAVE PROFILE'));
      await tester.pumpAndSettle();
      await tester.tap(find.byType(EngramBackButton));
      await tester.pumpAndSettle();
      expect(find.text('Friss Nev'), findsOneWidget);
      expect(showsWarmedAvatar(), isTrue);
    },
  );
}
