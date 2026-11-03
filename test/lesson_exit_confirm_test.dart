import 'package:engrammo/l10n/app_localizations.dart';
import 'package:engrammo/screens/lesson_player.dart';
import 'package:engrammo/widgets/app_buttons.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<void> _openLesson(WidgetTester tester) async {
  SharedPreferences.setMockInitialValues({});
  await tester.pumpWidget(
    MaterialApp(
      home: Builder(
        builder: (ctx) => Scaffold(
          body: Center(
            child: TextButton(
              key: const ValueKey('open-lesson'),
              onPressed: () => Navigator.of(ctx).push(
                MaterialPageRoute(
                  builder: (_) => const LessonPlayerPage(
                    chapterIndex: 0,
                    sectionIndex: 0,
                    lessonIndex: 0,
                  ),
                ),
              ),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(const ValueKey('open-lesson')));
  await tester.pumpAndSettle();
}

Future<void> _startDrill(WidgetTester tester) async {
  await tester.scrollUntilVisible(
    find.byKey(const ValueKey('lesson-coach-next')),
    300,
  );
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(const ValueKey('lesson-coach-next')));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('coach-képernyőről kilépés azonnali, kérdés nélkül', (
    tester,
  ) async {
    await _openLesson(tester);
    expect(find.text('The Attention Gate'), findsOneWidget);

    await tester.tap(find.byType(EngramBackButton));
    await tester.pumpAndSettle();

    expect(find.text(tr('lp_exit_title')), findsNothing);
    expect(find.byKey(const ValueKey('open-lesson')), findsOneWidget);
  });

  testWidgets('futó feladatból kilépés megerősítést kér', (tester) async {
    await _openLesson(tester);
    await _startDrill(tester);
    expect(find.byKey(const ValueKey('lesson-memorized')), findsOneWidget);

    await tester.tap(find.byType(EngramBackButton));
    await tester.pumpAndSettle();
    expect(find.text(tr('lp_exit_title')), findsOneWidget);

    await tester.tap(find.text(tr('lp_exit_stay')));
    await tester.pumpAndSettle();
    expect(find.text(tr('lp_exit_title')), findsNothing);
    expect(find.byKey(const ValueKey('lesson-memorized')), findsOneWidget);

    await tester.tap(find.byType(EngramBackButton));
    await tester.pumpAndSettle();
    await tester.tap(find.text(tr('lp_exit_leave')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('open-lesson')), findsOneWidget);
  });
}
