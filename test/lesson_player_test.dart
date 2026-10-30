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

Future<MetaTask> _expectedRoundTask(
  int chapter,
  int section,
  int lesson,
  int round,
) {
  final rounds = lessonRoundsFor(chapter, section, lesson);
  return MetaAIService.generateTask(
    MetaTaskRequest(
      kind: lessonRoundKindFor(chapter, lesson, round, rounds),
      difficulty: lessonRoundDifficultyFor(
        chapter,
        section,
        lesson,
        round,
        rounds,
      ),
      seed: '$chapter-$section-$lesson-r$round',
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

    expect(find.text('The Attention Gate'), findsOneWidget);

    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('lesson-coach-next')),
      300,
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('lesson-coach-next')), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('lesson-coach-next')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('lesson-memorized')), findsOneWidget);

    var answered = 0;
    for (var guard = 0; guard < 30; guard++) {
      await tester.pumpAndSettle();
      if (find
          .byKey(const ValueKey('lesson-continue'))
          .evaluate()
          .isNotEmpty) {
        break;
      }
      if (find
          .byKey(const ValueKey('lesson-next-step'))
          .evaluate()
          .isNotEmpty) {
        await tester.tap(find.byKey(const ValueKey('lesson-next-step')));
        continue;
      }
      if (find
          .byKey(const ValueKey('lesson-memorized'))
          .evaluate()
          .isNotEmpty) {
        await tester.ensureVisible(
          find.byKey(const ValueKey('lesson-memorized')),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const ValueKey('lesson-memorized')));
        continue;
      }
      final expected = await _expectedRoundTask(0, 0, 0, answered);
      final right = 'lesson-option-${expected.correct}';
      expect(find.byKey(ValueKey(right)), findsOneWidget);
      await tester.tap(find.byKey(ValueKey(right)));
      answered++;
    }

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
    for (var i = 0; i < 20; i++) {
      await tester.pump(const Duration(milliseconds: 100));
      if (find.byKey(const ValueKey('lesson-memorized')).evaluate().isNotEmpty) {
        break;
      }
    }
    expect(find.byKey(const ValueKey('lesson-memorized')), findsOneWidget);
  });

  testWidgets('Palace Step 2 lógó hálózattal is továbblép', (tester) async {
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
      for (var i = 0; i < 20; i++) {
        await tester.pump(const Duration(seconds: 1));
        if (find.byKey(const ValueKey('lesson-memorized')).evaluate().isNotEmpty) {
          break;
        }
      }
      expect(find.byKey(const ValueKey('lesson-memorized')), findsOneWidget);
    } finally {
      for (var i = 0; i < 100; i++) {
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

    var answered = 0;
    for (var guard = 0; guard < 30; guard++) {
      await tester.pumpAndSettle();
      if (find
          .byKey(const ValueKey('lesson-continue'))
          .evaluate()
          .isNotEmpty) {
        break;
      }
      if (find
          .byKey(const ValueKey('lesson-next-step'))
          .evaluate()
          .isNotEmpty) {
        await tester.tap(find.byKey(const ValueKey('lesson-next-step')));
        continue;
      }
      if (find
          .byKey(const ValueKey('lesson-memorized'))
          .evaluate()
          .isNotEmpty) {
        await tester.ensureVisible(
          find.byKey(const ValueKey('lesson-memorized')),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const ValueKey('lesson-memorized')));
        continue;
      }
      final expected = await _expectedRoundTask(1, 0, 0, answered);
      final wrong =
          'lesson-option-${(expected.correct + 1) % expected.options.length}';
      expect(find.byKey(ValueKey(wrong)), findsOneWidget);
      await tester.tap(find.byKey(ValueKey(wrong)));
      answered++;
    }
    expect(answered, 2);

    expect(find.text('1/3 stars'), findsOneWidget);
    final progress = await MemoryStore.loadChapterProgress();
    expect(progress[MemoryStore.lessonKey(1, 0, 0)], 1);
  });
}

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
