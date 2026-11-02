import 'package:engrammo/models/meta_image.dart';
import 'package:engrammo/models/meta_segment.dart';
import 'package:engrammo/models/meta_task.dart';
import 'package:engrammo/screens/benchmark.dart';
import 'package:engrammo/services/memory_store.dart';
import 'package:engrammo/services/meta_ai_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('MetaAIService offline tartalék', () {
    test('kulcs nélkül helyi feladat fallback jelöléssel', () async {
      expect(MetaAIService.configured, isFalse);
      final task = await MetaAIService.generateTask(
        const MetaTaskRequest(kind: 'number', difficulty: 3),
      );
      expect(task.fallback, isTrue);
      expect(task.items, isNotEmpty);
      expect(task.options, isNotEmpty);
    });

    test('kulcs nélkül a kép és a szegmentálás is tartalék', () async {
      final img = await MetaAIService.generateImage(
        const MetaImageRequest(prompt: 'palota kapu'),
      );
      expect(img.fallback, isTrue);
      expect(img.cacheKey, isNotEmpty);
      final seg = await MetaAIService.segment(
        const MetaSegmentRequest(imageRef: 'palace-1'),
      );
      expect(seg.fallback, isTrue);
      expect(seg.masks, isEmpty);
    });

    test(
      'minden hívás naplózódik modellnévvel és fallback jelöléssel',
      () async {
        await MetaAIService.generateTask(const MetaTaskRequest(kind: 'verbal'));
        expect(MetaAIService.lastCalls, isNotEmpty);
        final first = MetaAIService.lastCalls.first;
        expect(first.model, MetaAIService.taskModel);
        expect(first.fallback, isTrue);
      },
    );
  });

  group('Benchmark helyi tartalékok', () {
    test('szám-ingert adott hosszban ad', () {
      final n = NumberGamePage.make(4);
      expect(n.length, 4);
      expect(int.tryParse(n), isNotNull);
    });

    test('szó-ingert a készletből jön', () {
      expect(VerbalGamePage.pickFresh(), isNotEmpty);
    });

    test('szekvencia hossza pontos', () {
      expect(SequenceGamePage.make(5).length, 5);
    });

    test('vizuális minta mérete pontos', () {
      final p = VisualGamePage.makePattern(9, 3);
      expect(p.length, 3);
      expect(p.every((e) => e >= 0 && e < 9), isTrue);
    });
  });

  group('MemoryStore FSRS + meta-gyorsítótár', () {
    test('üres tárolóból üres map jön', () async {
      expect(await MemoryStore.loadFsrsCards(), isEmpty);
      expect(await MemoryStore.loadMetaCache(), isEmpty);
    });

    test('mentés és visszatöltés körbeér', () async {
      await MemoryStore.saveFsrsCards({'c1': '{"cardId":"c1"}'});
      await MemoryStore.saveMetaCache({'k1': 'v1'});
      expect((await MemoryStore.loadFsrsCards())['c1'], '{"cardId":"c1"}');
      expect((await MemoryStore.loadMetaCache())['k1'], 'v1');
    });
  });

  group('word batches for the verbal game', () {
    test('request body pins the count and the avoid list', () {
      final body = MetaAIService.wordBatchRequestBody(
        count: 12,
        avoid: const ['apple', 'bridge'],
        locale: 'en',
      );
      expect(body['model'], MetaAIService.taskModel);
      final system = (body['messages'] as List).first as Map;
      expect(system['content'], contains('exactly 12'));
      expect(system['content'], contains('apple, bridge'));
    });

    test('parses object, bare array and fenced batches', () {
      expect(
        MetaAIService.parseWordBatch('{"words": ["apple", "bridge"]}'),
        ['apple', 'bridge'],
      );
      expect(MetaAIService.parseWordBatch('["lamp"]'), ['lamp']);
      expect(
        MetaAIService.parseWordBatch('```json\n{"words": ["owl"]}\n```'),
        ['owl'],
      );
    });

    test('parse drops multi-word, short and duplicated entries', () {
      expect(
        MetaAIService.parseWordBatch(
          '{"words": ["a", "two words", "Apple", "apple", "ok-word"]}',
        ),
        ['Apple', 'ok-word'],
      );
      expect(MetaAIService.parseWordBatch('not json'), isEmpty);
      expect(MetaAIService.parseWordBatch('{"words": []}'), isEmpty);
    });

    test('offline batch returns unseen local nouns', () async {
      final answer = await MetaAIService.fetchWordBatch(
        count: 5,
        avoid: const ['apple'],
        locale: 'en',
      );
      expect(answer.fallback, isTrue);
      expect(answer.words.length, 5);
      expect(answer.words, isNot(contains('apple')));
      expect(answer.words.toSet().length, 5);
    });

    test('seed folds digits deterministically', () {
      expect(
        BenchmarkMeta.seedFromDigits(const [1, 2, 3]),
        BenchmarkMeta.seedFromDigits(const [1, 2, 3]),
      );
      expect(
        BenchmarkMeta.seedFromDigits(const [1, 2, 3]),
        isNot(BenchmarkMeta.seedFromDigits(const [3, 2, 1])),
      );
    });
  });

  group('end-of-run verdict', () {
    test('local verdict tiers follow score vs best', () {
      expect(
        MetaAIService.localGameRecap(
          gameId: 'verbal',
          score: 12,
          best: 12,
          locale: 'en',
        ),
        contains('new best'),
      );
      expect(
        MetaAIService.localGameRecap(
          gameId: 'verbal',
          score: 8,
          best: 12,
          locale: 'en',
        ),
        contains('best 12'),
      );
      expect(
        MetaAIService.localGameRecap(
          gameId: 'verbal',
          score: 0,
          best: 12,
          locale: 'en',
        ),
        startsWith('0 on verbal'),
      );
    });

    test('offline verdict never throws and stays non-empty', () async {
      final answer = await MetaAIService.gameRecap(
        gameId: 'spatial',
        score: 4,
        best: 6,
        locale: 'en',
      );
      expect(answer.fallback, isTrue);
      expect(answer.text, isNotEmpty);
    });

    test('request body names the game and the score', () {
      final body = MetaAIService.gameRecapRequestBody(
        gameId: 'order',
        score: 5,
        best: 7,
      );
      expect(body['model'], MetaAIService.taskModel);
      final user = (body['messages'] as List).last as Map;
      expect(user['content'], contains('"order"'));
      expect(user['content'], contains('5 (best 7)'));
    });
  });

  group('wonder route preview', () {
    test('request body pins the route and the station count', () {
      final body = MetaAIService.wonderPreviewRequestBody(
        route: 'home',
        stations: const ['door', 'hall', 'kitchen'],
        locale: 'en',
      );
      expect(body['model'], MetaAIService.wonderModel);
      final system = (body['messages'] as List).first as Map;
      expect(system['content'], contains('"home"'));
      expect(system['content'], contains('exactly 3'));
      expect(system['content'], contains('door, hall, kitchen'));
    });

    test('parses object, bare array and fenced previews', () {
      expect(
        MetaAIService.parseWonderPreview('{"viewpoints": ["a", "b"]}'),
        ['a', 'b'],
      );
      expect(MetaAIService.parseWonderPreview('["a"]'), ['a']);
      expect(
        MetaAIService.parseWonderPreview('```json\n{"viewpoints": ["a"]}\n```'),
        ['a'],
      );
      expect(MetaAIService.parseWonderPreview('not json'), isEmpty);
      expect(
        MetaAIService.parseWonderPreview('{"viewpoints": ["", "  "]}'),
        isEmpty,
      );
    });

    test('offline preview covers every station locally', () async {
      final answer = await MetaAIService.wonderRoutePreview(
        route: 'home',
        stations: const ['door', 'hall'],
        locale: 'en',
      );
      expect(answer.fallback, isTrue);
      expect(answer.viewpoints.length, 2);
      expect(answer.viewpoints[0], contains('door'));
      expect(answer.viewpoints[1], contains('hall'));
    });
  });

  group('glimmer instant take', () {
    test('request body pins the glimmer model and one line', () {
      final body = MetaAIService.glimmerTakeRequestBody(
        gameId: 'verbal',
        score: 9,
        best: 12,
      );
      expect(body['model'], MetaAIService.glimmerModel);
      expect(
        body['max_completion_tokens'],
        MetaAIService.glimmerMaxCompletionTokens,
      );
      final system = (body['messages'] as List).first as Map;
      expect(system['content'], contains('15 words'));
    });

    test('local take tiers follow score vs best', () {
      expect(
        MetaAIService.localGlimmerTake(score: 12, best: 12, locale: 'en'),
        contains('12 — new best'),
      );
      expect(
        MetaAIService.localGlimmerTake(score: 8, best: 12, locale: 'en'),
        contains('8 — one careful replay'),
      );
      expect(
        MetaAIService.localGlimmerTake(score: 0, best: 12, locale: 'en'),
        contains('0 — slow start'),
      );
    });

    test('offline take never throws and stays non-empty', () async {
      final answer = await MetaAIService.glimmerTake(
        gameId: 'order',
        score: 3,
        best: 5,
        locale: 'en',
      );
      expect(answer.fallback, isTrue);
      expect(answer.text, isNotEmpty);
    });
  });

  group('spark open tips', () {
    test('request body uses the open model for the same tip', () {
      final body = MetaAIService.openTipRequestBody(
        gameId: 'spatial',
        level: 4,
      );
      expect(body['model'], MetaAIService.sparkOpenModel);
      final user = (body['messages'] as List).last as Map;
      expect(user['content'], contains('"spatial"'));
      expect(user['content'], contains('level 4'));
    });

    test('offline open tip matches the built-in tip', () async {
      final answer = await MetaAIService.openPracticeTip(
        gameId: 'verbal',
        level: 7,
        locale: 'en',
      );
      expect(answer.fallback, isTrue);
      expect(
        answer.text,
        MetaAIService.localPracticeTip('verbal', 7, 'en'),
      );
    });
  });
}
