// FX6 layout overflow safety net (MANDATORY).
//
// Matrix: 2 sizes [375x667, 402x874] x 2 text scales [1.0, 1.2] x
// 2 locales [en, hu], all in the light theme. AuthScreen,
// RoomPalaceHomeCard and SessionCoachCard additionally run in the dark
// theme. One testWidgets per combination with a readable name, so a
// failure says exactly which combo broke.
//
// Never pumpAndSettle on repeating animations: pump(Duration) only.
// Surface size is reset in addTearDown.
import 'dart:typed_data';

import 'package:engrammo/l10n/app_localizations.dart';
import 'package:engrammo/models/fsrs_card.dart';
import 'package:engrammo/models/room_palace.dart';
import 'package:engrammo/screens/auth_screen.dart';
import 'package:engrammo/screens/benchmark.dart';
import 'package:engrammo/screens/learning_path.dart';
import 'package:engrammo/screens/onboarding.dart';
import 'package:engrammo/screens/room_palace_page.dart';
import 'package:engrammo/services/auth_service.dart';
import 'package:engrammo/services/memory_store.dart';
import 'package:engrammo/services/meta_ai_service.dart';
import 'package:engrammo/services/room_photo.dart';
import 'package:engrammo/theme/app_theme.dart';
import 'package:engrammo/widgets/room_palace_home_card.dart';
import 'package:engrammo/widgets/session_coach_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:shared_preferences/shared_preferences.dart';

const _sizes = <Size>[Size(375, 667), Size(402, 874)];
const _scales = <double>[1.0, 1.2];
const _locales = <String>['en', 'hu'];

String _combo(Size s, double scale, String locale, String theme) =>
    '${s.width.toInt()}x${s.height.toInt()} x$scale $locale $theme';

/// Drains EVERY pending FlutterError so the failure lists each overflow
/// (with its pixel count) instead of only the first one.
void _expectNoFlutterErrors(WidgetTester tester) {
  final errors = <Object>[];
  Object? e;
  do {
    e = tester.takeException();
    if (e != null) errors.add(e);
  } while (e != null);
  expect(errors, isEmpty, reason: errors.join('\n---\n'));
}

/// Pumps [home] at the given size/scale/locale/theme, runs [interact]
/// (taps, text entry), then scrolls through any vertical list so that
/// lazily laid-out rows overflow loudly too.
Future<void> _pumpCombo(
  WidgetTester tester, {
  required Widget home,
  required Size size,
  required double scale,
  required String locale,
  required bool dark,
  Future<void> Function()? seed,
  Future<void> Function(WidgetTester)? interact,
}) async {
  SharedPreferences.setMockInitialValues({});
  MemoryStore.clearMemoryCache();
  BenchmarkStore.resetForTest();
  MetaAIService.secureStoreForTest = {};
  MetaAIService.consentForTest = null;
  authService.exitGuest();
  AppLocalizations.useCode(locale);
  if (seed != null) await seed();
  await tester.binding.setSurfaceSize(size);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(
    MediaQuery(
      data: MediaQueryData(size: size, textScaler: TextScaler.linear(scale)),
      child: MaterialApp(
        theme: dark ? AppTheme.dark() : AppTheme.light(),
        // WidgetsApp may rebuild the outer MediaQuery from the view;
        // re-apply the scale inside so the 1.2 pass really runs at 1.2.
        builder: (context, child) {
          final mq = MediaQuery.of(context);
          return MediaQuery(
            data: mq.copyWith(textScaler: TextScaler.linear(scale)),
            child: child!,
          );
        },
        home: home,
      ),
    ),
  );
  await tester.pump(const Duration(milliseconds: 800));
  if (interact != null) await interact(tester);
  final sv = find.byType(SingleChildScrollView);
  final lv = find.byType(ListView);
  final Finder? target = sv.evaluate().isNotEmpty
      ? sv.first
      : (lv.evaluate().isNotEmpty ? lv.first : null);
  if (target != null) {
    for (var k = 0; k < 6; k++) {
      await tester.drag(target, const Offset(0, -400));
      await tester.pump(const Duration(milliseconds: 300));
    }
  }
  await tester.pump(const Duration(milliseconds: 300));
  _expectNoFlutterErrors(tester);
}

