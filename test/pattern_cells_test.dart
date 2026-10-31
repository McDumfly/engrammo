import 'package:engrammo/models/palace_drill.dart' show localPalaceTask;
import 'package:engrammo/screens/benchmark.dart';
import 'package:engrammo/services/meta_ai_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('Spark mintaleosztás (pattern-span)', () {
    test('kérés-teste a pontos méretet és darabszámot viszi', () {
      final body = MetaAIService.patternRequestBody(size: 16, count: 7);
      expect(body['model'], MetaAIService.taskModel);
      expect(body['temperature'], 0.2);
      final messages = body['messages'] as List;
      final user = (messages.last as Map)['content'] as String;
      expect(user, contains('16'));
      expect(user, contains('exactly 7'));
      expect(user, contains('0..15'));
    });

    test('méret csak 9 vagy 16 lehet', () {
      final body = MetaAIService.patternRequestBody(size: 25, count: 3);
      final messages = body['messages'] as List;
      final user = (messages.last as Map)['content'] as String;
      expect(user, contains('0..8'));
    });

    test('érvényes JSON-ból pontos halmaz', () {
      final cells = MetaAIService.parsePatternCells(
        '{"cells":[0, 4, 8]}',
        size: 9,
        count: 3,
      );
      expect(cells, {0, 4, 8});
    });

    test('kódkeretes válasz is jó', () {
      final cells = MetaAIService.parsePatternCells(
        '```json\n{"cells":[1, 5]}\n```',
        size: 9,
        count: 2,
      );
      expect(cells, {1, 5});
    });

    test('hibás leosztás: nincs csendes javítás', () {
      // Rossz darabszám.
      expect(
        MetaAIService.parsePatternCells('{"cells":[0, 4]}', size: 9, count: 3),
        isNull,
      );
      // Duplikátum.
      expect(
        MetaAIService.parsePatternCells(
          '{"cells":[0, 4, 4]}',
          size: 9,
          count: 3,
        ),
        isNull,
      );
      // Tartományon kívül (9-es rácson nincs 12).
      expect(
        MetaAIService.parsePatternCells(
          '{"cells":[0, 4, 12]}',
          size: 9,
          count: 3,
        ),
        isNull,
      );
      // Rossz JSON.
      expect(
        MetaAIService.parsePatternCells('nem json', size: 9, count: 3),
        isNull,
      );
      // Hiányzó kulcs.
      expect(
        MetaAIService.parsePatternCells('{"nope":[]}', size: 9, count: 3),
        isNull,
      );
    });

    test('helyi leosztás magozottan determinisztikus', () {
      final a = MetaAIService.localPatternCells(
        size: 16,
        count: 7,
        seed: 'bench:visual:5',
      );
      final b = MetaAIService.localPatternCells(
        size: 16,
        count: 7,
        seed: 'bench:visual:5',
      );
      expect(a, equals(b));
      expect(a.length, 7);
      expect(a.every((c) => c >= 0 && c < 16), isTrue);
    });

    test('kulcs nélkül helyi leosztás live=false jelöléssel', () async {
      final res = await MetaAIService.generatePatternCells(size: 16, count: 9);
      expect(res.live, isFalse);
      expect(res.cells.length, 9);
      expect(res.cells.every((c) => c >= 0 && c < 16), isTrue);
      expect(MetaAIService.lastCalls.first.kind, 'pattern');
      expect(MetaAIService.lastCalls.first.fallback, isTrue);
    });
  });

  group('BenchmarkMeta őszinte rekordok', () {
    test('visualPattern offline is pontos darabszámot ad', () async {
      for (final size in [9, 16]) {
        final count = size == 9 ? 5 : 12;
        final res = await BenchmarkMeta.visualPattern(size, count);
        expect(res.live, isFalse);
        expect(res.cells.length, count);
        expect(res.cells.every((c) => c >= 0 && c < size), isTrue);
      }
    });

    test('szám- és sorozatinger offline live=false', () async {
      final n = await BenchmarkMeta.numberStimulus(5);
      expect(n.live, isFalse);
      expect(n.text, isNotEmpty);
      final s = await BenchmarkMeta.sequenceStimulus(4);
      expect(s.live, isFalse);
      expect(s.digits, isNotEmpty);
      final w = await BenchmarkMeta.wordBatch(count: 6);
      expect(w.live, isFalse);
      final v = await BenchmarkMeta.wonderPreview(
        route: 'otthon',
        stations: ['a', 'b', 'c'],
      );
      expect(v.live, isFalse);
    });

    test('képes kör offline: nincs kép, van feladat', () async {
      final task = await BenchmarkMeta.pictureRound(
        seed: 'bench:visual:test',
        difficulty: 2,
      );
      expect(task.imageUrl, isEmpty);
      expect(task.items, isNotEmpty);
      expect(task.options, hasLength(4));
    });

    test('térbeli kör minden szinten pontos állomásszámot ad', () async {
      for (final stations in [3, 4, 8, 9, 10]) {
        final task = await BenchmarkMeta.spatialRound(
          seed: 'bench:spatial:$stations:test',
          stations: stations,
        );
        expect(task.items.length, stations, reason: 'stations=$stations');
        expect(task.stations.length, stations, reason: 'stations=$stations');
        expect(task.options, hasLength(4));
      }
    });
  });

  group('Palotafeladat darabszám-felülírás', () {
    test('count-tal pontos hossz készül', () {
      final three = localPalaceTask(difficulty: 1, seed: 's', count: 3);
      expect(three.items.length, 3);
      expect(three.stations.length, 3);
      expect(three.options, hasLength(4));
      final ten = localPalaceTask(difficulty: 5, seed: 's', count: 10);
      expect(ten.items.length, 10);
      expect(ten.stations.length, 10);
      expect(ten.options, hasLength(4));
    });

    test('count nélkül a régi 4-8-as ablak marad', () {
      expect(localPalaceTask(difficulty: 1, seed: 's').items.length, 4);
      expect(localPalaceTask(difficulty: 5, seed: 's').items.length, 8);
    });
  });
}
