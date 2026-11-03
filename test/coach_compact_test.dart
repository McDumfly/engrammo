import 'package:engrammo/l10n/app_localizations.dart';
import 'package:engrammo/models/foundations.dart';
import 'package:engrammo/models/lesson_content.dart';
import 'package:engrammo/screens/lesson_player.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('isTrackIntroLesson', () {
    test('minden memoriatipus elso allomasa bevezeto', () {
      // track 0..5 elso fejezete: 0,1,2,3,4,5
      for (var c = 0; c <= 5; c++) {
        expect(
          isTrackIntroLesson(c, 0, 0),
          isTrue,
          reason: 'chapter $c elso leckeje bevezeto',
        );
      }
    });

    test('a masodik allomastol mar nem bevezeto', () {
      expect(isTrackIntroLesson(0, 0, 1), isFalse);
      expect(isTrackIntroLesson(0, 1, 0), isFalse);
      expect(isTrackIntroLesson(2, 0, 1), isFalse);
      expect(isTrackIntroLesson(8, 0, 0), isFalse);
      expect(isTrackIntroLesson(-1, 0, 0), isFalse);
    });
  });

  group('coach nezet', () {
    testWidgets('elso allomas: egy rovid kepernyo, reszletek lenyithatok', (
      tester,
    ) async {
      SharedPreferences.setMockInitialValues({});
      AppLocalizations.useCode('en');
      tester.view.physicalSize = const Size(402, 874);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });
      await tester.pumpWidget(
        const MaterialApp(
          home: LessonPlayerPage(
            chapterIndex: 0,
            sectionIndex: 0,
            lessonIndex: 0,
          ),
        ),
      );
      await tester.pumpAndSettle();

      final coach = coachFor(0, 0, 'en');
      // Az elso allomason a "Nezd meg eloszor" pelda latszik.
      expect(
        find.byKey(const ValueKey('lesson-worked-example')),
        findsOneWidget,
      );
      // A Start gorgetes nelkul kepernyon van 402x874-en.
      final nextTop = tester.getTopLeft(
        find.byKey(const ValueKey('lesson-coach-next')),
      );
      expect(nextTop.dy, lessThan(874));
      // A hosszu bevezeto szoveg alapbol NEM latszik.
      expect(find.text(coach.intro), findsNothing);
      expect(find.text(coach.why), findsNothing);

      // De a Details mogott minden megvan.
      await tester.scrollUntilVisible(
        find.byKey(const ValueKey('lesson-details')),
        300,
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('lesson-details')));
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(find.text(coach.intro), 300);
      await tester.pumpAndSettle();
      expect(find.text(coach.intro), findsOneWidget);
    });

    testWidgets('kesobbi allomas: csak a lenyeg, reszletek lenyithatok', (
      tester,
    ) async {
      SharedPreferences.setMockInitialValues({});
      AppLocalizations.useCode('en');
      await tester.pumpWidget(
        const MaterialApp(
          home: LessonPlayerPage(
            chapterIndex: 0,
            sectionIndex: 0,
            lessonIndex: 2,
          ),
        ),
      );
      await tester.pumpAndSettle();

      final coach = coachFor(0, 0, 'en');
      // Lenyeg: a 3 lepes latszik.
      for (final step in coach.steps) {
        await tester.scrollUntilVisible(find.text(step), 300);
        await tester.pumpAndSettle();
        expect(find.text(step), findsOneWidget);
      }
      // START gomb egybol elerheto.
      await tester.scrollUntilVisible(
        find.byKey(const ValueKey('lesson-coach-next')),
        300,
      );
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('lesson-coach-next')), findsOneWidget);

      // Hosszu bevezeto szoveg alapbol NEM latszik.
      expect(find.text(coach.intro), findsNothing);
      expect(find.text(coach.why), findsNothing);

      // De lenyithato reszletekbol elojon.
      await tester.scrollUntilVisible(
        find.byKey(const ValueKey('lesson-details')),
        300,
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('lesson-details')));
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(find.text(coach.intro), 300);
      await tester.pumpAndSettle();
      expect(find.text(coach.intro), findsOneWidget);
    });
  });
}
