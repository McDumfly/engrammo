import 'package:engrammo/models/fsrs_card.dart';
import 'package:engrammo/models/room_palace.dart';
import 'package:engrammo/screens/benchmark.dart' show MaskedPicture;
import 'package:engrammo/screens/room_palace_page.dart';
import 'package:engrammo/services/memory_store.dart';
import 'package:engrammo/services/meta_ai_service.dart';
import 'package:engrammo/services/room_photo.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    MetaAIService.secureStoreForTest = {};
    MetaAIService.consentForTest = null;
  });

  tearDown(() {
    MetaAIService.secureStoreForTest = null;
    MetaAIService.consentForTest = null;
  });

  testWidgets('review recall accepts the placed item', (tester) async {
    final photo = squareJpegDataUrl(
      Uint8List.fromList(img.encodePng(img.Image(width: 10, height: 10))),
    );
    await MemoryStore.upsertRoomPalace(
      RoomPalace(
        id: 'room:test',
        createdAt: DateTime.utc(2026, 11, 1),
        imageRef: photo,
        stations: const ['desk', 'lamp', 'chair'],
        items: const ['apple', 'hammer'],
        links: const ['first link', 'second link'],
        card: FsrsCard(
          cardId: 'room:test',
          taskId: 'room_palace',
          due: DateTime.now(),
        ),
      ),
    );

    await tester.pumpWidget(
      const MaterialApp(home: RoomPalacePage(reviewId: 'room:test')),
    );
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'apple');
    await tester.ensureVisible(find.text('Check'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Check'));
    await tester.pump();

    expect(find.text('Yes — apple!'), findsOneWidget);
  });

  testWidgets('sample room starts a scan with a non-empty photo', (
    tester,
  ) async {
    MetaAIService.consentForTest = true;
    tester.view.physicalSize = const Size(800, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());
    await tester.pumpWidget(const MaterialApp(home: RoomPalacePage()));
    await tester.pumpAndSettle();
    final sample = find.byKey(const ValueKey('room-try-sample'));
    expect(sample, findsOneWidget);
    await tester.tap(sample);
    await tester.runAsync(() => Future.delayed(const Duration(seconds: 5)));
    await tester.pumpAndSettle();
    // The offline round lands on the items step with placeholder spots.
    expect(find.byKey(const ValueKey('room-try-sample')), findsNothing);
    expect(find.text('What do you want to remember?'), findsOneWidget);
    expect(find.text('Sample photo'), findsOneWidget);
  });

  testWidgets('prove-it flow ends on a from-memory proof panel', (
    tester,
  ) async {
    final photo = squareJpegDataUrl(
      Uint8List.fromList(img.encodePng(img.Image(width: 10, height: 10))),
    );
    await MemoryStore.upsertRoomPalace(
      RoomPalace(
        id: 'room:prove',
        createdAt: DateTime.utc(2026, 11, 1),
        imageRef: photo,
        stations: const ['desk', 'lamp', 'chair'],
        items: const ['apple', 'hammer'],
        links: const ['first link', 'second link'],
        card: FsrsCard(
          cardId: 'room:prove',
          taskId: 'room_palace',
          due: DateTime.now(),
        ),
      ),
    );
    tester.view.physicalSize = const Size(800, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());
    await tester.pumpWidget(
      const MaterialApp(home: RoomPalacePage(reviewId: 'room:prove')),
    );
    await tester.pumpAndSettle();

    Future<void> answer(String word) async {
      await tester.enterText(find.byType(TextField), word);
      await tester.pump();
      await tester.tap(find.text('Check'));
      await tester.pumpAndSettle();
    }

    await answer('apple');
    await answer('hammer');

    // Normal result: Prove it is the one primary button.
    expect(find.text('Prove it: photo hidden'), findsOneWidget);
    await tester.tap(find.text('Prove it: photo hidden'));
    await tester.pumpAndSettle();

    // Blind recall hides the photo behind the same-size dark card.
    expect(
      find.text('Photo hidden. Walk the room in your head.'),
      findsOneWidget,
    );
    await answer('apple');
    await answer('hammer');

    // Blind result: proof panel with per-station chips, and the generic
    // big score stays hidden so the proof title is the one hero.
    expect(find.text('2/2 from memory alone'), findsOneWidget);
    expect(find.text('2/2'), findsNothing);
    expect(find.text('landmarks recalled from your own room'), findsNothing);
    expect(find.text('apple'), findsOneWidget);
    expect(find.text('hammer'), findsOneWidget);
    expect(find.text('Done'), findsOneWidget);
  });

  testWidgets('wrong answer keeps focus and selects the wrong text', (
    tester,
  ) async {
    final photo = squareJpegDataUrl(
      Uint8List.fromList(img.encodePng(img.Image(width: 10, height: 10))),
    );
    await MemoryStore.upsertRoomPalace(
      RoomPalace(
        id: 'room:wrong',
        createdAt: DateTime.utc(2026, 11, 1),
        imageRef: photo,
        stations: const ['desk', 'lamp', 'chair'],
        items: const ['apple', 'hammer'],
        links: const ['first link', 'second link'],
        card: FsrsCard(
          cardId: 'room:wrong',
          taskId: 'room_palace',
          due: DateTime.now(),
        ),
      ),
    );
    await tester.pumpWidget(
      const MaterialApp(home: RoomPalacePage(reviewId: 'room:wrong')),
    );
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'vacuole');
    await tester.pump();
    await tester.tap(find.text('Check'));
    await tester.pumpAndSettle();

    // The judged-wrong feedback shows and the whole wrong text is
    // selected, so the next keystroke replaces it.
    expect(find.textContaining('Not quite.'), findsWidgets);
    final field = tester.widget<TextField>(find.byType(TextField));
    expect(field.controller!.text, 'vacuole');
    expect(
      field.controller!.selection,
      const TextSelection(baseOffset: 0, extentOffset: 7),
    );
  });

  testWidgets('share card copies text and keeps the photo on device', (
    tester,
  ) async {
    Map<String, dynamic>? clipboard;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (call) async {
          if (call.method == 'Clipboard.setData') {
            clipboard = Map<String, dynamic>.from(call.arguments as Map);
          }
          return null;
        });
    addTearDown(
      () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, null),
    );
    final photo = squareJpegDataUrl(
      Uint8List.fromList(img.encodePng(img.Image(width: 10, height: 10))),
    );
    await MemoryStore.upsertRoomPalace(
      RoomPalace(
        id: 'room:share',
        createdAt: DateTime.utc(2026, 11, 1),
        imageRef: photo,
        stations: const ['desk', 'lamp'],
        items: const ['apple', 'hammer'],
        links: const ['first link', 'second link'],
        card: FsrsCard(
          cardId: 'room:share',
          taskId: 'room_palace',
          due: DateTime.now(),
        ),
      ),
    );
    tester.view.physicalSize = const Size(800, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());
    await tester.pumpWidget(
      const MaterialApp(home: RoomPalacePage(reviewId: 'room:share')),
    );
    await tester.pumpAndSettle();

    Future<void> answer(String word) async {
      await tester.enterText(find.byType(TextField), word);
      await tester.pump();
      await tester.tap(find.text('Check'));
      await tester.pumpAndSettle();
    }

    await answer('apple');
    await answer('hammer');

    await tester.tap(find.text('Share my result'));
    await tester.pumpAndSettle();

    // Screenshot-ready card: photo score, model badges, clipboard only.
    expect(find.text('2/2 recalled from my own room'), findsOneWidget);
    expect(find.text('Muse Spark'), findsOneWidget);
    expect(find.text('SAM 3.1'), findsOneWidget);
    expect(find.text('Muse Image'), findsOneWidget);
    expect(find.text('Engrammo'), findsOneWidget);
    expect(find.text('Your photo never leaves this device.'), findsOneWidget);
    await tester.tap(find.text('Copy text'));
    await tester.pumpAndSettle();
    expect(
      (clipboard?['text'] as String?) ?? '',
      contains('I recalled 2/2 items by walking my own room.'),
    );
    expect(find.text('Copied'), findsOneWidget);
  });

  testWidgets('baseline probe compares before and after on the result', (
    tester,
  ) async {
    MetaAIService.consentForTest = true;
    tester.view.physicalSize = const Size(800, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());
    await tester.pumpWidget(const MaterialApp(home: RoomPalacePage()));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('room-try-sample')));
    await tester.runAsync(() => Future.delayed(const Duration(seconds: 5)));
    await tester.pumpAndSettle();

    // Offline scan lands on the items step with placeholder spots.
    expect(find.text('What do you want to remember?'), findsOneWidget);
    await tester.enterText(find.byType(TextField), 'apple\nhammer\nnail');
    await tester.pumpAndSettle();

    final baselineBtn = find.text('First, test me without the palace');
    expect(baselineBtn, findsOneWidget);
    await tester.tap(baselineBtn);
    await tester.pumpAndSettle();

    // Tests jump straight to the recall phase.
    expect(find.text('Type every item you still remember'), findsOneWidget);
    await tester.enterText(find.byType(TextField), 'apple\nhammer');
    await tester.pump();
    await tester.tap(find.text('Check'));
    await tester.pumpAndSettle();

    // The normal build continued with the same items: encode step.
    expect(find.text('Start recall'), findsOneWidget);
    await tester.tap(find.text('Start recall'));
    await tester.pumpAndSettle();

    Future<void> answer(String word) async {
      await tester.enterText(find.byType(TextField), word);
      await tester.pump();
      await tester.tap(find.text('Check'));
      await tester.pumpAndSettle();
    }

    await answer('apple');
    await answer('hammer');
    await answer('nail');

    // Result shows the before → after proof (2/3 without, 3/3 with).
    expect(
      find.byWidgetPredicate(
        (w) =>
            w is Text &&
            (w.data ?? w.textSpan?.toPlainText() ?? '').contains(
              'Without the palace 2/3 → with it 3/3',
            ),
      ),
      findsOneWidget,
    );
  });

  testWidgets('tour walks the palace and ends in recall', (tester) async {
    MetaAIService.consentForTest = true;
    tester.view.physicalSize = const Size(800, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());
    await tester.pumpWidget(const MaterialApp(home: RoomPalacePage()));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('room-try-sample')));
    await tester.runAsync(() => Future.delayed(const Duration(seconds: 5)));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'apple\nhammer\nnail');
    await tester.pumpAndSettle();
    await tester.tap(find.text('First, test me without the palace'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'apple\nhammer');
    await tester.pump();
    await tester.tap(find.text('Check'));
    await tester.pumpAndSettle();

    // Encode step offers the cinematic tour.
    expect(find.text('Walk my palace'), findsOneWidget);
    await tester.tap(find.text('Walk my palace'));
    await tester.pumpAndSettle();

    // First station pill, then tap through to the last one.
    expect(find.text('1 · spot 1 → apple'), findsOneWidget);
    await tester.tap(find.text('1 · spot 1 → apple'));
    await tester.pumpAndSettle();
    expect(find.text('2 · spot 2 → hammer'), findsOneWidget);
    await tester.tap(find.text('2 · spot 2 → hammer'));
    await tester.pumpAndSettle();
    expect(find.text('Now recall it'), findsOneWidget);
    await tester.tap(find.text('Now recall it'));
    await tester.pumpAndSettle();

    // The tour pops back into the recall step.
    expect(find.text('Start recall'), findsNothing);
    expect(find.text('Check'), findsOneWidget);
  });

  testWidgets(
    'MaskedPicture with no objects shows the photo without throwing',
    (tester) async {
      final photo = squareJpegDataUrl(
        Uint8List.fromList(img.encodePng(img.Image(width: 10, height: 10))),
      );
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MaskedPicture(
              imageUrl: photo,
              scene: '',
              objects: const [],
              boxes: const [],
              masks: const [],
              revealed: const {},
              masked: true,
            ),
          ),
        ),
      );
      await tester.pump();
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('finishing a review appends one palace run to the strip', (
    tester,
  ) async {
    final photo = squareJpegDataUrl(
      Uint8List.fromList(img.encodePng(img.Image(width: 10, height: 10))),
    );
    await MemoryStore.upsertRoomPalace(
      RoomPalace(
        id: 'room:retention',
        createdAt: DateTime.now().subtract(const Duration(days: 2)),
        imageRef: photo,
        stations: const ['desk', 'lamp', 'chair'],
        items: const ['apple', 'hammer'],
        links: const ['first link', 'second link'],
        card: FsrsCard(
          cardId: 'room:retention',
          taskId: 'room_palace',
          due: DateTime.now(),
        ),
      ),
    );
    tester.view.physicalSize = const Size(800, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());
    await tester.pumpWidget(
      const MaterialApp(home: RoomPalacePage(reviewId: 'room:retention')),
    );
    await tester.pumpAndSettle();

    Future<void> answer(String word) async {
      await tester.enterText(find.byType(TextField), word);
      await tester.pump();
      await tester.tap(find.text('Check'));
      await tester.pumpAndSettle();
    }

    await answer('apple');
    await answer('hammer');

    // One finish appends exactly one palace run with the score.
    final stored = await MemoryStore.loadRoomPalaces();
    final palace = stored.firstWhere((p) => p.id == 'room:retention');
    expect(palace.runs, hasLength(1));
    expect(palace.runs.single.kind, 'palace');
    expect(palace.runs.single.correct, 2);
    expect(palace.runs.single.total, 2);

    // The strip shows the honest caption, the next review is in the
    // future so the early link appears, and the pending node stays a
    // question mark, never a guessed score.
    expect(
      find.text('Tracked on this device. One learner, not a study.'),
      findsOneWidget,
    );
    expect(find.text('Review now (early)'), findsOneWidget);
    expect(find.text('?'), findsOneWidget);
  });

  testWidgets('a blind finish keeps the card due and records a blind run', (
    tester,
  ) async {
    final photo = squareJpegDataUrl(
      Uint8List.fromList(img.encodePng(img.Image(width: 10, height: 10))),
    );
    final due = DateTime.now();
    await MemoryStore.upsertRoomPalace(
      RoomPalace(
        id: 'room:blind-due',
        createdAt: DateTime.utc(2026, 11, 1),
        imageRef: photo,
        stations: const ['desk', 'lamp', 'chair'],
        items: const ['apple', 'hammer'],
        links: const ['first link', 'second link'],
        card: FsrsCard(
          cardId: 'room:blind-due',
          taskId: 'room_palace',
          due: due,
        ),
      ),
    );
    tester.view.physicalSize = const Size(800, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());
    await tester.pumpWidget(
      const MaterialApp(home: RoomPalacePage(reviewId: 'room:blind-due')),
    );
    await tester.pumpAndSettle();

    Future<void> answer(String word) async {
      await tester.enterText(find.byType(TextField), word);
      await tester.pump();
      await tester.tap(find.text('Check'));
      await tester.pumpAndSettle();
    }

    await answer('apple');
    await answer('hammer');

    // The first (sighted) finish reschedules and appends a palace run.
    final afterFirst = await MemoryStore.loadRoomPalaces();
    final firstDue = afterFirst
        .firstWhere((p) => p.id == 'room:blind-due')
        .card
        .due;

    await tester.tap(find.text('Prove it: photo hidden'));
    await tester.pumpAndSettle();
    await answer('apple');
    await answer('hammer');

    // The blind run is tracked, but the FSRS card never moves on it.
    final stored = await MemoryStore.loadRoomPalaces();
    final palace = stored.firstWhere((p) => p.id == 'room:blind-due');
    expect(palace.card.due, firstDue);
    expect(palace.runs, hasLength(2));
    expect(palace.runs.last.kind, 'blind');
    expect(palace.runs.last.correct, 2);
  });

  testWidgets('revealed chip on a 40px cover still renders the full label', (
    tester,
  ) async {
    final photo = squareJpegDataUrl(
      Uint8List.fromList(img.encodePng(img.Image(width: 10, height: 10))),
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: MaskedPicture(
            imageUrl: photo,
            scene: '',
            objects: const ['mitochondria'],
            // ~40 px wide on the 380 pt test picture.
            boxes: const [
              [0.0, 0.4, 0.105, 0.2],
            ],
            masks: const [],
            revealed: const {0},
            masked: true,
          ),
        ),
      ),
    );
    await tester.pump();
    expect(tester.takeException(), isNull);
    expect(find.text('mitochondria'), findsOneWidget);
    expect(tester.getSize(find.text('mitochondria')).width, greaterThan(60));
  });
}
