import 'package:engrammo/models/palace_drill.dart'
    show localPictureTask;
import 'package:engrammo/screens/benchmark.dart';
import 'package:engrammo/screens/lesson_player.dart'
    show lessonRoundKindWantsImage;
import 'package:engrammo/services/meta_ai_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('AI-összegzés és gyakorlótipp', () {
    test('helyi összegzés az aránytól függ', () {
      final good = MetaAIService.localSessionRecap(
        correct: 4,
        total: 5,
        trackLabel: 'spatial',
      );
      final mid = MetaAIService.localSessionRecap(
        correct: 3,
        total: 5,
        trackLabel: 'spatial',
      );
      final low = MetaAIService.localSessionRecap(
        correct: 1,
        total: 5,
        trackLabel: 'spatial',
      );
      expect(good, isNotEmpty);
      expect(mid, isNotEmpty);
      expect(low, isNotEmpty);
      expect(good == mid && mid == low, isFalse);
      expect(
        MetaAIService.localSessionRecap(
          correct: 2,
          total: 4,
          trackLabel: 'tér',
          locale: 'hu',
        ),
        isNotEmpty,
      );
    });

    test('összegzés kulcs nélkül tartalék szöveggel', () async {
      final answer = await MetaAIService.sessionRecap(
        correct: 2,
        total: 3,
        trackLabel: 'visual',
      );
      expect(answer.fallback, isTrue);
      expect(answer.text, isNotEmpty);
      expect(MetaAIService.lastCalls.first.kind, 'recap');
    });

    test('összegzés-kérés teste a nyelvet is viszi', () {
      final en = MetaAIService.recapRequestBody(
        correct: 1,
        total: 2,
        trackLabel: 'duel',
      );
      final hu = MetaAIService.recapRequestBody(
        correct: 1,
        total: 2,
        trackLabel: 'párbaj',
        locale: 'hu',
      );
      expect(en['model'], MetaAIService.taskModel);
      final enSys = (en['messages'] as List).first as Map;
      final huSys = (hu['messages'] as List).first as Map;
      expect((enSys['content'] as String).contains('English'), isTrue);
      expect((huSys['content'] as String).contains('Hungarian'), isTrue);
    });

    test('gyakorlótipp minden játékhoz és ismeretlenhez is', () async {
      for (final game in [
        'sequence',
        'number',
        'verbal',
        'visual',
        'order',
        'spatial',
      ]) {
        final tip = await MetaAIService.practiceTip(gameId: game, level: 3);
        expect(tip.fallback, isTrue);
        expect(tip.text, isNotEmpty);
      }
      final unknown = await MetaAIService.practiceTip(
        gameId: 'nope',
        level: 2,
      );
      expect(unknown.text, contains('2'));
      expect(
        MetaAIService.localPracticeTip('visual', 4, 'hu'),
        isNotEmpty,
      );
      expect(MetaAIService.lastCalls.first.kind, startsWith('tip:'));
    });

    test('tippkérés teste játékot és szintet visz', () {
      final body = MetaAIService.practiceTipRequestBody(
        gameId: 'spatial',
        level: 5,
        locale: 'hu',
      );
      expect(body['model'], MetaAIService.taskModel);
      final sys = (body['messages'] as List).first as Map;
      final content = sys['content'] as String;
      expect(content.contains('spatial'), isTrue);
      expect(content.contains('5'), isTrue);
      expect(content.contains('Hungarian'), isTrue);
    });
  });

  group('Gyakorló AI-körök tartaléka', () {
    test('képes kör kulcs nélkül helyi képi feladat', () async {
      final task = await BenchmarkMeta.pictureRound(seed: 't1', difficulty: 2);
      expect(task.fallback, isTrue);
      expect(task.imageUrl, isEmpty);
      expect(task.items, isNotEmpty);
      expect(task.options.length, 4);
      expect(task.correct >= 0 && task.correct < 4, isTrue);
    });

    test('térbeli kör kulcs nélkül párosított állomásokkal', () async {
      final task = await BenchmarkMeta.spatialRound(seed: 't2', stations: 5);
      expect(task.items, isNotEmpty);
      expect(task.stations.length, task.items.length);
      expect(task.options.length, 4);
      expect(task.imageUrl, isEmpty);
    });

    test('vizuális dúsítás kulcs nélkül nem tesz SAM-címkét', () async {
      final out = await MetaAIService.enrichVisualTask(
        localPictureTask(difficulty: 2, seed: 't3'),
        seed: 't3',
      );
      expect(out.imageUrl, isEmpty);
      expect(out.stations, isEmpty);
      expect(out.items, isNotEmpty);
    });
  });

  group('Leckekör-képkapu', () {
    test('szám- és mintakörök nem kérnek képet', () {
      expect(lessonRoundKindWantsImage('number'), isFalse);
      expect(lessonRoundKindWantsImage('sequence'), isFalse);
      expect(lessonRoundKindWantsImage('pattern'), isFalse);
      expect(lessonRoundKindWantsImage('spatial'), isTrue);
      expect(lessonRoundKindWantsImage('visual'), isTrue);
      expect(lessonRoundKindWantsImage('verbal'), isTrue);
      expect(lessonRoundKindWantsImage('episodic'), isTrue);
      expect(lessonRoundKindWantsImage('semantic'), isTrue);
    });
  });
}
