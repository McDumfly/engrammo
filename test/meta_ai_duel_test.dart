import 'package:engrammo/models/battle_round.dart';
import 'package:engrammo/models/meta_task.dart';
import 'package:engrammo/services/meta_ai_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

MetaTask _task(String paradigm) {
  return MetaTask(
    prompt: 'Memorize!',
    items: const ['a', 'b'],
    question: 'What was it?',
    options: const ['a', 'b', 'c', 'd'],
    correct: 0,
    paradigm: paradigm,
    createdAt: DateTime(2026, 1, 1),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('párbaj-képigény', () {
    test('képes paradigmák: picture, pair, semantic', () {
      for (final p in [
        'picture-recall',
        'paired-associate',
        'category-exemplar',
      ]) {
        expect(battleTaskWantsImage(_task(p)), isTrue, reason: p);
      }
    });

    test('digit- és rácskörök tiszták maradnak', () {
      for (final p in [
        'backward-span',
        'iconic-probe',
        'echoic-probe',
        'pattern-span',
        'chunk-span',
        'brown-peterson',
        'unknown-thing',
      ]) {
        expect(battleTaskWantsImage(_task(p)), isFalse, reason: p);
      }
    });
  });

  group('párbaj-AI szövegek', () {
    test('hype tartalmazza az ellenfelet és a típust', () {
      final en = MetaAIService.localDuelHype('FoeBot', 'visual');
      final hu = MetaAIService.localDuelHype('FoeBot', 'vizuális', 'hu');
      expect(en, contains('FoeBot'));
      expect(en, contains('visual'));
      expect(hu, contains('FoeBot'));
      expect(hu, isNotEmpty);
    });

    test('körjegyzet találatra és mellére eltér', () {
      final good = MetaAIService.localDuelRound(true);
      final miss = MetaAIService.localDuelRound(false);
      expect(good, isNotEmpty);
      expect(miss, isNotEmpty);
      expect(good == miss, isFalse);
      expect(MetaAIService.localDuelRound(true, 'hu'), isNotEmpty);
      expect(MetaAIService.localDuelRound(false, 'hu'), isNotEmpty);
    });

    test('felderítés első párbajnál külön szöveg', () {
      final first = MetaAIService.localDuelScout(
        kindLabel: 'spatial',
        wins: 0,
        matches: 0,
      );
      final vet = MetaAIService.localDuelScout(
        kindLabel: 'spatial',
        wins: 3,
        matches: 5,
      );
      expect(first, isNotEmpty);
      expect(vet, isNotEmpty);
      expect(first == vet, isFalse);
      expect(vet, contains('3'));
      expect(
        MetaAIService.localDuelScout(
          kindLabel: 'tér',
          wins: 1,
          matches: 2,
          locale: 'hu',
        ),
        isNotEmpty,
      );
    });

    test('kérés-testek viszik a modellt, a nyelvet és a neveket', () {
      final hype = MetaAIService.duelHypeRequestBody(
        foeName: 'FoeBot',
        kindLabel: 'visual',
      );
      final hypeHu = MetaAIService.duelHypeRequestBody(
        foeName: 'FoeBot',
        kindLabel: 'vizuális',
        locale: 'hu',
      );
      expect(hype['model'], MetaAIService.taskModel);
      final hypeSys =
          (((hype['messages'] as List).first as Map)['content'] as String);
      expect(hypeSys.contains('FoeBot'), isTrue);
      expect(hypeSys.contains('English'), isTrue);
      final hypeHuSys =
          (((hypeHu['messages'] as List).first as Map)['content'] as String);
      expect(hypeHuSys.contains('Hungarian'), isTrue);

      final good = MetaAIService.duelRoundRequestBody(
        paradigm: 'picture-recall',
        correct: true,
      );
      final miss = MetaAIService.duelRoundRequestBody(
        paradigm: 'picture-recall',
        correct: false,
      );
      final goodSys =
          (((good['messages'] as List).first as Map)['content'] as String);
      final missSys =
          (((miss['messages'] as List).first as Map)['content'] as String);
      expect(goodSys.contains('picture-recall'), isTrue);
      expect(goodSys == missSys, isFalse);

      final scout = MetaAIService.duelScoutRequestBody(
        kindLabel: 'spatial',
        rating: 1200,
        wins: 3,
        matches: 5,
      );
      expect(scout['model'], MetaAIService.taskModel);
      final scoutSys =
          (((scout['messages'] as List).first as Map)['content'] as String);
      expect(scoutSys.contains('1200'), isTrue);
    });

    test('kulcs nélkül mindhárom tartalékkal tér vissza', () async {
      final hype = await MetaAIService.duelHype(
        foeName: 'FoeBot',
        kindLabel: 'visual',
      );
      expect(hype.fallback, isTrue);
      expect(hype.text, isNotEmpty);

      final round = await MetaAIService.duelRoundComment(
        paradigm: 'picture-recall',
        correct: true,
      );
      expect(round.fallback, isTrue);
      expect(round.text, isNotEmpty);

      final scout = await MetaAIService.duelScout(
        kindLabel: 'spatial',
        rating: 1200,
        wins: 0,
        matches: 0,
      );
      expect(scout.fallback, isTrue);
      expect(scout.text, isNotEmpty);

      final kinds = MetaAIService.lastCalls.map((c) => c.kind).toSet();
      expect(kinds.contains('hype'), isTrue);
      expect(kinds.contains('round'), isTrue);
      expect(kinds.contains('scout'), isTrue);
    });
  });
}
