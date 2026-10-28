import 'dart:async';
import 'dart:io';

import 'package:engrammo/models/meta_task.dart';
import 'package:engrammo/screens/lesson_player.dart';
import 'package:engrammo/services/env_loader.dart';
import 'package:engrammo/services/memory_store.dart';
import 'package:engrammo/services/meta_ai_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// A leckejátékos által generált feladat, ugyanazzal a kéréssel —
/// a helyi generátor seed-determinisztikus, így a teszt előre tudja
/// a helyes opció indexét (a keverés miatt az már nem fixen 0).
Future<MetaTask> _expectedTask(int chapter, int section, int lesson) {
  final rounds = lessonRoundsFor(chapter, section, lesson);
  return MetaAIService.generateTask(
    MetaTaskRequest(
      kind: lessonRoundKindFor(chapter, lesson, 0, rounds),
      difficulty: lessonRoundDifficultyFor(chapter, section, lesson, 0, rounds),
      seed: '$chapter-$section-$lesson-r0',
      locale: 'en',
    ),
  );
}

void main() {
  testWidgets('lecke végigjátszható és csillagot ment', (tester) async {
    SharedPreferences.setMockInitialValues({});
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

    // Coach-kártya angol magyarázattal.
    expect(find.text('The Attention Gate'), findsOneWidget);

    // A START DRILL a hosszú coach-lista alján ül: görgetve hozzuk
    // láthatóvá (a lista lusta építése miatt csak így koppintható).
    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('lesson-coach-next')),
      300,
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('lesson-coach-next')), findsOneWidget);

    // Gyakorlat indítása -> inger (offline tartalék).
    await tester.tap(find.byKey(const ValueKey('lesson-coach-next')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('lesson-memorized')), findsOneWidget);

    // Kérdés -> helyes válasz (a generátorból kiolvasott index).
    await tester.ensureVisible(
      find.byKey(const ValueKey('lesson-memorized')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('lesson-memorized')));
    await tester.pumpAndSettle();
    final expected = await _expectedTask(0, 0, 0);
    final right = 'lesson-option-${expected.correct}';
    expect(find.byKey(ValueKey(right)), findsOneWidget);
    await tester.tap(find.byKey(ValueKey(right)));
    await tester.pumpAndSettle();

    // Csillag + mentés + folytatás.
    expect(find.text('3/3 stars'), findsOneWidget);
    final progress = await MemoryStore.loadChapterProgress();
    expect(progress[MemoryStore.lessonKey(0, 0, 0)], 3);
    expect(find.byKey(const ValueKey('lesson-continue')), findsOneWidget);
  });

  testWidgets('Palace Builder Step 2 nem ragad töltésbe', (tester) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(
      const MaterialApp(
        home: LessonPlayerPage(
          chapterIndex: 2,
          sectionIndex: 0,
          lessonIndex: 1,
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('lesson-coach-next')),
      300,
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('lesson-coach-next')));
    // A térbeli dúsítás kulcs nélkül azonnali helyi tartalék: néhány
    // képkocka alatt ingernek kell jönnie, nem örök spinnernek.
    for (var i = 0; i < 20; i++) {
      await tester.pump(const Duration(milliseconds: 100));
      if (find.byKey(const ValueKey('lesson-memorized')).evaluate().isNotEmpty) {
        break;
      }
    }
    expect(find.byKey(const ValueKey('lesson-memorized')), findsOneWidget);
  });

  testWidgets('Palace Step 2 lógó hálózattal is továbblép', (tester) async {
    // Kulcs van (élő ág), de a szerver soha nem válaszol: a játékos
    // ilyenkor sem ragadhat a töltőképernyőn, hanem a helyi
    // tartalékfeladattal folytatja.
    SharedPreferences.setMockInitialValues({});
    EnvLoader.loadFromStringForTest('MODEL_API_KEY=test-key');
    HttpOverrides.global = _HangingHttpOverrides();
    addTearDown(() {
      HttpOverrides.global = null;
      EnvLoader.resetForTest();
    });
    await tester.pumpWidget(
      const MaterialApp(
        home: LessonPlayerPage(
          chapterIndex: 2,
          sectionIndex: 0,
          lessonIndex: 1,
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('lesson-coach-next')),
      300,
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('lesson-coach-next')));
    try {
      // Lógó hálózatnál 20 s virtuális idő alatt megjön az inger:
      // a régi lánc (feladat + kép + szegmentálás, egyenként 12 s)
      // 36 s-ig is elüldögélne a spinneren.
      for (var i = 0; i < 20; i++) {
        await tester.pump(const Duration(seconds: 1));
        if (find.byKey(const ValueKey('lesson-memorized')).evaluate().isNotEmpty) {
          break;
        }
      }
      expect(find.byKey(const ValueKey('lesson-memorized')), findsOneWidget);
    } finally {
      // Az elárvult belső hívások 12 s-es időzítőit is kifuttatjuk,
      // hogy ne maradjon függő Timer a teszt végén.
      for (var i = 0; i < 60; i++) {
        await tester.pump(const Duration(seconds: 1));
      }
    }
  });

  testWidgets('hibás válasz 1 csillagot ment, nem nullát', (tester) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(
      const MaterialApp(
        home: LessonPlayerPage(
          chapterIndex: 1,
          sectionIndex: 0,
          lessonIndex: 0,
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('lesson-coach-next')),
      300,
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('lesson-coach-next')));
    await tester.pumpAndSettle();
    await tester.ensureVisible(
      find.byKey(const ValueKey('lesson-memorized')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('lesson-memorized')));
    await tester.pumpAndSettle();

    // Biztosan hibás válasz: a helyes utáni opció (körbe).
    final expected = await _expectedTask(1, 0, 0);
    final wrong =
        'lesson-option-${(expected.correct + 1) % expected.options.length}';
    await tester.tap(find.byKey(ValueKey(wrong)));
    await tester.pumpAndSettle();

    expect(find.text('1/3 stars'), findsOneWidget);
    final progress = await MemoryStore.loadChapterProgress();
    expect(progress[MemoryStore.lessonKey(1, 0, 0)], 1);
  });
}

