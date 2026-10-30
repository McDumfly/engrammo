import 'package:engrammo/models/meta_task.dart';
import 'package:engrammo/models/transfer_missions.dart';
import 'package:engrammo/models/validated_tasks.dart';
import 'package:engrammo/screens/lesson_player.dart';
import 'package:engrammo/services/memory_store.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('transfer paradigms', () {
    test('face and foreign kinds map to their own paradigms', () {
      expect(specForKind('face').id, 'face-name');
      expect(specForKind('foreign').id, 'keyword-pair');
      expect(specForId('face-name').display, isNotEmpty);
      expect(specForId('keyword-pair').display, isNotEmpty);
    });

    test('new local tasks pass their own validation at every level', () {
      for (final kind in ['face', 'foreign']) {
        for (var d = 1; d <= 5; d++) {
          final req = MetaTaskRequest(
            kind: kind,
            difficulty: d,
            seed: 'transfer-$kind-$d',
          );
          final task = localValidatedTask(req);
          expect(task.options.length, 4, reason: '$kind d$d options');
          expect(task.options.toSet().length, 4, reason: '$kind d$d unique');
          expect(task.items, isNotEmpty, reason: '$kind d$d stimulus');
          expect(validateTask(req, task), isEmpty, reason: '$kind d$d valid');
        }
      }
    });

    test('new local tasks are deterministic per seed', () {
      for (final kind in ['face', 'foreign']) {
        final req = MetaTaskRequest(
          kind: kind,
          difficulty: 2,
          seed: 'seed-7',
        );
        final a = localValidatedTask(req);
        final b = localValidatedTask(req);
        expect(a.items, orderedEquals(b.items));
        expect(a.options, orderedEquals(b.options));
        expect(a.correct, b.correct);
      }
    });
  });

  group('deep chapters train their own kind', () {
    test('visual deep chapter alternates visual and spatial', () {
      final kinds = [
        for (var r = 0; r < 4; r++) lessonRoundKindFor(18, 0, r, 4),
      ];
      expect(kinds[0], 'visual');
      expect(kinds[1], 'spatial');
      expect(kinds[2], 'visual');
      expect(kinds[3], 'spatial');
    });

    test('sensory deep chapter alternates sensory and sequence', () {
      final kinds = [
        for (var r = 0; r < 4; r++) lessonRoundKindFor(8, 0, r, 4),
      ];
      expect(kinds[0], 'sensory');
      expect(kinds[1], 'sequence');
    });

    test('grand gauntlet keeps its hard mix', () {
      final kinds = [
        for (var r = 0; r < 4; r++) lessonRoundKindFor(7, 0, r, 4),
      ];
      expect(kinds.toSet(), containsAll(['number', 'sequence', 'spatial']));
    });

    test('new kinds map to their own paradigms', () {
      expect(specForKind('prospective').id, 'prospective-cue');
      expect(specForKind('poem').id, 'poem-chunk');
      expect(specForKind('replay').id, 'day-replay');
      expect(specForId('prospective-cue').display, isNotEmpty);
      expect(specForId('poem-chunk').display, isNotEmpty);
      expect(specForId('day-replay').display, isNotEmpty);
    });

    test('new local tasks pass validation and are deterministic', () {
      for (final kind in ['prospective', 'poem', 'replay']) {
        for (var d = 1; d <= 5; d++) {
          final req = MetaTaskRequest(
            kind: kind,
            difficulty: d,
            seed: 'transfer2-$kind-$d',
          );
          final task = localValidatedTask(req);
          expect(task.options.length, 4, reason: '$kind d$d options');
          expect(task.options.toSet().length, 4, reason: '$kind d$d unique');
          expect(task.items, isNotEmpty, reason: '$kind d$d stimulus');
          expect(validateTask(req, task), isEmpty, reason: '$kind d$d valid');
        }
        final req = MetaTaskRequest(
          kind: kind,
          difficulty: 2,
          seed: 'seed-7',
        );
        final a = localValidatedTask(req);
        final b = localValidatedTask(req);
        expect(a.items, orderedEquals(b.items), reason: kind);
        expect(a.options, orderedEquals(b.options), reason: kind);
        expect(a.correct, b.correct, reason: kind);
      }
    });

    test('fieldwork rotates the new everyday kinds', () {
      expect(lessonKindFor(34, 2), 'replay');
      expect(lessonKindFor(34, 3), 'poem');
      expect(lessonKindFor(35, 3), 'prospective');
      final kinds = [
        for (var r = 0; r < 4; r++) lessonRoundKindFor(34, 2, r, 4),
      ];
      expect(kinds[0], 'replay');
      expect(kinds[1], 'episodic');
    });
  });

  group('transfer missions', () {
    test('4 missions per track, 24 total, unique ids', () {
      expect(transferMissions.length, 24);
      final ids = transferMissions.map((m) => m.id).toSet();
      expect(ids.length, 24);
      for (var t = 0; t < 6; t++) {
        expect(missionsForTrack(t).length, 4, reason: 'track $t');
        for (final m in missionsForTrack(t)) {
          expect(m.track, t);
          expect(m.title, isNotEmpty);
          expect(m.briefing, isNotEmpty);
          expect(m.steps.length, 3);
          expect(m.selfCheck, isNotEmpty);
          expect(m.source, isNotEmpty);
        }
      }
    });

    test('mission lookup finds known ids, null for unknown', () {
      expect(missionById('spatial-home-10'), isNotNull);
      expect(missionById('semantic-talk-5'), isNotNull);
      expect(missionById('no-such-mission'), isNull);
    });

    test('mission completion persists', () async {
      SharedPreferences.setMockInitialValues({});
      expect(await MemoryStore.loadDoneMissions(), isEmpty);
      await MemoryStore.saveMissionDone('spatial-home-10');
      expect(
        await MemoryStore.loadDoneMissions(),
        contains('spatial-home-10'),
      );
      await MemoryStore.saveMissionDone('spatial-home-10', done: false);
      expect(
        await MemoryStore.loadDoneMissions(),
        isNot(contains('spatial-home-10')),
      );
    });
  });
}
