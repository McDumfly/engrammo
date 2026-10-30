import 'package:engrammo/models/curriculum.dart';
import 'package:engrammo/models/lesson_content.dart';
import 'package:engrammo/screens/lesson_player.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('curriculum shape', () {
    test('36 chapters: 6 tracks x 6 chapters', () {
      expect(chapters.length, 36);
      expect(memoryTracks.length, 6);
    });

    test('first 6 chapters keep 3 sections x 4 lessons', () {
      for (var c = 0; c < 6; c++) {
        expect(chapters[c].sections.length, 3, reason: 'chapter $c');
        for (var s = 0; s < 3; s++) {
          expect(
            chapters[c].sections[s].lessons.length,
            4,
            reason: 'chapter $c section $s',
          );
        }
      }
    });

    test('historic mastery chapters hold 3 sections x 6 lessons', () {
      for (var c = 6; c < 8; c++) {
        expect(chapters[c].sections.length, 3, reason: 'chapter $c');
        for (var s = 0; s < 3; s++) {
          expect(
            chapters[c].sections[s].lessons.length,
            6,
            reason: 'chapter $c section $s',
          );
        }
      }
    });

    test('deep-path chapters hold 3 sections x 4 lessons', () {
      for (var c = 8; c < 30; c++) {
        expect(chapters[c].sections.length, 3, reason: 'chapter $c');
        for (var s = 0; s < 3; s++) {
          expect(
            chapters[c].sections[s].lessons.length,
            4,
            reason: 'chapter $c section $s',
          );
        }
      }
    });

    test('fieldwork chapters hold 3 sections x 4 lessons', () {
      for (var c = 30; c < 36; c++) {
        expect(chapters[c].sections.length, 3, reason: 'chapter $c');
        for (var s = 0; s < 3; s++) {
          expect(
            chapters[c].sections[s].lessons.length,
            4,
            reason: 'chapter $c section $s',
          );
        }
      }
    });

    test('444 lessons total, all with titles', () {
      var total = 0;
      for (final chapter in chapters) {
        for (final section in chapter.sections) {
          expect(section.name, isNotEmpty);
          expect(section.technique, isNotEmpty);
          for (final lesson in section.lessons) {
            expect(lesson.title, isNotEmpty);
            expect(lesson.detail, isNotEmpty);
            total++;
          }
        }
      }
      expect(total, 444);
    });

    test('classic realms untouched', () {
      expect(chapters[0].realm, 'Echo Trail');
      expect(chapters[2].realm, 'Palace Builder');
      expect(chapters[5].realm, 'Name–Face Synthesizer');
      expect(chapters[6].realm, 'Pro Lab');
      expect(chapters[7].realm, 'Grand Gauntlet');
    });

    test('every track ends in a fieldwork chapter', () {
      expect(chapters[30].realm, 'Street Ears');
      expect(chapters[31].realm, 'Number Field');
      expect(chapters[32].realm, 'Two Palaces');
      expect(chapters[33].realm, 'Daily Images');
      expect(chapters[34].realm, 'Week Replay');
      expect(chapters[35].realm, 'Names Out');
    });
  });

  group('track structure', () {
    test('each track walks 6 chapters, foundations first', () {
      for (var t = 0; t < 6; t++) {
        final order = chaptersForTrack(t);
        expect(order.length, 6, reason: 'track $t');
        expect(order.first, t, reason: 'track $t starts at chapter $t');
      }
    });

    test('tracks cover all 36 chapters exactly once', () {
      final seen = <int>{};
      for (var t = 0; t < 6; t++) {
        for (final c in chaptersForTrack(t)) {
          expect(seen.add(c), isTrue, reason: 'chapter $c duplicated');
        }
      }
      expect(seen.length, 36);
    });

    test('every chapter belongs to its own track', () {
      for (var t = 0; t < 6; t++) {
        for (final c in chaptersForTrack(t)) {
          expect(trackOfChapter(c), t, reason: 'chapter $c');
        }
      }
    });

    test('depth and position round-trip', () {
      for (var t = 0; t < 6; t++) {
        final order = chaptersForTrack(t);
        for (var pos = 0; pos < order.length; pos++) {
          final c = order[pos];
          expect(chapterDepth(c), pos, reason: 'chapter $c');
          final loc = trackPositionOfChapter(c);
          expect(loc.track, t, reason: 'chapter $c');
          expect(loc.pos, pos, reason: 'chapter $c');
        }
      }
    });

    test('historic mastery chapters slot into their tracks', () {
      expect(trackOfChapter(6), 2);
      expect(trackOfChapter(7), 1);
      expect(chaptersForTrack(1), contains(7));
      expect(chaptersForTrack(2), contains(6));
      expect(chapterDepth(7), 4);
      expect(chapterDepth(31), 5);
    });
  });

  group('coach content', () {
    test('every section has English coach content', () {
      for (var c = 0; c < chapters.length; c++) {
        for (var s = 0; s < chapters[c].sections.length; s++) {
          final coach = coachFor(c, s);
          expect(coach.title, isNotEmpty, reason: '$c-$s title');
          expect(coach.intro, isNotEmpty, reason: '$c-$s intro');
          expect(coach.steps.length, 3, reason: '$c-$s steps');
          expect(coach.why, isNotEmpty, reason: '$c-$s why');
          expect(coach.source, isNotEmpty, reason: '$c-$s source');
        }
      }
    });
  });

  group('lesson mapping', () {
    test('base chapters train their own kind', () {
      expect(lessonKindFor(0, 0), 'sensory');
      expect(lessonKindFor(1, 0), 'sequence');
      expect(lessonKindFor(2, 0), 'spatial');
      expect(lessonKindFor(3, 0), 'visual');
      expect(lessonKindFor(4, 0), 'verbal');
      expect(lessonKindFor(5, 0), 'verbal');
    });

    test('deep-path chapters train their own track kind', () {
      expect(lessonKindFor(8, 0), 'sensory');
      expect(lessonKindFor(11, 0), 'sensory');
      expect(lessonKindFor(12, 0), 'sequence');
      expect(lessonKindFor(15, 0), 'spatial');
      expect(lessonKindFor(17, 0), 'spatial');
      expect(lessonKindFor(18, 0), 'visual');
      expect(lessonKindFor(22, 0), 'verbal');
      expect(lessonKindFor(26, 0), 'verbal');
      expect(lessonKindFor(29, 0), 'verbal');
    });

    test('mastery chapters mix kinds like competition', () {
      expect(lessonKindFor(6, 0), 'number');
      expect(lessonKindFor(6, 1), 'verbal');
      expect(lessonKindFor(7, 0), 'number');
      expect(lessonKindFor(7, 1), 'sequence');
    });

    test('fieldwork chapters train transfer variants', () {
      expect(lessonKindFor(30, 0), 'sensory');
      expect(lessonKindFor(30, 1), 'interference');
      expect(lessonKindFor(31, 0), 'number');
      expect(lessonKindFor(32, 0), 'spatial');
      expect(lessonKindFor(33, 0), 'visual');
      expect(lessonKindFor(34, 0), 'episodic');
      expect(lessonKindFor(34, 1), 'verbal');
      expect(lessonKindFor(35, 0), 'face');
      expect(lessonKindFor(35, 1), 'foreign');
      expect(lessonKindFor(35, 2), 'semantic');
    });

    test('free recall starts at the finals, never in base chapters', () {
      expect(
        lessonRecallMode(chapter: 5, difficulty: 5, paradigm: 'story-recall'),
        isFalse,
      );
      expect(
        lessonRecallMode(chapter: 6, difficulty: 2, paradigm: 'story-recall'),
        isFalse,
      );
      expect(
        lessonRecallMode(chapter: 6, difficulty: 3, paradigm: 'story-recall'),
        isTrue,
      );
      expect(
        lessonRecallMode(
          chapter: 11,
          difficulty: 5,
          paradigm: 'backward-span',
        ),
        isTrue,
      );
      expect(
        lessonRecallMode(chapter: 11, difficulty: 5, paradigm: 'mystery'),
        isFalse,
      );
      expect(recallCapableParadigm('brown-peterson'), isTrue);
      expect(lessonRecallHint('story-recall'), isNotEmpty);
    });

    test('difficulty rises with depth, finals start at 3', () {
      expect(lessonDifficultyFor(0, 0, 0), 1);
      expect(lessonDifficultyFor(0, 2, 3), 4);
      expect(lessonDifficultyFor(5, 2, 3), 4);
      expect(lessonDifficultyFor(7, 0, 0), 3);
      expect(lessonDifficultyFor(7, 2, 5), 5);
      expect(lessonDifficultyFor(8, 0, 0), 1);
      expect(lessonDifficultyFor(9, 0, 0), 2);
      expect(lessonDifficultyFor(11, 0, 0), 3);
      expect(lessonDifficultyFor(11, 2, 3), 5);
      expect(lessonDifficultyFor(29, 0, 0), 3);
      expect(lessonDifficultyFor(30, 0, 0), 3);
      expect(lessonDifficultyFor(35, 2, 3), 5);
      for (var c = 0; c < 36; c++) {
        for (var s = 0; s < 3; s++) {
          for (var l = 0; l < 6; l++) {
            final d = lessonDifficultyFor(c, s, l);
            expect(d, inInclusiveRange(1, 5), reason: '$c-$s-$l');
          }
        }
      }
    });
  });
}
