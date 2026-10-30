import 'package:engrammo/models/claims_policy.dart'
    show bannedClaimTokens;
import 'package:engrammo/models/curriculum.dart'
    show chaptersForTrack, trackOfChapter;
import 'package:engrammo/models/marathon.dart';
import 'package:engrammo/screens/learning_path.dart' show LearningPathPage;
import 'package:engrammo/screens/lesson_player.dart'
    show LessonPlayerPage, lessonRoundsFor, loadLocalLessonTasks;
import 'package:engrammo/services/memory_store.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('full-course scale', () {
    test('minden pálya több tucat leckéből áll', () {
      for (var t = 0; t < 6; t++) {
        expect(
          lessonsInTrack(t),
          greaterThan(60),
          reason: 'track $t too short',
        );
      }
    });

    test('a teljes program több száz foglalkozás pályánként', () {
      for (var t = 0; t < 6; t++) {
        expect(
          sessionsToFinishTrack(t),
          greaterThan(800),
          reason: 'track $t full course too short',
        );
      }
    });

    test('a becsült gyakorlóidő túlmegy a 20 órás kutatási dózison', () {
      for (var t = 0; t < 6; t++) {
        final hours = estimatedMinutesToFinishTrack(t) / 60;
        expect(
          hours,
          greaterThan(labDoseMinutesPerTrack / 60),
          reason: 'track $t planned hours ($hours) under lab dose',
        );
        expect(
          hours,
          greaterThan(60),
          reason: 'track $t planned hours ($hours) too short for months',
        );
      }
    });

    test('a rések összege naptárban is sok hónap', () {
      expect(reviewGapDays.length, practiceDepths + 1);
      var total = 0;
      for (var d = 1; d <= practiceDepths; d++) {
        total += reviewGapDays[d];
      }
      expect(total, greaterThanOrEqualTo(180));
    });

    test('a fejezetek lefedik a pályájukat', () {
      for (var t = 0; t < 6; t++) {
        for (final c in chaptersForTrack(t)) {
          expect(trackOfChapter(c), t);
        }
      }
    });
  });

  group('depth math', () {
    test('depthForReps 0 és 11 közé vág', () {
      expect(practiceDepths, 11);
      expect(depthForReps(-3), 0);
      expect(depthForReps(0), 0);
      expect(depthForReps(3), 3);
      expect(depthForReps(10), 10);
      expect(depthForReps(11), practiceDepths);
      expect(depthForReps(99), practiceDepths);
    });

    test('a következő kör eggyel mélyebb, csillagos örökséggel is', () {
      expect(depthForNextSession(reps: 0, stars: 0), 0);
      expect(depthForNextSession(reps: 0, stars: 2), 1);
      expect(depthForNextSession(reps: 1, stars: 3), 1);
      expect(depthForNextSession(reps: 4, stars: 3), 4);
      expect(depthForNextSession(reps: 10, stars: 3), 10);
      expect(depthForNextSession(reps: 99, stars: 3), practiceDepths);
    });

    test('0. mélység az alapértelmezett játék', () {
      for (var base = 2; base <= 5; base++) {
        expect(roundsForDepth(base, 0), base);
      }
      expect(lagForDepth(0, 0), 0);
      expect(lagForDepth(1, 0), 1);
      expect(difficultyBoostForDepth(0), 0);
    });

    test('a körök, késleltetés és nehézség monoton nő', () {
      for (var base = 2; base <= 5; base++) {
        var last = 0;
        for (var d = 0; d <= practiceDepths; d++) {
          final rounds = roundsForDepth(base, d);
          expect(rounds, greaterThanOrEqualTo(last));
          expect(rounds, inInclusiveRange(2, 6));
          last = rounds;
        }
      }
      var lastLag = 0;
      for (var d = 0; d <= practiceDepths; d++) {
        final lag = lagForDepth(0, d);
        expect(lag, greaterThanOrEqualTo(lastLag));
        expect(lag, inInclusiveRange(0, 2));
        lastLag = lag;
      }
      var lastBoost = 0;
      for (var d = 0; d <= practiceDepths; d++) {
        final boost = difficultyBoostForDepth(d);
        expect(boost, greaterThanOrEqualTo(lastBoost));
        expect(boost, inInclusiveRange(0, 2));
        lastBoost = boost;
      }
      expect(roundsForDepth(3, practiceDepths), greaterThan(3));
      expect(difficultyBoostForDepth(practiceDepths), greaterThan(0));
    });

    test('a variánsmag determinisztikus és mélységenként más', () {
      final a = variantSeedFor(2, 1, 3, 2);
      expect(variantSeedFor(2, 1, 3, 2), a);
      final seen = <String>{};
      for (var d = 0; d <= practiceDepths; d++) {
        seen.add(variantSeedFor(2, 1, 3, d));
      }
      expect(seen.length, practiceDepths + 1);
    });

    test('a leckekulcs-formátum egyezik a tárolóéval', () {
      for (final c in [0, 2, 7, 30, 35]) {
        for (final s in [0, 2]) {
          for (final l in [0, 3]) {
            expect(
              marathonLessonKey(c, s, l),
              MemoryStore.lessonKey(c, s, l),
            );
          }
        }
      }
    });
  });

  group('tiers and track totals', () {
    test('tierszint-határok', () {
      expect(tierForAverageDepth(0), 'Foundation');
      expect(tierForAverageDepth(0.99), 'Foundation');
      expect(tierForAverageDepth(1), 'Building');
      expect(tierForAverageDepth(3.49), 'Building');
      expect(tierForAverageDepth(3.5), 'Solid');
      expect(tierForAverageDepth(5.49), 'Solid');
      expect(tierForAverageDepth(5.5), 'Deep');
      expect(tierForAverageDepth(8.99), 'Deep');
      expect(tierForAverageDepth(9), 'Durable');
      expect(tierForAverageDepth(11), 'Durable');
    });

    test('üres pálya: 0 átlag, 0 foglalkozás', () {
      for (var t = 0; t < 6; t++) {
        expect(
          trackDepthAverage(reps: {}, progress: {}, track: t),
          0,
        );
        expect(
          sessionsDoneOnTrack(reps: {}, progress: {}, track: t),
          0,
        );
      }
    });

    test('a csillagos örökség egy foglalkozásnak számít', () {
      final progress = {'0-0-0': 2, '0-0-1': 3};
      expect(
        sessionsDoneOnTrack(reps: {}, progress: progress, track: 0),
        2,
      );
      expect(
        trackDepthAverage(reps: {}, progress: progress, track: 0),
        greaterThan(0),
      );
    });

    test('az ismétlések sapkázva számítanak', () {
      final reps = {'0-0-0': 99};
      expect(
        sessionsDoneOnTrack(reps: reps, progress: {}, track: 0),
        sessionsPerLessonFull,
      );
      expect(
        trackDepthAverage(reps: reps, progress: {}, track: 0),
        closeTo(practiceDepths / lessonsInTrack(0), 0.0001),
      );
    });
  });

  group('spaced review', () {
    test('soha nem gyakorolt lecke most esedékes', () {
      expect(
        daysUntilReviewDue(
          lastDone: null,
          depth: 0,
          now: DateTime(2026, 10, 28),
        ),
        0,
      );
    });

    test('a rés nő a mélységgel', () {
      final now = DateTime(2026, 10, 28);
      var last = -1;
      for (var d = 0; d < reviewGapDays.length; d++) {
        final days = daysUntilReviewDue(
          lastDone: now,
          depth: d,
          now: now,
        );
        expect(days, greaterThan(last));
        last = days;
      }
    });

    test('lejárt review negatív vagy nulla', () {
      expect(
        daysUntilReviewDue(
          lastDone: DateTime(2026, 9, 1),
          depth: 0,
          now: DateTime(2026, 10, 28),
        ),
        lessThanOrEqualTo(0),
      );
    });
  });

  group('review locks', () {
    test('az alapkör és a dátum nélküli örökség mindig nyitva', () {
      final now = DateTime(2026, 10, 28);
      expect(
        practiceRoundLocked(
          lastDone: now,
          depth: 0,
          stars: 0,
          now: now,
        ),
        isFalse,
      );
      expect(
        practiceRoundLocked(
          lastDone: null,
          depth: 1,
          stars: 3,
          now: now,
        ),
        isFalse,
      );
    });

    test('friss gyakorlás után a következő kör zárva, lejártkor nyitva', () {
      final now = DateTime(2026, 10, 28);
      expect(
        practiceRoundLocked(
          lastDone: now,
          depth: 1,
          stars: 3,
          now: now,
        ),
        isTrue,
      );
      expect(
        practiceRoundLocked(
          lastDone: DateTime(2026, 10, 20),
          depth: 1,
          stars: 3,
          now: now,
        ),
        isFalse,
      );
    });

    test('a legmélyebb kör is zárral pihen, majd újra nyílik', () {
      final now = DateTime(2026, 10, 28);
      expect(
        practiceRoundLocked(
          lastDone: now,
          depth: practiceDepths,
          stars: 3,
          now: now,
        ),
        isTrue,
      );
      expect(
        practiceRoundLocked(
          lastDone: DateTime(2026, 1, 1),
          depth: practiceDepths,
          stars: 3,
          now: now,
        ),
        isFalse,
      );
    });

    test('a státuszcímke esedékest, holnapot és napszámot ír', () {
      final now = DateTime(2026, 10, 28);
      expect(
        reviewStatusLabel(lastDone: null, depth: 1, now: now),
        'Due for review',
      );
      final gap1 = reviewGapDays[1];
      expect(
        reviewStatusLabel(lastDone: now, depth: 1, now: now),
        gap1 == 1 ? 'Review tomorrow' : 'Review in $gap1 days',
      );
      final yesterday =
          now.subtract(const Duration(days: 1));
      final left = daysUntilReviewDue(
        lastDone: yesterday,
        depth: 1,
        now: now,
      );
      expect(left, gap1 - 1);
      expect(
        reviewStatusLabel(lastDone: yesterday, depth: 1, now: now),
        left <= 0
            ? 'Due for review'
            : left == 1
                ? 'Review tomorrow'
                : 'Review in $left days',
      );
    });

    test('a zárt üzenet megnevezi a kört és a várakozást', () {
      final msg = reviewLockedMessage(depth: 2, daysLeft: 5);
      expect(msg, contains('Practice round 2 of $practiceDepths'));
      expect(msg, contains('5 days'));
      expect(reviewLockedMessage(depth: 1, daysLeft: 1), contains('tomorrow'));
    });

    test('a következő-review sor napot vagy holnapot ír', () {
      expect(nextReviewLine(daysLeft: 7), contains('7 days'));
      expect(nextReviewLine(daysLeft: 1), contains('tomorrow'));
      expect(nextReviewLine(daysLeft: 0), contains('Due for review'));
    });
  });

  group('honest wording', () {
    test('egyetlen maraton-szöveg sem tartalmaz tiltott ígéretet', () {
      final lines = <String>[
        for (var d = 0; d <= practiceDepths; d++) depthChipLabel(d),
        for (var t = 0; t < 6; t++) trackProgramLine(t),
        labDoseProgressLine(0),
        labDoseProgressLine(210),
        labDoseProgressLine(labDoseMinutesPerTrack),
        labDoseProgressLine(labDoseMinutesPerTrack + 1),
        labDoseProgressLine(stretchDoseMinutesPerTrack),
        labDoseProgressLine(stretchDoseMinutesPerTrack + 600),
        for (final avg in [0.0, 1.0, 3.5, 5.5, 9.0, 11.0])
          tierForAverageDepth(avg),
        reviewStatusLabel(
          lastDone: DateTime(2026, 10, 28),
          depth: 1,
          now: DateTime(2026, 10, 28),
        ),
        reviewStatusLabel(
          lastDone: DateTime(2026, 10, 20),
          depth: 3,
          now: DateTime(2026, 10, 28),
        ),
        reviewLockedMessage(depth: 2, daysLeft: 5),
        reviewLockedMessage(depth: 1, daysLeft: 1),
        nextReviewLine(daysLeft: 7),
        nextReviewLine(daysLeft: 1),
      ];
      for (final line in lines) {
        final lower = line.toLowerCase();
        for (final banned in bannedClaimTokens) {
          expect(
            lower.contains(banned.toLowerCase()),
            isFalse,
            reason: 'banned "$banned" in: $line',
          );
        }
      }
    });

    test('a dózissor a kutatási dózist nevezi meg', () {
      expect(labDoseProgressLine(0), contains('Dresler'));
      expect(labDoseProgressLine(0), contains('20 hours'));
      expect(trackProgramLine(0), contains('Dresler'));
    });
  });

  group('marathon persistence', () {
    test('friss fiókban üresek a maraton-számlálók', () async {
      expect(await MemoryStore.loadLessonReps(), isEmpty);
      expect(await MemoryStore.loadTrackMinutes(), isEmpty);
      expect(await MemoryStore.loadLessonDoneDates(), isEmpty);
    });

    test('recordLessonSession számol, percez és dátumoz', () async {
      final now = DateTime(2026, 10, 28, 19, 30);
      await MemoryStore.recordLessonSession(
        track: 2,
        chapter: 2,
        section: 0,
        lesson: 0,
        minutes: 4,
        now: now,
      );
      await MemoryStore.recordLessonSession(
        track: 2,
        chapter: 2,
        section: 0,
        lesson: 0,
        minutes: 6,
        now: now,
      );
      final reps = await MemoryStore.loadLessonReps();
      expect(reps[MemoryStore.lessonKey(2, 0, 0)], 2);
      final minutes = await MemoryStore.loadTrackMinutes();
      expect(minutes['2'], 10);
      expect(minutes['0'], isNull);
      final dates = await MemoryStore.loadLessonDoneDates();
      expect(dates[MemoryStore.lessonKey(2, 0, 0)], now);
    });

    test('az ismétlésszámláló sapkázott', () async {
      await MemoryStore.saveLessonReps({'0-0-0': 500});
      final reps = await MemoryStore.loadLessonReps();
      expect(reps['0-0-0'], maxStoredReps);
    });

    test('a hibás dátumsor nem öli meg a listát', () async {
      await MemoryStore.saveLessonDoneDates({
        '0-0-0': DateTime(2026, 10, 28),
      });
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getStringList('lesson_done_v1') ?? [];
      await prefs.setStringList('lesson_done_v1', [...raw, 'broken-row']);
      final dates = await MemoryStore.loadLessonDoneDates();
      expect(dates.containsKey('0-0-0'), isTrue);
    });
  });

  group('player depth wiring', () {
    test('0. mélység: ugyanaz a körszám és mag, mint eddig', () {
      for (var c = 0; c < 8; c++) {
        final rounds = lessonRoundsFor(c, 1, 2);
        final tasks = loadLocalLessonTasks(
          chapter: c,
          section: 1,
          lesson: 2,
        );
        expect(tasks.length, rounds);
      }
    });

    test('mélyebb kör: több feladat, más mag', () {
      final shallow = loadLocalLessonTasks(
        chapter: 3,
        section: 2,
        lesson: 3,
      );
      final deep = loadLocalLessonTasks(
        chapter: 3,
        section: 2,
        lesson: 3,
        depth: practiceDepths,
      );
      expect(deep.length, greaterThanOrEqualTo(shallow.length));
      final again = loadLocalLessonTasks(
        chapter: 3,
        section: 2,
        lesson: 3,
        depth: practiceDepths,
      );
      expect(again.length, deep.length);
      var sameAsShallow = 0;
      for (var i = 0; i < shallow.length; i++) {
        if (deep[i].items.join('|') == shallow[i].items.join('|')) {
          sameAsShallow++;
        }
      }
      expect(sameAsShallow, lessThan(shallow.length));
    });
  });

  testWidgets('a coach-kártya mutatja a gyakorlókör mélységét', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(
      const MaterialApp(
        home: LessonPlayerPage(
          chapterIndex: 0,
          sectionIndex: 1,
          lessonIndex: 0,
          practiceDepth: 2,
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('lesson-depth-chip')),
      300,
    );
    await tester.pumpAndSettle();
    expect(
      find.text(depthChipLabel(2)),
      findsOneWidget,
    );
  });

  testWidgets('a pálya alján látszik a hosszú program blokkja', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(const MaterialApp(home: LearningPathPage()));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('track-program-block')),
      500,
    );
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('track-program-block')),
      findsOneWidget,
    );
    final total = sessionsToFinishTrack(0);
    expect(find.text('Foundation • 0 of $total sessions'), findsOneWidget);
    expect(find.text(labDoseProgressLine(0)), findsOneWidget);
  });

  testWidgets('a friss lecke újranyitása zárva, várakozást ír', (
    tester,
  ) async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    SharedPreferences.setMockInitialValues({
      'chapter_progress_v1': ['0-0-0=3'],
      'lesson_reps_v1': ['0-0-0=1'],
      'lesson_done_v1': ['0-0-0=${today.toIso8601String()}'],
    });
    await tester.pumpWidget(const MaterialApp(home: LearningPathPage()));
    await tester.pumpAndSettle();

    final daysLeft = daysUntilReviewDue(
      lastDone: today,
      depth: 1,
      now: now,
    );
    expect(daysLeft, greaterThan(0));
    await tester.ensureVisible(
      find.byKey(const ValueKey('path-lesson-0-0-0')),
    );
    await tester.pumpAndSettle();
    expect(
      find.text(reviewLockedMessage(depth: 1, daysLeft: daysLeft)),
      findsNothing,
    );
    await tester.tap(find.byKey(const ValueKey('path-lesson-0-0-0')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('lesson-coach-next')), findsNothing);
    expect(
      find.text(reviewLockedMessage(depth: 1, daysLeft: daysLeft)),
      findsOneWidget,
    );
    expect(find.byType(LearningPathPage), findsOneWidget);
  });

  testWidgets('a lejárt review újranyitható', (tester) async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final old = today.subtract(const Duration(days: 90));
    SharedPreferences.setMockInitialValues({
      'chapter_progress_v1': ['0-0-0=3'],
      'lesson_reps_v1': ['0-0-0=1'],
      'lesson_done_v1': ['0-0-0=${old.toIso8601String()}'],
    });
    await tester.pumpWidget(const MaterialApp(home: LearningPathPage()));
    await tester.pumpAndSettle();

    expect(
      daysUntilReviewDue(lastDone: old, depth: 1, now: now),
      lessThanOrEqualTo(0),
    );
    await tester.ensureVisible(
      find.byKey(const ValueKey('path-lesson-0-0-0')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('path-lesson-0-0-0')));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('lesson-coach-next')),
      300,
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('lesson-coach-next')), findsOneWidget);
  });
}
