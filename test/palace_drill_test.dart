import 'package:engrammo/models/active_palace.dart';
import 'package:engrammo/models/fsrs_card.dart';
import 'package:engrammo/models/meta_task.dart';
import 'package:engrammo/models/room_palace.dart' show RoomPalace;
import 'package:engrammo/models/palace_drill.dart';
import 'package:engrammo/services/meta_ai_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('localPalaceTask (loci-séta)', () {
    test('állomások rendezettek, különbözőek, a szavakkal párosak', () {
      final task = localPalaceTask(difficulty: 3, seed: 'x-r0');
      expect(task.items.length, 6);
      expect(task.stations.length, 6);
      expect(task.stations.toSet().length, 6);
      expect(task.items.toSet().length, 6);
      expect(task.options.length, 4);
      expect(task.options.toSet().length, 4);
      expect(
        task.options[task.correct],
        contains(task.items.firstWhere((w) => task.options[task.correct] == w)),
      );
    });

    test('nehézséggel nő az állomásszám (4-8)', () {
      expect(localPalaceTask(difficulty: 1, seed: 's').items.length, 4);
      expect(localPalaceTask(difficulty: 5, seed: 's').items.length, 8);
    });

    test('magyarázata loci-technikát tanít forrásmegjelöléssel', () {
      final task = localPalaceTask(difficulty: 2, seed: 's');
      expect(task.explanation, contains('Loci'));
      expect(task.explanation, contains('Maguire'));
      expect(task.explanation, contains('Dresler'));
    });

    test('ugyanaz a mag ugyanazt a sétát adja', () {
      final a = localPalaceTask(difficulty: 2, seed: '2-0-1-r0');
      final b = localPalaceTask(difficulty: 2, seed: '2-0-1-r0');
      expect(a.stations, b.stations);
      expect(a.items, b.items);
      expect(a.question, b.question);
    });
  });

  group('localPictureTask (képi felidézés)', () {
    test('4 válaszlehetőség, 1 jelenetbeli + 3 kívüli', () {
      final task = localPictureTask(difficulty: 2, seed: 'p-r0');
      expect(task.options.length, 4);
      expect(task.options.toSet().length, 4);
      final correct = task.options[task.correct];
      expect(task.items, contains(correct));
      final present = task.options.where(task.items.contains).toList();
      expect(present.length, 1);
    });

    test('magyarázata képi memóriát tanít forrásmegjelöléssel', () {
      final task = localPictureTask(difficulty: 2, seed: 'p');
      expect(task.explanation, contains('Shepard'));
      expect(task.explanation, contains('Standing'));
    });
  });

  group('stationsFromLabels (SAM-egyesítés)', () {
    test('élő címkék elöl, helyi útvonal tölti a hiányt', () {
      final out = stationsFromLabels(['desk', 'lamp'], 's', 4);
      expect(out.length, 4);
      expect(out.take(2), ['desk', 'lamp']);
      expect(out.toSet().length, 4);
    });

    test('üres/dupla címkéket dob, mindig pontosan n állomás', () {
      final out = stationsFromLabels(['', 'gate', 'gate', '  '], 's', 5);
      expect(out.length, 5);
      expect(out.first, 'gate');
      expect(out.toSet().length, 5);
      expect(stationsFromLabels(const [], 's', 6).length, 6);
    });
  });

  group('MetaTask új mezői', () {
    test('régi JSON (mezők nélkül) is beolvasható', () {
      final back = MetaTask.fromJson({
        'prompt': 'p',
        'items': ['a'],
        'question': 'q',
        'options': ['a', 'b'],
        'correct': 0,
      });
      expect(back.stations, isEmpty);
      expect(back.imageUrl, isEmpty);
    });

    test('JSON-körút megőrzi az állomásokat és a kép-URL-t', () {
      final t = localPalaceTask(
        difficulty: 1,
        seed: 's',
      ).copyWith(imageUrl: 'https://x/y.png');
      expect(MetaTask.fromJson(t.toJson()), t);
    });
  });

  group('MetaAIService térbeli/vizuális ág', () {
    test('offline térbeli/vizuális feladat loci/képi alakú', () async {
      final spatial = await MetaAIService.generateTask(
        const MetaTaskRequest(kind: 'spatial', difficulty: 2, seed: 's'),
      );
      expect(spatial.fallback, isTrue);
      expect(spatial.stations.length, spatial.items.length);
      expect(spatial.stations, isNotEmpty);
      final visual = await MetaAIService.generateTask(
        const MetaTaskRequest(kind: 'visual', difficulty: 2, seed: 's'),
      );
      expect(visual.fallback, isTrue);
      expect(visual.items, isNotEmpty);
      expect(visual.options.length, 4);
    });

    test('Spark-prompt loci/képi szerkezetet kér', () {
      final spatial = MetaAIService.taskRequestBody(
        const MetaTaskRequest(kind: 'spatial', locale: 'en'),
      );
      final messages = spatial['messages'] as List;
      final user = (messages[1] as Map)['content'] as String;
      expect(user, contains('loci-drill'));
      expect(user, contains('stations'));
      final visual = MetaAIService.taskRequestBody(
        const MetaTaskRequest(kind: 'visual', locale: 'en'),
      );
      final vMessages = visual['messages'] as List;
      expect((vMessages[1] as Map)['content'] as String, contains('picture'));
    });

    test('Spark-válasz állomáslistája beolvasható', () {
      expect(
        MetaAIService.parseTaskContent(
          '{"prompt":"Walk!","items":["apple","key"],'
          '"stations":["door","couch"],'
          '"question":"What at the door?","options":["apple","key","a","b"],'
          '"correct":0,"explanation":"Loci."}',
          const MetaTaskRequest(kind: 'spatial'),
        ),
        isNull,
      );
      final task = MetaAIService.parseTaskContent(
        '{"prompt":"Walk!","items":["apple","key","lamp","tiger"],'
        '"stations":["door","couch","shelf","window"],'
        '"question":"What at the door?",'
        '"options":["apple","key","lamp","tiger"],'
        '"correct":0,"explanation":"Loci."}',
        const MetaTaskRequest(kind: 'spatial'),
      )!;
      expect(task.stations, ['door', 'couch', 'shelf', 'window']);
      expect(task.fallback, isFalse);
      expect(task.paradigm, 'loci-drill');
    });

    test('dúsítás kulcs nélkül is teljes feladatot ad', () async {
      final base = localPalaceTask(difficulty: 2, seed: 's');
      final out = await MetaAIService.enrichSpatialTask(
        base.copyWith(stations: const []),
        difficulty: 2,
        seed: 's',
      );
      expect(out.stations.length, out.items.length);
      expect(out.stations, isNotEmpty);
      final visual = await MetaAIService.enrichVisualTask(
        localPictureTask(difficulty: 2, seed: 's'),
        seed: 's',
      );
      expect(visual.items, isNotEmpty);
    });

    test('szám-feladat a chunk-span paradigmában', () async {
      final number = await MetaAIService.generateTask(
        const MetaTaskRequest(kind: 'number', difficulty: 3, seed: 'n3'),
      );
      expect(number.items.first.length, 9);
      expect(number.options.length, 4);
      expect(number.paradigm, 'chunk-span');
      expect(number.source, isNotEmpty);
    });
  });

  group('taskOnPalace (fúrás az aktív palotán)', () {
    MetaTask task() => MetaTask(
      prompt: 'Walk your home palace — one image per station!',
      items: const ['w0', 'w1', 'w2', 'w3', 'w4', 'w5'],
      question: 'What did you place at the w2?',
      options: const ['w2', 'x', 'y', 'z'],
      correct: 0,
      paradigm: 'loci-drill',
      createdAt: DateTime.utc(2026),
    );

    const practice = ActivePalace(
      id: 'route:1',
      title: 'Old-town street',
      stations: ['garden gate', 'bus stop', 'bakery window', 'corner fountain'],
      imageRef: '',
      boxes: [],
      masks: [],
      own: false,
      sample: false,
    );

    test('vág és megtartja a jó választ', () {
      final out = taskOnPalace(task(), practice);
      expect(out.stations.length, 4);
      expect(out.items, const ['w0', 'w1', 'w2', 'w3']);
      expect(out.options[out.correct], 'w2');
      expect(out.question, contains(out.stations[2]));
    });

    test('kieső választ az utolsó állomásra mutat', () {
      final t = task().copyWith(
        options: const ['a', 'b', 'c', 'w5'],
        correct: 3,
      );
      final out = taskOnPalace(t, practice);
      expect(out.items.length, 4);
      expect(out.correct, 3);
      expect(out.options[3], 'w3');
      expect(out.question, contains(out.stations[3]));
    });

    test('saját palota: fotó, nincs samLabels', () {
      final room = RoomPalace(
        id: 'room:1',
        createdAt: DateTime.utc(2026, 11, 1, 12),
        imageRef: 'data:image/jpeg;base64,AAA',
        stations: const ['desk', 'lamp', 'sofa', 'rug'],
        card: FsrsCard(
          cardId: 'room:1',
          taskId: 'room_palace',
          due: DateTime.utc(2026),
        ),
      );
      final own = ActivePalace.fromRoom(room, 'en');
      final out = taskOnPalace(task(), own);
      expect(out.imageUrl, room.imageRef);
      expect(out.samLabels, isEmpty);
      expect(
        out.prompt,
        'Walk your room palace — one vivid image per station!',
      );
      final route = taskOnPalace(task(), practice);
      expect(route.prompt, contains('Practice palace:'));
      expect(route.imageUrl, isEmpty);
    });
  });
}
