import 'package:engrammo/models/curriculum.dart';
import 'package:engrammo/models/lesson_content.dart';
import 'package:engrammo/screens/lesson_player.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('curriculum shape', () {
    test('30 chapters: 6 tracks x 5 chapters', () {
      expect(chapters.length, 30);
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

    test('372 lessons total, all with titles', () {
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
      expect(total, 372);
    });

    test('classic realms untouched', () {
      expect(chapters[0].realm, 'Echo Trail');
      expect(chapters[2].realm, 'Palace Builder');
      expect(chapters[5].realm, 'Name–Face Synthesizer');
      expect(chapters[6].realm, "Champion's Arsenal");
      expect(chapters[7].realm, 'Grandmaster Gauntlet');
    });

    test('every track ends in a supermemory final', () {
      expect(chapters[11].realm, 'Golden Ear');
      expect(chapters[7].realm, 'Grandmaster Gauntlet');
      expect(chapters[17].realm, 'Grand Palace');
      expect(chapters[21].realm, 'Supermemory Gallery');
      expect(chapters[25].realm, 'Life Archive');
      expect(chapters[29].realm, 'Name Master');
    });
  });

  group('track structure', () {
    test('each track walks 5 chapters, foundations first', () {
      for (var t = 0; t < 6; t++) {
        final order = chaptersForTrack(t);
        expect(order.length, 5, reason: 'track $t');
        expect(order.first, t, reason: 'track $t starts at chapter $t');
      }
    });

    test('tracks cover all 30 chapters exactly once', () {
      final seen = <int>{};
      for (var t = 0; t < 6; t++) {
        for (final c in chaptersForTrack(t)) {
          expect(seen.add(c), isTrue, reason: 'chapter $c duplicated');
        }
      }
      expect(seen.length, 30);
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
      expect(chaptersForTrack(1).last, 7);
      expect(chapterDepth(7), 4);
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
      for (var c = 0; c < 30; c++) {
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