String _tinyPhoto() => squareJpegDataUrl(
  Uint8List.fromList(img.encodePng(img.Image(width: 10, height: 10))),
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('AuthScreen collapsed', () {
    for (final size in _sizes) {
      for (final scale in _scales) {
        for (final locale in _locales) {
          testWidgets('AuthScreen ${_combo(size, scale, locale, 'light')}', (
            tester,
          ) async {
            await _pumpCombo(
              tester,
              home: const AuthScreen(),
              size: size,
              scale: scale,
              locale: locale,
              dark: false,
            );
          });
          testWidgets('AuthScreen ${_combo(size, scale, locale, 'dark')}', (
            tester,
          ) async {
            await _pumpCombo(
              tester,
              home: const AuthScreen(),
              size: size,
              scale: scale,
              locale: locale,
              dark: true,
            );
          });
        }
      }
    }
  });

  group('AuthScreen email form', () {
    for (final size in _sizes) {
      for (final scale in _scales) {
        for (final locale in _locales) {
          Future<void> openForm(WidgetTester tester) async {
            await tester.ensureVisible(find.text(tr('auth_email_toggle')));
            await tester.pump(const Duration(milliseconds: 300));
            await tester.tap(find.text(tr('auth_email_toggle')));
            await tester.pump(const Duration(milliseconds: 800));
          }

          testWidgets(
            'AuthScreen email ${_combo(size, scale, locale, 'light')}',
            (tester) async {
              await _pumpCombo(
                tester,
                home: const AuthScreen(),
                size: size,
                scale: scale,
                locale: locale,
                dark: false,
                interact: openForm,
              );
            },
          );
          testWidgets(
            'AuthScreen email ${_combo(size, scale, locale, 'dark')}',
            (tester) async {
              await _pumpCombo(
                tester,
                home: const AuthScreen(),
                size: size,
                scale: scale,
                locale: locale,
                dark: true,
                interact: openForm,
              );
            },
          );
        }
      }
    }
  });

  group('OnboardingPage', () {
    for (var page = 0; page < 4; page++) {
      for (final size in _sizes) {
        for (final scale in _scales) {
          for (final locale in _locales) {
            testWidgets(
              'OnboardingPage p$page ${_combo(size, scale, locale, 'light')}',
              (tester) async {
                await _pumpCombo(
                  tester,
                  home: Scaffold(body: OnboardingPage(onDone: () {})),
                  size: size,
                  scale: scale,
                  locale: locale,
                  dark: false,
                  interact: (tester) async {
                    for (var i = 0; i < page; i++) {
                      await tester.tap(find.text(tr('onboarding_next')));
                      await tester.pump(const Duration(milliseconds: 800));
                    }
                  },
                );
                expect(find.byType(OnboardingPage), findsOneWidget);
              },
            );
          }
        }
      }
    }
  });

  group('RoomPalaceHomeCard', () {
    for (final size in _sizes) {
      for (final scale in _scales) {
        for (final locale in _locales) {
          Widget cardHome() => Scaffold(
            body: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              children: const [RoomPalaceHomeCard()],
            ),
          );
          testWidgets(
            'RoomPalaceHomeCard ${_combo(size, scale, locale, 'light')}',
            (tester) async {
              await _pumpCombo(
                tester,
                home: cardHome(),
                size: size,
                scale: scale,
                locale: locale,
                dark: false,
              );
            },
          );
          testWidgets(
            'RoomPalaceHomeCard ${_combo(size, scale, locale, 'dark')}',
            (tester) async {
              await _pumpCombo(
                tester,
                home: cardHome(),
                size: size,
                scale: scale,
                locale: locale,
                dark: true,
              );
            },
          );
        }
      }
    }
  });

  group('BenchmarkHubPage', () {
    // Plausibly large bests so the right-hand best column (not just
    // the chevron) renders in every combo.
    Future<void> seedBests() => MemoryStore.saveBenchmark(
      const BenchmarkState(
        best: {
          'sequence': 64,
          'number': 2048,
          'verbal': 1234,
          'visual': 32,
          'order': 512,
          'spatial': 96,
        },
      ),
    );

    for (final size in _sizes) {
      for (final scale in _scales) {
        for (final locale in _locales) {
          testWidgets(
            'BenchmarkHubPage ${_combo(size, scale, locale, 'light')}',
            (tester) async {
              await _pumpCombo(
                tester,
                home: const BenchmarkHubPage(),
                size: size,
                scale: scale,
                locale: locale,
                dark: false,
                seed: seedBests,
                interact: (tester) async {
                  // One more frame for BenchmarkStore.ensureLoaded.
                  await tester.pump(const Duration(milliseconds: 300));
                  expect(find.text(tr('bench_hub_title')), findsOneWidget);
                  // The seeded best column really rendered: rows below
                  // the fold are not even built, so scroll the verbal
                  // card (best 1234) into view first.
                  final bestFinder = find.textContaining(
                    '1234',
                    skipOffstage: false,
                  );
                  for (var k = 0; k < 8 && bestFinder.evaluate().isEmpty; k++) {
                    await tester.drag(
                      find.byType(ListView),
                      const Offset(0, -300),
                    );
                    await tester.pump(const Duration(milliseconds: 300));
                  }
                  expect(bestFinder, findsOneWidget);
                },
              );
            },
          );
        }
      }
    }
  });

  group('RoomPalacePage capture', () {
    for (final size in _sizes) {
      for (final scale in _scales) {
        for (final locale in _locales) {
          testWidgets(
            'RoomPalacePage capture ${_combo(size, scale, locale, 'light')}',
            (tester) async {
              await _pumpCombo(
                tester,
                home: const RoomPalacePage(),
                size: size,
                scale: scale,
                locale: locale,
                dark: false,
                interact: (tester) async {
                  expect(find.text(tr('room_title')), findsOneWidget);
                },
              );
            },
          );
        }
      }
    }
  });

  group('SessionCoachCard done', () {
    // The real local planner caps room rows at 2 and the game/path
    // titles are fixed short strings, so 2 of the 3 titles are long
    // here (~90 chars each); the Hungarian why-lines stress row 2.
    const stationA = 'antique wooden bookshelf beside the window wall';
    const stationB = 'old brass floor lamp standing in the corner';

    Future<void> seedLongPalaces() async {
      final photo = _tinyPhoto();
      for (final id in ['room:long1', 'room:long2']) {
        await MemoryStore.upsertRoomPalace(
          RoomPalace(
            id: id,
            createdAt: DateTime.utc(2026, 11, 1),
            imageRef: photo,
            stations: const [stationA, stationB],
            items: const ['apple'],
            links: const ['first link'],
            card: FsrsCard(
              cardId: id,
              taskId: 'room_palace',
              due: DateTime.now(),
            ),
          ),
        );
      }
    }

    Future<void> runCoach(WidgetTester tester) async {
      await tester.tap(find.text(tr('coach_build_btn')));
      await tester.pump(const Duration(milliseconds: 1200));
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.text(tr('coach_start'), skipOffstage: false), findsOneWidget);
    }

    for (final size in _sizes) {
      for (final scale in _scales) {
        for (final locale in _locales) {
          testWidgets(
            'SessionCoachCard done ${_combo(size, scale, locale, 'light')}',
            (tester) async {
              await _pumpCombo(
                tester,
                home: const Scaffold(
                  body: SingleChildScrollView(child: SessionCoachCard()),
                ),
                size: size,
                scale: scale,
                locale: locale,
                dark: false,
                seed: seedLongPalaces,
                interact: runCoach,
              );
            },
          );
          testWidgets(
            'SessionCoachCard done ${_combo(size, scale, locale, 'dark')}',
            (tester) async {
              await _pumpCombo(
                tester,
                home: const Scaffold(
                  body: SingleChildScrollView(child: SessionCoachCard()),
                ),
                size: size,
                scale: scale,
                locale: locale,
                dark: true,
                seed: seedLongPalaces,
                interact: runCoach,
              );
            },
          );
        }
      }
    }
  });

  group('LearningPath Home tab', () {
    for (final size in _sizes) {
      for (final scale in _scales) {
        for (final locale in _locales) {
          testWidgets('LearningPath ${_combo(size, scale, locale, 'light')}', (
            tester,
          ) async {
            await _pumpCombo(
              tester,
              home: const LearningPathPage(),
              size: size,
              scale: scale,
              locale: locale,
              dark: false,
            );
            expect(find.byType(LearningPathPage), findsOneWidget);
          });
          testWidgets('LearningPath ${_combo(size, scale, locale, 'dark')}', (
            tester,
          ) async {
            await _pumpCombo(
              tester,
              home: const LearningPathPage(),
              size: size,
              scale: scale,
              locale: locale,
              dark: true,
            );
            expect(find.byType(LearningPathPage), findsOneWidget);
          });
        }
      }
    }
  });

  group('RoomPalacePage result', () {
    // room_palace_page_test only reaches recall, so this drives one
    // more step: a single-station palace answered correctly lands on
    // the real result step (local judging, no network).
    Future<void> seedResultPalace() async {
      await MemoryStore.upsertRoomPalace(
        RoomPalace(
          id: 'room:result1',
          createdAt: DateTime.utc(2026, 11, 1),
          imageRef: _tinyPhoto(),
          stations: const ['desk'],
          items: const ['apple'],
          links: const ['first link'],
          card: FsrsCard(
            cardId: 'room:result1',
            taskId: 'room_palace',
            due: DateTime.now(),
          ),
        ),
      );
    }

    Future<void> answerAndFinish(WidgetTester tester) async {
      await tester.enterText(find.byType(TextField), 'apple');
      await tester.pump(const Duration(milliseconds: 300));
      await tester.ensureVisible(find.text(tr('room_check_btn')));
      await tester.pump(const Duration(milliseconds: 300));
      await tester.tap(find.text(tr('room_check_btn')));
      await tester.pump(const Duration(milliseconds: 1200));
      await tester.pump(const Duration(milliseconds: 500));
      // The result step is taller than the viewport, and lazily built
      // rows below the cache extent do not exist until scrolled to.
      final lv = find.byType(ListView);
      for (var k = 0; k < 6; k++) {
        await tester.drag(lv.first, const Offset(0, -400));
        await tester.pump(const Duration(milliseconds: 300));
      }
      expect(find.text(tr('common_done'), skipOffstage: false), findsOneWidget);
    }

    for (final size in _sizes) {
      for (final scale in _scales) {
        for (final locale in _locales) {
          testWidgets(
            'RoomPalacePage result ${_combo(size, scale, locale, 'light')}',
            (tester) async {
              await _pumpCombo(
                tester,
                home: const RoomPalacePage(reviewId: 'room:result1'),
                size: size,
                scale: scale,
                locale: locale,
                dark: false,
                seed: seedResultPalace,
                interact: answerAndFinish,
              );
            },
          );
        }
      }
    }
  });
}
