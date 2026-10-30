import 'package:engrammo/models/transfer_targets.dart';
import 'package:engrammo/models/validated_tasks.dart' show specForId;
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('transfer targets', () {
    test('12 cél, egyedi id-k, teljes tartalom', () {
      expect(transferTargets.length, 12);
      final ids = transferTargets.map((t) => t.id).toSet();
      expect(ids.length, 12);
      for (final t in transferTargets) {
        expect(t.label, isNotEmpty, reason: t.id);
        expect(t.situation, isNotEmpty, reason: t.id);
        expect(t.strategy, isNotEmpty, reason: t.id);
        expect(t.paradigms, isNotEmpty, reason: t.id);
        expect(t.source, isNotEmpty, reason: t.id);
      }
    });

    test('a kért hétköznapi célok mind szerepelnek', () {
      for (final id in [
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
        expect(transferTargetById(id), isNotNull, reason: id);
      }
      expect(transferTargetById('no-such-target'), isNull);
    });

    test('minden cél paradigmája létezik a registryben', () {
      for (final t in transferTargets) {
        for (final p in t.paradigms) {
          expect(specForId(p).id, p, reason: '${t.id} → $p');
        }
      }
    });

    test('minden stratégiaparadigmának van hétköznapi célja', () {
      for (final p in [
        'paired-associate',
        'category-exemplar',
        'story-recall',
        'face-name',
        'picture-recall',
        'chunk-span',
        'backward-span',
        'loci-drill',
        'keyword-pair',
        'prospective-cue',
        'poem-chunk',
        'day-replay',
      ]) {
        expect(
          transferTargetsForParadigm(p),
          isNotEmpty,
          reason: 'paradigm $p needs a destination',
        );
      }
    });

    test('minden sávnak van hétköznapi célja', () {
      for (var t = 0; t < 6; t++) {
        expect(
          transferTargetsForTrack(t),
          isNotEmpty,
          reason: 'track $t needs destinations',
        );
      }
    });
  });
}
