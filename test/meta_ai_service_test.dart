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

    test('minden hívás naplózódik modellnévvel és fallback jelöléssel', () async {
      await MetaAIService.generateTask(
        const MetaTaskRequest(kind: 'verbal'),
      );
      expect(MetaAIService.lastCalls, isNotEmpty);
      final first = MetaAIService.lastCalls.first;
      expect(first.model, MetaAIService.taskModel);
      expect(first.fallback, isTrue);
    });
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
}
