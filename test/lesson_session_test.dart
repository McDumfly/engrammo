import 'dart:async';

import 'package:engrammo/models/meta_task.dart';
import 'package:engrammo/screens/lesson_player.dart';
import 'package:engrammo/services/memory_store.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('lessonRoundsFor', () {
    test('kezdő állomás egyetlen feladat', () {
      expect(lessonRoundsFor(0, 0, 0), 1);
      expect(lessonRoundsFor(0, 0, 1), 1);
      expect(lessonRoundsFor(1, 0, 0), 1);
    });

    test('későbbi partok több feladatot láncolnak', () {
      expect(lessonRoundsFor(0, 0, 2), 2);
      expect(lessonRoundsFor(0, 2, 3), greaterThan(2));
      expect(lessonRoundsFor(2, 2, 3), 4);
    });

    test('1 és 5 között marad a Gauntlet végén is', () {
      expect(lessonRoundsFor(7, 2, 3), 5);
      for (var c = 0; c < 8; c++) {
        for (var s = 0; s < 3; s++) {
          for (var l = 0; l < 4; l++) {
            final r = lessonRoundsFor(c, s, l);
            expect(r, inInclusiveRange(1, 5));
          }
        }
      }
    });
  });

  group('lessonLagFor', () {
    test('rövid sorozatban azonnali a kérdés', () {
      expect(lessonLagFor(1, 0), 0);
      expect(lessonLagFor(2, 3), 0);
    });

    test('3+ feladattól késleltetett a kérdés', () {
      expect(lessonLagFor(3, 2), 1);
      expect(lessonLagFor(4, 2), 1);
    });

    test('5 feladattól vagy Gauntletben két inger jön közbe', () {
      expect(lessonLagFor(5, 0), 2);
      expect(lessonLagFor(4, 7), 2);
    });
  });

  group('lessonSessionPlan', () {
    test('lag 0: inger után egyből kérdés', () {
      final plan = lessonSessionPlan(3, 0);
      expect(
        plan.map((s) => '${s.stimulus ? 'S' : 'Q'}${s.task}').toList(),
        ['S0', 'Q0', 'S1', 'Q1', 'S2', 'Q2'],
      );
    });

    test('lag 1: a kérdés egy ingerrel később jön', () {
      final plan = lessonSessionPlan(4, 1);
      expect(
        plan.map((s) => '${s.stimulus ? 'S' : 'Q'}${s.task}').toList(),
        ['S0', 'S1', 'Q0', 'S2', 'Q1', 'S3', 'Q2', 'Q3'],
      );
    });

    test('lag 2: a kérdés két ingerrel később jön', () {
      final plan = lessonSessionPlan(5, 2);
      expect(
        plan.map((s) => '${s.stimulus ? 'S' : 'Q'}${s.task}').toList(),
        ['S0', 'S1', 'S2', 'Q0', 'S3', 'Q1', 'S4', 'Q2', 'Q3', 'Q4'],
      );
    });

    test('minden ingerhez pontosan egy kérdés tartozik', () {
      for (var rounds = 1; rounds <= 5; rounds++) {
        for (var lag = 0; lag <= 2; lag++) {
          final plan = lessonSessionPlan(rounds, lag);
          expect(plan.length, rounds * 2);
          for (var t = 0; t < rounds; t++) {
            expect(plan.where((s) => s.stimulus && s.task == t).length, 1);
            expect(plan.where((s) => !s.stimulus && s.task == t).length, 1);
          }
        }
      }
    });
  });

  group('lessonRoundKindFor', () {
    test('egyfeladatos állomás tartja a lecke típusát', () {
      expect(
        lessonRoundKindFor(2, 0, 0, 1),
        lessonKindFor(2, 0),
      );
    });

    test('többfeladatos sorozat keresztbe edz', () {
      final base = lessonKindFor(0, 0);
      final kinds = [
        for (var r = 0; r < 4; r++) lessonRoundKindFor(0, 0, r, 4),
      ];
      expect(kinds.first, base);
      expect(kinds.toSet().length, greaterThan(1));
    });
  });

  group('loadLessonTasks', () {
    test('lógó betöltésből időkorlát után helyi tartalék lesz', () async {
      final tasks = await loadLessonTasks(
        chapter: 2,
        section: 0,
        lesson: 1,
        loadRound: (_) => Completer<MetaTask>().future,
        timeout: const Duration(milliseconds: 50),
      );
      expect(tasks, hasLength(lessonRoundsFor(2, 0, 1)));
      expect(tasks.first.paradigm, 'loci-drill');
    });

    test('dobó betöltésből azonnal helyi tartalék lesz', () async {
      final tasks = await loadLessonTasks(
        chapter: 0,
        section: 0,
        lesson: 0,
        loadRound: (_) => Future<MetaTask>.error(StateError('boom')),
      );
      expect(tasks, hasLength(lessonRoundsFor(0, 0, 0)));
    });
  });

  group('lessonSessionStars', () {
    test('egyetlen jó gyors válasz 3 csillag', () {
      expect(
        lessonSessionStars(
          correct: 1,
          total: 1,
          elapsed: const Duration(seconds: 3),
        ),
        3,
      );
    });

    test('mind jó, de lassú: 2 csillag', () {
      expect(
        lessonSessionStars(
          correct: 2,
          total: 2,
          elapsed: const Duration(seconds: 60),
        ),
        2,
      );
    });

    test('többség jó: 2, kevés jó: 1, nulla mentés nincs', () {
      expect(
        lessonSessionStars(
          correct: 2,
          total: 3,
          elapsed: const Duration(seconds: 9),
        ),
        2,
      );
      expect(
        lessonSessionStars(
          correct: 1,
          total: 3,
          elapsed: const Duration(seconds: 9),
        ),
        1,
      );
    });
  });

  testWidgets('többfeladatos állomás késleltetett kérdésekkel végigjátszható', (
    tester,
  ) async {
    // 2-2-3: 4 feladat, lag 1 -> S0,S1,Q0,S2,Q1,S3,Q2,Q3.
    expect(lessonRoundsFor(2, 2, 3), 4);
    expect(lessonLagFor(4, 2), 1);
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(
      const MaterialApp(
        home: LessonPlayerPage(
          chapterIndex: 2,
          sectionIndex: 2,
          lessonIndex: 3,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('lesson-coach-next')),
      300,
    );
    await tester.pumpAndSettle();
    // Nehéz állomáson a coach jelzi a sorozatot és a késleltetést.
    expect(find.byKey(const ValueKey('lesson-session-info')), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('lesson-coach-next')));
    await tester.pumpAndSettle();

    // A terv szerint felváltva inger és kérdés jön (4+4 lépés):
    // addig lépünk, amíg a kész-képernyő meg nem épül (a CONTINUE
    // a hosszú lista alján a hajtás alá is kerülhet).
    final contGone = find.byKey(const ValueKey('lesson-continue'));
    final contBuilt = find.byKey(
      const ValueKey('lesson-continue'),
      skipOffstage: false,
    );
    for (var guard = 0; guard < 30; guard++) {
      await tester.pumpAndSettle();
      if (contBuilt.evaluate().isNotEmpty) break;
      if (find
          .byKey(const ValueKey('lesson-next-step'))
          .evaluate()
          .isNotEmpty) {
        await tester.tap(find.byKey(const ValueKey('lesson-next-step')));
        continue;
      }
      if (find.byKey(const ValueKey('lesson-memorized')).evaluate().isNotEmpty) {
        await tester.tap(find.byKey(const ValueKey('lesson-memorized')));
        continue;
      }
      await tester.tap(find.byKey(const ValueKey('lesson-option-0')));
    }
    await tester.scrollUntilVisible(contGone, 300);
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('lesson-continue')), findsOneWidget);
    expect(find.textContaining('/3 stars'), findsOneWidget);
    final progress = await MemoryStore.loadChapterProgress();
    final stars = progress[MemoryStore.lessonKey(2, 2, 3)] ?? 0;
    expect(stars, inInclusiveRange(1, 3));
  });
}
