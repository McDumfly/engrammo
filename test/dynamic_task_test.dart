import 'package:engrammo/models/dynamic_task.dart';
import 'package:engrammo/services/meta_ai_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  const req = DynamicTaskRequest(
    targetId: 'phone-numbers',
    userMaterial: '06301234567',
    seed: 't1',
  );

  DynamicTask validTask() => localDynamicTask(req);

  group('dynamic task schema', () {
    test('a helyi építő minden célra érvényes feladatot ad', () {
      for (final target in [
        'exam-facts',
        'names',
        'faces',
        'numbers-codes',
        'years-dates',
        'birthdays',
        'deadlines',
        'todos-errands',
        'poems-verses',
        'phone-numbers',
        'foreign-words',
        'whole-day',
      ]) {
        final r = DynamicTaskRequest(targetId: target, seed: 's');
        final t = localDynamicTask(r);
        expect(
          validateDynamicTask(r, t),
          isEmpty,
          reason: 'local $target must be valid',
        );
        expect(t.fallback, isTrue);
        expect(t.blocks.first.type, DynamicBlockType.info);
      }
    });

    test('saját anyaggal felidéző blokk is épül', () {
      final t = validTask();
      expect(t.blocks.length, greaterThanOrEqualTo(3));
      final recall = t.blocks[1];
      expect(recall.type, DynamicBlockType.phone);
      expect(recall.answer, '06301234567');
    });

    test('üres anyaggal önellenőrző íróblokk épül', () {
      const r = DynamicTaskRequest(targetId: 'names');
      final t = localDynamicTask(r);
      expect(validateDynamicTask(r, t), isEmpty);
      final write = t.blocks[1];
      expect(write.type, DynamicBlockType.text);
      expect(write.answer, isEmpty);
    });

    test('sémasértések listája pontos', () {
      final base = validTask();
      expect(
        validateDynamicTask(req, base.copyWith(title: '  ')),
        contains('empty title'),
      );
      expect(
        validateDynamicTask(
          req,
          base.copyWith(
            blocks: [for (var i = 0; i < 6; i++) base.blocks.first],
          ),
        ),
        contains('at most 5 blocks'),
      );
      expect(
        validateDynamicTask(req, base.copyWith(targetId: 'names')),
        contains('target mismatch'),
      );
      expect(
        validateDynamicTask(
          req,
          base.copyWith(blocks: [...base.blocks.reversed]),
        ),
        contains('first block must teach (info)'),
      );
      expect(
        validateDynamicTask(
          req,
          base.copyWith(blocks: [base.blocks.first]),
        ),
        contains('need at least one answerable block'),
      );
    });

    test('választó- és sorrendi blokkok szabályai', () {
      DynamicTask withBlocks(List<DynamicBlock> blocks) => DynamicTask(
        id: 'x',
        title: 't',
        instructions: 'i',
        targetId: req.targetId,
        blocks: blocks,
        createdAt: DateTime(2026, 1, 1),
      );
      const info = DynamicBlock(
        type: DynamicBlockType.info,
        id: 'b0',
        label: 'strategy',
      );
      final goodChoice = withBlocks([
        info,
        const DynamicBlock(
          type: DynamicBlockType.choice,
          id: 'b1',
          label: 'q?',
          options: ['a', 'b', 'c', 'd'],
          answer: '2',
        ),
      ]);
      expect(validateDynamicTask(req, goodChoice), isEmpty);
      final badChoice = withBlocks([
        info,
        const DynamicBlock(
          type: DynamicBlockType.choice,
          id: 'b1',
          label: 'q?',
          options: ['a', 'b', 'c'],
          answer: '0',
        ),
      ]);
      expect(
        validateDynamicTask(req, badChoice),
        contains('choice b1 needs 4 options'),
      );
      final badIndex = withBlocks([
        info,
        const DynamicBlock(
          type: DynamicBlockType.choice,
          id: 'b1',
          label: 'q?',
          options: ['a', 'b', 'c', 'd'],
          answer: '9',
        ),
      ]);
      expect(
        validateDynamicTask(req, badIndex),
        contains('choice b1 answer must be 0-3'),
      );
      final goodOrder = withBlocks([
        info,
        const DynamicBlock(
          type: DynamicBlockType.order,
          id: 'b1',
          label: 'tap in order',
          options: ['x', 'y', 'z'],
          answer: '0,1,2',
        ),
      ]);
      expect(validateDynamicTask(req, goodOrder), isEmpty);
      final badOrder = withBlocks([
        info,
        const DynamicBlock(
          type: DynamicBlockType.order,
          id: 'b1',
          label: 'tap in order',
          options: ['x', 'y', 'z'],
          answer: '0,2,1',
        ),
      ]);
      expect(
        validateDynamicTask(req, badOrder),
        contains('order b1 answer must list indices in order'),
      );
    });

    test('JSON körbeér', () {
      final t = validTask();
      final back = DynamicTask.fromJson(t.toJson());
      expect(back, t);
      expect(back.blocks, t.blocks);
    });
  });

  group('dynamic text scoring', () {
    test('telefonszám: formázás nem számít', () {
      expect(dynamicTextCorrect('06301234567', '06 30 123 4567'), isTrue);
      expect(dynamicTextCorrect('06301234567', '+36 30 123 4567'), isFalse);
      expect(dynamicTextCorrect('06301234567', ''), isFalse);
    });

    test('szöveg: ékezet és kisbetű nem számít', () {
      expect(dynamicTextCorrect('Baker', 'baker'), isTrue);
      expect(dynamicTextCorrect('Baker', 'Miller'), isFalse);
    });

    test('üres kulcs önellenőrző (a nézet kezeli)', () {
      expect(dynamicTextCorrect('', 'anything'), isFalse);
    });
  });

  group('dynamic task AI parsing', () {
    test('érvényes AI-válasz átmegy, a bélyeget a kód adja', () {
      final task = MetaAIService.parseDynamicTaskContent(
        '{"title":"My numbers","instructions":"Do this.","blocks":['
        '{"type":"info","id":"b0","label":"Chunk in threes."},'
        '{"type":"choice","id":"b1","label":"Which chunk?","options":'
        '["491","625","830","112"],"answer":"0"}]}',
        req,
      );
      expect(task, isNotNull);
      expect(task!.targetId, 'phone-numbers');
      expect(task.model, MetaAIService.taskModel);
      expect(task.fallback, isFalse);
      expect(validateDynamicTask(req, task), isEmpty);
    });

    test('sémasértő AI-válasz elbukik (nincs csendes javítás)', () {
      final task = MetaAIService.parseDynamicTaskContent(
        '{"title":"t","instructions":"i","blocks":['
        '{"type":"choice","id":"b0","label":"q?","options":'
        '["a","b","c"],"answer":"0"}]}',
        req,
      );
      expect(task, isNull);
      expect(MetaAIService.parseDynamicTaskContent('not json', req), isNull);
    });

    test('kulcs nélkül a helyi építő ad feladatot', () async {
      final task = await MetaAIService.buildDynamicTask(req);
      expect(task.fallback, isTrue);
      expect(validateDynamicTask(req, task), isEmpty);
      expect(
        MetaAIService.lastCalls.first.kind,
        'build:phone-numbers',
      );
    });

    test('a prompt hordozza a sémát és a saját anyagot', () {
      final body = MetaAIService.dynamicTaskRequestBody(req);
      final user = (body['messages'] as List)[1]['content'] as String;
      expect(user, contains('06301234567'));
      expect(user, contains('"answer"'));
      expect(user, contains('choice'));
    });
  });
}
