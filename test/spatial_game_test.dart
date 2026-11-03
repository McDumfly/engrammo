import 'dart:math';

import 'package:engrammo/l10n/app_localizations.dart';
import 'package:engrammo/screens/benchmark.dart';
import 'package:engrammo/services/meta_ai_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    BenchmarkStore.resetForTest();
    MetaAIService.secureStoreForTest = {};
    MetaAIService.consentForTest = null;
  });

  tearDown(() {
    BenchmarkStore.resetForTest();
    MetaAIService.secureStoreForTest = null;
    MetaAIService.consentForTest = null;
  });

  group('SpatialGamePage helpers', () {
    test('pickStations returns the requested distinct stations', () {
      final stations = SpatialGamePage.pickStations(4, routeIndex: 0);
      expect(stations.length, 4);
      expect(stations.toSet().length, 4);
    });

    test('pickStations clamps to 3..10', () {
      expect(SpatialGamePage.pickStations(1, routeIndex: 0).length, 3);
      expect(SpatialGamePage.pickStations(99, routeIndex: 0).length, 10);
    });

    test('pickWords returns distinct nouns', () {
      final words = SpatialGamePage.pickWords(5, Random(42));
      expect(words.length, 5);
      expect(words.toSet().length, 5);
    });

    test('makeOptions holds the answer plus 3 fresh lures', () {
      final options = SpatialGamePage.makeOptions('apple', [
        'apple',
        'hammer',
      ], Random(7));
      expect(options.length, 4);
      expect(options, contains('apple'));
      expect(options.toSet().length, 4);
      expect(options, isNot(contains('hammer')));
    });

    test('localWonderPreview captions every station in order', () {
      final views = SpatialGamePage.localWonderPreview(['door', 'hall']);
      expect(views.length, 2);
      expect(views[0], contains('door'));
      expect(views[1], contains('hall'));
    });

    test('defaultStations returns the 10 sample stops', () {
      final stations = SpatialGamePage.defaultStations('en');
      expect(stations.length, 10);
      expect(stations.first, 'front door');
      final hu = SpatialGamePage.defaultStations('hu');
      expect(hu.length, 10);
      expect(hu.first, 'bejárati ajtó');
    });

    test('sanitizeStations trims, fills blanks and de-duplicates', () {
      final out = SpatialGamePage.sanitizeStations([
        '  my door  ',
        '',
        'my door',
      ]);
      expect(out.length, 10);
      expect(out[0], 'my door');
      expect(out[1], 'hallway mirror');
      expect(out[2], 'my door 2');
    });
  });

  group('SpatialGamePage flow', () {
    /// Station→word rows (`1. hall → lamp`) on the walk memorize screen.
    Map<String, String> readWalkPairs(WidgetTester tester) {
      final out = <String, String>{};
      final pattern = RegExp(r'^\d+\. (.+) → (.+)$');
      for (final t in tester.widgetList<Text>(find.byType(Text))) {
        final m = pattern.firstMatch(t.data ?? '');
        if (m != null) out[m.group(1)!] = m.group(2)!;
      }
      return out;
    }

    /// The 4 big answer buttons on the question screen.
    List<String> readOptions(WidgetTester tester) {
      final out = <String>[];
      for (final t in tester.widgetList<Text>(find.byType(Text))) {
        if (t.style?.fontSize == 20) out.add(t.data ?? '');
      }
      return out;
    }

    Future<void> tapGotIt(WidgetTester tester) async {
      await tester.ensureVisible(find.text('Got it, ask me'));
      await tester.pump();
      await tester.tap(find.text('Got it, ask me'));
      await tester.pump();
    }

    Future<void> tapStart(WidgetTester tester) async {
      await tester.scrollUntilVisible(
        find.text('Start with my palace'),
        500,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pump();
      await tester.tap(find.text('Start with my palace'));
      await tester.pump();
    }

    Future<void> waitForDeal(WidgetTester tester) async {
      final gotIt = find.text('Got it, ask me');
      for (var i = 0; i < 30 && gotIt.evaluate().isEmpty; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
    }

    /// Starts the walk with the sample stations untouched.
    Future<void> startPalaceWalk(
      WidgetTester tester, [
      String palace = 'My flat',
    ]) async {
      await tester.pumpWidget(const MaterialApp(home: SpatialGamePage()));
      await tester.pump();
      await tester.enterText(find.byType(TextField).first, palace);
      await tapStart(tester);
      await waitForDeal(tester);
    }

    /// Tall viewport so the whole setup form (palace + 10 stations +
    /// start) builds at once: the setup list lazily builds and disposes
    /// rows while scrolling, so positional indexes shift under the test.
    void useTallScreen(WidgetTester tester) {
      tester.view.physicalSize = const Size(800, 3000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
    }

    /// Types [value] into the n-th station field (0-based) on setup.
    /// Station fields are found by their hint label, never by position.
    Future<void> enterStation(
      WidgetTester tester,
      int index,
      String value,
    ) async {
      final field = find.byWidgetPredicate(
        (w) =>
            w is TextField && w.decoration?.hintText == 'Station ${index + 1}',
      );
      expect(field, findsOneWidget);
      await tester.enterText(field, value);
      await tester.pump();
    }

    testWidgets('hub lists the spatial memory card', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(const MaterialApp(home: BenchmarkHubPage()));
      await tester.pump();
      // The Room Palace hero sits above the game cards: scroll to the card.
      await tester.scrollUntilVisible(find.text('Spatial memory'), 500);
      await tester.pump();
      expect(find.text('Spatial memory'), findsOneWidget);
      expect(find.text('Walk the palace route!'), findsOneWidget);
    });

    testWidgets('setup asks for the palace and its stations, then walks them', (
      WidgetTester tester,
    ) async {
      useTallScreen(tester);
      await tester.pumpWidget(const MaterialApp(home: SpatialGamePage()));
      await tester.pump();
      expect(find.text('What is your memory palace?'), findsOneWidget);
      expect(find.text('Your route stations, in order'), findsOneWidget);
      // One palace field plus ten station fields, prefilled with the
      // sample route the player edits into their own.
      expect(find.byType(TextField), findsNWidgets(11));
      // Single mode: no mode chips to pick from, and picture masking
      // lives under visual memory.
      expect(find.text('Palace walk'), findsNothing);
      expect(find.text('My palace · list (practice)'), findsNothing);
      expect(find.text('Picture masking · SAM'), findsNothing);

      await tester.enterText(find.byType(TextField).first, 'My flat');
      await tapStart(tester);
      await waitForDeal(tester);

      // The untouched sample route becomes the first walk.
      final pairs = readWalkPairs(tester);
      expect(pairs.keys.toList(), [
        'front door',
        'hallway mirror',
        'coat rack',
      ]);
      expect(find.text('3 stations'), findsOneWidget);
      expect(find.textContaining('My flat'), findsWidgets);
    });

    testWidgets('saved palace skips the setup screen', (
      WidgetTester tester,
    ) async {
      SharedPreferences.setMockInitialValues({
        SpatialGamePage.palacePrefsKey: 'My flat',
        SpatialGamePage.stationsPrefsKey: [
          'my door',
          'my hall',
          'my kitchen',
          'my couch',
          'my lamp',
          'my shelf',
          'my stove',
          'my table',
          'my bed',
          'my sink',
        ],
      });
      await tester.pumpWidget(const MaterialApp(home: SpatialGamePage()));
      await tester.pump();
      await waitForDeal(tester);
      expect(find.text('What is your memory palace?'), findsNothing);
      final pairs = readWalkPairs(tester);
      expect(pairs.keys.toList(), ['my door', 'my hall', 'my kitchen']);
    });

    testWidgets('walk uses the player-typed stations, not the sample route', (
      WidgetTester tester,
    ) async {
      // The app cannot know the player's home layout: whatever the
      // player types as their route is what the walk runs on.
      useTallScreen(tester);
      await tester.pumpWidget(const MaterialApp(home: SpatialGamePage()));
      await tester.pump();
      await tester.enterText(find.byType(TextField).first, 'My flat');
      await enterStation(tester, 0, 'my door');
      await enterStation(tester, 1, 'my hall');
      await enterStation(tester, 2, 'my kitchen');
      await tapStart(tester);
      await waitForDeal(tester);

      final pairs = readWalkPairs(tester);
      expect(pairs.keys.toList(), ['my door', 'my hall', 'my kitchen']);
    });

    testWidgets('correct answer advances to a longer walk and scores spatial', (
      WidgetTester tester,
    ) async {
      await startPalaceWalk(tester);
      final pairs = readWalkPairs(tester);
      expect(pairs.length, 3);
      expect(find.text('3 stations'), findsOneWidget);

      await tapGotIt(tester);
      // The loci probe names one station…
      final question = tester
          .widgetList<Text>(find.byType(Text))
          .map((t) => t.data ?? '')
          .firstWhere((d) => d.startsWith('What did you place'));
      final station = pairs.keys.firstWhere(question.contains);
      // …and the mapped word is among the options.
      await tester.tap(find.text(pairs[station]!).first);
      await tester.pump();
      await waitForDeal(tester);
      expect(find.text('4 stations'), findsOneWidget);
      expect(BenchmarkStore.best['spatial'], 3);
    });

    testWidgets('wrong answer ends the run with a restart', (
      WidgetTester tester,
    ) async {
      await startPalaceWalk(tester);
      final pairs = readWalkPairs(tester);
      await tapGotIt(tester);

      final options = readOptions(tester);
      final wrong = options.firstWhere((o) => !pairs.values.contains(o));
      await tester.tap(find.text(wrong).first);
      await tester.pump();

      expect(find.text('Restart'), findsOneWidget);
      expect(BenchmarkStore.best['spatial'], 2);

      await tester.tap(find.text('Restart'));
      await tester.pump();
      await waitForDeal(tester);
      expect(find.text('3 stations'), findsOneWidget);
      expect(readWalkPairs(tester).length, 3);
    });

    testWidgets('setup has one mode: stations and start, no chips', (
      WidgetTester tester,
    ) async {
      useTallScreen(tester);
      await tester.pumpWidget(const MaterialApp(home: SpatialGamePage()));
      await tester.pump();
      expect(find.text('Your route stations, in order'), findsOneWidget);
      expect(find.text('Start with my palace'), findsOneWidget);
      expect(find.text('Palace walk'), findsNothing);
      expect(find.text('My palace · list (practice)'), findsNothing);
      expect(find.text('Change palace'), findsNothing);
      // Picture masking moved under visual memory.
      expect(find.text('Picture masking · SAM'), findsNothing);
    });

    testWidgets('visual page offers the SAM mask game', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(const MaterialApp(home: VisualGamePage()));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      await tester.tap(find.text('Picture masking · SAM'));
      await tester.pump();

      final maskBtn = find.text('Mask with SAM');
      for (var i = 0; i < 30 && maskBtn.evaluate().isEmpty; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      expect(maskBtn, findsOneWidget);
      // Offline the quiet local line shows instead of any SAM error.
      expect(
        find.text('Local scene — online SAM + Spark kick in'),
        findsOneWidget,
      );
      // Let any pending delays fire.
      await tester.pump(const Duration(milliseconds: 2500));
    });

    testWidgets('mask round scores visual, never spatial', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(home: SamMaskGamePage(count: 3, seed: 'mask-score')),
      );
      await tester.pump();
      final maskBtn = find.text('Mask with SAM');
      for (var i = 0; i < 30 && maskBtn.evaluate().isEmpty; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      // Offline fallback shows the words to memorize as chips.
      final words = <String>[];
      for (final t in tester.widgetList<Text>(find.byType(Text))) {
        if (t.style?.fontSize == 14 && t.style?.fontWeight == FontWeight.w600) {
          words.add(t.data ?? '');
        }
      }
      expect(words.length, 3);
      // The square picture is tall: scroll like a user would before
      // tapping below-the-fold controls.
      await tester.scrollUntilVisible(
        maskBtn,
        300,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(maskBtn);
      await tester.pump();
      for (final w in words) {
        await tester.scrollUntilVisible(
          find.byType(TextField),
          300,
          scrollable: find.byType(Scrollable).first,
        );
        await tester.enterText(find.byType(TextField), w);
        await tester.pump();
        await tester.scrollUntilVisible(
          find.text('Guess'),
          300,
          scrollable: find.byType(Scrollable).first,
        );
        await tester.tap(find.text('Guess'));
        await tester.pump();
      }
      expect(BenchmarkStore.best['visual'], 3);
      expect(BenchmarkStore.best.containsKey('spatial'), isFalse);
    });

    testWidgets('mask badge shows connecting while loading, then local', (
      WidgetTester tester,
    ) async {
      // Töltés alatt a jelvény nem állíthatja, hogy HELYI MÓD: ilyenkor
      // még nem dőlt el, élő vagy helyi lesz-e a kör. (Az offline
      // tartalék egy pump alatt betölt, ezért rögtön az első képkockán
      // kell a kapcsolódást látni.)
      await tester.pumpWidget(const MaterialApp(home: SamMaskGamePage()));
      expect(find.text('Painting the picture…'), findsOneWidget);
      expect(find.text('0%'), findsOneWidget);
      expect(find.text('Connecting'), findsOneWidget);
      expect(find.text('Local mode'), findsNothing);

      final maskBtn = find.text('Mask with SAM');
      for (var i = 0; i < 30 && maskBtn.evaluate().isEmpty; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      expect(maskBtn, findsOneWidget);
      expect(find.text('Local mode'), findsOneWidget);
      expect(find.text('Connecting'), findsNothing);
    });

    testWidgets('change-palace link fits a narrow Hungarian phone screen', (
      WidgetTester tester,
    ) async {
      // A 360 px széles magyar telefonon a régi módválasztó túlcsordult
      // (RIGHT OVERFLOWED BY 89 PIXELS) — az egyetlen
      // "Palota módosítása" link tördelés nélkül elfér.
      AppLocalizations.useCode(AppLocalizations.hungarianCode);
      addTearDown(() => AppLocalizations.useCode(AppLocalizations.englishCode));
      tester.view.physicalSize = const Size(360, 740);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(const MaterialApp(home: SpatialGamePage()));
      await tester.pump();
      await tester.enterText(find.byType(TextField).first, 'A lakásom');
      await tester.scrollUntilVisible(
        find.text('Kezdés a palotámmal'),
        500,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pump();
      await tester.tap(find.text('Kezdés a palotámmal'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.text('Palota módosítása'), findsOneWidget);
      expect(find.text('Palota-séta'), findsNothing);
    });

    testWidgets('spatial setup uses HugeIcons only, no Material Icons', (
      WidgetTester tester,
    ) async {
      // Az appkódban `Icon(Icons.…)` használata tilos: a saját ikonok
      // a HugeIcons-készletből jönnek. (A Material-ikonbetűtípus ettől
      // még be van csomagolva, mert egyes Material-widgetek belső
      // ikont rajzolnak.)
      await tester.pumpWidget(const MaterialApp(home: SpatialGamePage()));
      await tester.pump();
      expect(find.byType(Icon), findsNothing);
    });

    testWidgets('game over shows the AI verdict with a question button', (
      WidgetTester tester,
    ) async {
      await startPalaceWalk(tester);
      final pairs = readWalkPairs(tester);
      await tapGotIt(tester);
      final options = readOptions(tester);
      final wrong = options.firstWhere((o) => !pairs.values.contains(o));
      await tester.tap(find.text(wrong).first);
      await tester.pump();
      // The verdict arrives over async model calls (or their local
      // fallback chain) and sits below the fold of the result list:
      // wait for it and search the whole tree, like a scrolling user.
      final verdict = find.text('AI verdict', skipOffstage: false);
      for (var i = 0; i < 30; i++) {
        if (verdict.evaluate().isNotEmpty) break;
        await tester.pump(const Duration(milliseconds: 100));
      }
      expect(verdict, findsOneWidget);
      expect(
        find.text('Ask the AI coach', skipOffstage: false),
        findsOneWidget,
      );
    });
  });
}
