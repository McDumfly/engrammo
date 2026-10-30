import 'package:engrammo/models/avatar_traits.dart';
import 'package:engrammo/screens/avatar_selection_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('haj/sapka szetvalasztas', () {
    test('a sapkak es a hajak particionaljak a top listat', () {
      final tops = AvatarTraits.topVariants.toSet();
      final hats = AvatarTraits.hatVariants.toSet();
      final hairs = AvatarTraits.hairVariants.toSet();
      expect(hats.intersection(hairs), isEmpty);
      expect(hats.union(hairs), tops);
      expect(hats, containsAll(['hat', 'turban', 'hijab', 'winterHat1']));
    });

    test('isHat csak a sapkakra igaz', () {
      expect(AvatarTraits.isHat('hat'), isTrue);
      expect(AvatarTraits.isHat('turban'), isTrue);
      expect(AvatarTraits.isHat('shortFlat'), isFalse);
      expect(AvatarTraits.isHat(null), isFalse);
    });
  });

  Future<void> settleStudio(WidgetTester tester) async {
    for (var i = 0; i < 120; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 50)),
      );
      await tester.pump(const Duration(milliseconds: 50));
      if (find.byType(CircularProgressIndicator).evaluate().isEmpty) break;
    }
    await tester.pumpAndSettle();
  }

  Future<void> openHats(WidgetTester tester) async {
    await tester.tap(find.text('Hats'));
    await settleStudio(tester);
  }

  void tallWindow(WidgetTester tester) {
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  }

  testWidgets('Hats szekcio: sapka valaszthato es leveheto', (tester) async {
    tallWindow(tester);
    SharedPreferences.setMockInitialValues({});
    Map<String, String>? saved;
    await tester.pumpWidget(
      MaterialApp(
        home: AvatarSelectionScreen(
          initialOpts: AvatarTraits.defaults(),
          onSaved: (opts) => saved = opts,
        ),
      ),
    );
    await settleStudio(tester);

    expect(find.text('Hats'), findsOneWidget);
    await openHats(tester);

    expect(find.text('Hats color'), findsOneWidget);
    expect(find.text('Pick your hats'), findsOneWidget);
    expect(find.text('Turban'), findsOneWidget);
    expect(find.text('Short flat'), findsNothing);

    await tester.tap(find.text('Turban'));
    await settleStudio(tester);
    await tester.tap(find.text('Save avatar'));
    await tester.pumpAndSettle();
    expect(saved, isNotNull);
    expect(saved!['top'], 'turban');
  });

  testWidgets('Hats szekcio: None visszaadja az elozo hajat', (tester) async {
    tallWindow(tester);
    SharedPreferences.setMockInitialValues({});
    Map<String, String>? saved;
    await tester.pumpWidget(
      MaterialApp(
        home: AvatarSelectionScreen(
          initialOpts: {...AvatarTraits.defaults(), 'top': 'bob'},
          onSaved: (opts) => saved = opts,
        ),
      ),
    );
    await settleStudio(tester);

    await openHats(tester);
    await tester.tap(find.text('Hat'));
    await settleStudio(tester);
    await tester.tap(find.text('None'));
    await settleStudio(tester);
    await tester.tap(find.text('Save avatar'));
    await tester.pumpAndSettle();
    expect(saved, isNotNull);
    expect(saved!['top'], 'bob');
  });
}