/// Soha meg nem jövő válasz: a kérést befogadja, a választ nem küldi.
/// A `package:http` IOClient ezen keresztül megy (`HttpClient()` gyári
/// konstruktor), így a teljes Meta-hálózat lógását szimulálja.
class _HangingHttpOverrides extends HttpOverrides {
  @override
  HttpClient createHttpClient(SecurityContext? context) =>
      _HangingHttpClient();
}

class _HangingHttpClient implements HttpClient {
  @override
  Future<HttpClientRequest> openUrl(String method, Uri url) =>
      Future.value(_HangingHttpRequest());

  @override
  dynamic noSuchMethod(Invocation invocation) {
    if (invocation.isSetter) return null;
    if (invocation.isMethod) return null;
    return super.noSuchMethod(invocation);
  }
}

class _HangingHttpRequest implements HttpClientRequest {
  @override
  HttpHeaders get headers => _HangingHttpHeaders();

  @override
  Future<dynamic> addStream(Stream<List<int>> stream) =>
      Completer<dynamic>().future;

  @override
  Future<HttpClientResponse> close() => Completer<HttpClientResponse>().future;

  @override
  dynamic noSuchMethod(Invocation invocation) {
    if (invocation.isSetter) return null;
    if (invocation.isMethod) return null;
    return super.noSuchMethod(invocation);
  }
}

class _HangingHttpHeaders implements HttpHeaders {
  @override
  dynamic noSuchMethod(Invocation invocation) {
    if (invocation.isSetter) return null;
    if (invocation.isMethod) return null;
    return super.noSuchMethod(invocation);
  }
}
