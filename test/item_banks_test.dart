import 'package:engrammo/models/item_banks.dart';
import 'package:engrammo/models/palace_drill.dart' show concreteNouns;
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('story banks', () {
    test('8 assessment stories: 4 forms x easy/hard', () {
      expect(assessmentStories.length, 8);
      for (var f = 0; f < 4; f++) {
        expect(assessmentStory(f, false).form, f);
        expect(assessmentStory(f, true).form, f);
        expect(assessmentStory(f, true).hard, isTrue);
      }
      expect(spareStories.length, 16);
    });

    test('easy stories carry 3 idea units, hard ones 5', () {
      for (final s in [...assessmentStories, ...spareStories]) {
        expect(
          s.units.length,
          s.hard ? 5 : 3,
          reason: '${s.id} unit count',
        );
        for (final u in s.units) {
          expect(u.label, isNotEmpty);
          expect(u.keywords, isNotEmpty);
        }
      }
    });

    test('MCQ probes are well-formed (key + 3 distinct lures)', () {
      for (final s in [...assessmentStories, ...spareStories]) {
        expect(s.lures.length, 3);
        expect(s.lures, isNot(contains(s.correct)));
        expect(
          {...s.lures, s.correct}.length,
          4,
          reason: '${s.id} options differ',
        );
      }
    });

    test('lessons cannot teach the test: spares disjoint from assessment', () {
      final assess = assessmentStories.map((s) => s.text).toSet();
      for (final s in spareStories) {
        expect(assess, isNot(contains(s.text)));
      }
      final ids = [
        ...assessmentStories.map((s) => s.id),
        ...spareStories.map((s) => s.id),
      ];
      expect(ids.toSet().length, ids.length);
    });

    test('storyUnitsFor resolves banked texts, empty otherwise', () {
      expect(
        storyUnitsFor(assessmentStories.first.text),
        isNotEmpty,
      );
      expect(storyUnitsFor('never banked'), isEmpty);
    });
  });

  group('category banks', () {
    test('8 assessment + 16 spare categories', () {
      expect(assessmentCategories.length, 8);
      expect(spareCategories.length, 16);
      for (var f = 0; f < 4; f++) {
        expect(assessmentCategory(f, false).form, f);
        expect(assessmentCategory(f, true).hard, isTrue);
      }
    });

    test('prototypes differ from neighbor lures, names unique', () {
      final all = [...assessmentCategories, ...spareCategories];
      final names = all.map((c) => c.category).toList();
      expect(names.toSet().length, names.length);
      for (final c in all) {
        expect(c.lures.length, 3);
        expect(c.lures, isNot(contains(c.correct)));
        expect({...c.lures, c.correct}.length, 4);
      }
    });

    test('assessment forms are disjoint: no word repeats across forms', () {
      for (final bank in [assessmentCategories]) {
        final wordsByForm = <int, Set<String>>{};
        for (final c in bank) {
          wordsByForm.putIfAbsent(c.form, () => <String>{}).addAll([
            c.correct.toLowerCase(),
            ...c.lures.map((l) => l.toLowerCase()),
          ]);
        }
        for (var f = 0; f < 4; f++) {
          for (var g = f + 1; g < 4; g++) {
            expect(
              wordsByForm[f]!.intersection(wordsByForm[g]!),
              isEmpty,
              reason: 'forms $f/$g share no category word',
            );
          }
        }
      }
    });
  });

  group('assessment form disjointness (stories)', () {
    test('agent names are unique per story and absent elsewhere', () {
      for (final bank in [assessmentStories]) {
        final agents = [for (final s in bank) s.units.first.label];
        expect(
          agents.map((a) => a.toLowerCase()).toSet().length,
          agents.length,
          reason: 'each assessment story has its own agent',
        );
        for (var i = 0; i < bank.length; i++) {
          final word = RegExp(
            '\\b${RegExp.escape(agents[i])}\\b',
            caseSensitive: false,
          );
          for (var j = 0; j < bank.length; j++) {
            if (i == j) continue;
            expect(
              word.hasMatch(bank[j].text),
              isFalse,
              reason:
                  '"${agents[i]}" (${bank[i].id}) must not appear in ${bank[j].id}',
            );
          }
        }
      }
    });
  });

  group('face-name and foreign-word banks', () {
    test('16 face pairs with unique features', () {
      expect(faceNameBank.length, 16);
      final features = faceNameBank.map((e) => e.feature).toList();
      expect(features.toSet().length, features.length);
      for (final e in faceNameBank) {
        expect(e.hook, isNotEmpty);
        expect({...e.lures, e.name}.length, 4);
      }
    });

    test('32 foreign words, no cognates, distinct options', () {
      expect(foreignWordBank.length, 32);
      final foreign = foreignWordBank.map((e) => e.foreign).toList();
      expect(foreign.toSet().length, foreign.length);
      for (final e in foreignWordBank) {
        expect(e.meaning.toLowerCase() == e.foreign.toLowerCase(), isFalse);
        expect(e.keyword, isNotEmpty);
        expect(e.keyword.toLowerCase() == e.meaning.toLowerCase(), isFalse);
        expect({...e.lures, e.meaning}.length, 4);
      }
    });
  });

  group('scene and noun extras', () {
    test('8 extra scenes x 6 distinct details', () {
      expect(extraPictureScenes.length, 8);
      for (final entry in extraPictureScenes.entries) {
        expect(entry.value.length, 6, reason: entry.key);
        expect(entry.value.toSet().length, 6, reason: entry.key);
      }
    });

    test('24 extra nouns, disjoint from the base pool', () {
      expect(extraConcreteNouns.length, 24);
      expect(extraConcreteNouns.toSet().length, 24);
      final base = concreteNouns.toSet();
      for (final n in extraConcreteNouns) {
        expect(base, isNot(contains(n)));
      }
    });
  });
}
