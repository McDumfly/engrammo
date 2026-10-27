import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';

import '../theme/app_colors.dart' show amber, coral, sky, teal, violet, violetDark;
import 'meta_task.dart';

class LessonSpec {
  final String title;
  final String detail;
  final List<List<dynamic>> icon;
  final int stars;
  final bool active;
  const LessonSpec(
    this.title,
    this.detail,
    this.icon, {
    this.stars = 0,
    this.active = false,
  });
}

class SectionSpec {
  final String name;
  final String technique;
  final List<List<dynamic>> icon;
  final List<LessonSpec> lessons;
  final bool locked;
  const SectionSpec({
    required this.name,
    required this.technique,
    required this.icon,
    required this.lessons,
    this.locked = false,
  });
}

class ChapterSpec {
  final int memory;
  final String realm;
  final String tagline;
  final Color tint;
  final List<SectionSpec> sections;
  const ChapterSpec({
    required this.memory,
    required this.realm,
    required this.tagline,
    required this.tint,
    required this.sections,
  });
}

const chapters = <ChapterSpec>[
  ChapterSpec(
    memory: 0,
    realm: 'Echo Trail',
    tagline: 'Catch the moment: listen, repeat back.',
    tint: sky,
    sections: [
      SectionSpec(
        name: 'Attention gate',
        technique: 'blocking the next-item effect',
        icon: HugeIcons.strokeRoundedEar,
        lessons: [
          LessonSpec(
            '1 name, in silence',
            'mindful pause',
            HugeIcons.strokeRoundedEar,
            stars: 3,
          ),
          LessonSpec(
            '2 names in a row',
            'instant recall',
            HugeIcons.strokeRoundedMic01,
            stars: 3,
          ),
          LessonSpec(
            'During introductions',
            'set your own role aside',
            HugeIcons.strokeRoundedUser,
            stars: 2,
          ),
          LessonSpec(
            '3 names, 5 seconds',
            'ask for the spelling',
            HugeIcons.strokeRoundedTimer01,
            active: true,
          ),
        ],
      ),
      SectionSpec(
        name: 'Audio flash',
        technique: 'acoustic recoding',
        icon: HugeIcons.strokeRoundedAudioWave01,
        locked: true,
        lessons: [
          LessonSpec(
            '3 items, 3 sec',
            'flashing digits',
            HugeIcons.strokeRoundedAudioWave01,
          ),
          // Egyetlen fizetoeszkoz: engram (lasd collectibles.dart).
          LessonSpec(
            '5 items, 2 sec',
            'halved time',
            HugeIcons.strokeRoundedBrainCircuit,
          ),
          LessonSpec(
            'Heard name back',
            'from sound to motor code',
            HugeIcons.strokeRoundedBellRing,
          ),
          LessonSpec(
            '7 items, 1 sec',
            'engram flash',
            HugeIcons.strokeRoundedHourglass,
          ),
        ],
      ),
      SectionSpec(
        name: 'Noisy field',
        technique: 'selective attention',
        icon: HugeIcons.strokeRoundedShield01,
        locked: true,
        lessons: [
          LessonSpec(
            '3 items in noise',
            'with background chatter',
            HugeIcons.strokeRoundedShield01,
          ),
          LessonSpec(
            '5 items in noise',
            'with music on',
            HugeIcons.strokeRoundedTarget01,
          ),
          LessonSpec(
            'Mixed, in order',
            'keeping the sequence',
            HugeIcons.strokeRoundedFlag01,
          ),
          LessonSpec(
            'Final exam',
            '7 items, noise, timed',
            HugeIcons.strokeRoundedCrown,
          ),
        ],
      ),
    ],
  ),
  ChapterSpec(
    memory: 1,
    realm: 'Chunking Forge',
    tagline: 'Pack big: turn numbers into images.',
    tint: violet,
    sections: [
      SectionSpec(
        name: 'Digit chunks',
        technique: 'chunking • 3-digit codes',
        icon: HugeIcons.strokeRoundedCalculator01,
        lessons: [
          LessonSpec(
            '4 digits',
            'into two chunks',
            HugeIcons.strokeRoundedCalculator01,
            stars: 3,
          ),
          LessonSpec(
            '6 digits',
            'with phonetic images',
            HugeIcons.strokeRoundedHashtag,
            stars: 3,
          ),
          LessonSpec(
            '9 digits',
            'three chunks',
            HugeIcons.strokeRoundedGrid3x3,
            stars: 2,
          ),
          LessonSpec(
            '12 digits',
            'with a code system',
            HugeIcons.strokeRoundedLayers01,
            active: true,
          ),
        ],
      ),
      SectionSpec(
        name: 'Card deck',
        technique: 'card systems',
        icon: HugeIcons.strokeRoundedClubs01,
        locked: true,
        lessons: [
          LessonSpec(
            '4 cards in order',
            'visual chunks',
            HugeIcons.strokeRoundedClubs01,
          ),
          LessonSpec(
            '8 cards',
            'across two stations',
            HugeIcons.strokeRoundedDice,
          ),
          LessonSpec(
            '13 cards, one suit',
            'full suit run',
            HugeIcons.strokeRoundedShapes,
          ),
          LessonSpec(
            'Half deck',
            '26 cards in a row',
            HugeIcons.strokeRoundedCube,
          ),
        ],
      ),
      SectionSpec(
        name: 'LTWM peak',
        technique: 'retrieval structures',
        icon: HugeIcons.strokeRoundedBrain01,
        locked: true,
        lessons: [
          LessonSpec(
            '20 digits',
            'planted into a palace',
            HugeIcons.strokeRoundedBrain01,
          ),
          LessonSpec(
            '32 digits',
            'instant access',
            HugeIcons.strokeRoundedBlocks,
          ),
          LessonSpec(
            'Full deck',
            '52 cards on one walk',
            HugeIcons.strokeRoundedPuzzle,
          ),
          LessonSpec(
            'Championship exam',
            '100 digits',
            HugeIcons.strokeRoundedTrophy,
          ),
        ],
      ),
    ],
  ),
  ChapterSpec(
    memory: 2,
    realm: 'Palace Builder',
    tagline: 'Build a palace in your head, then walk through it.',
    tint: teal,
    sections: [
      SectionSpec(
        name: 'First room',
        technique: 'loci method • 5 stations',
        icon: HugeIcons.strokeRoundedHome01,
        lessons: [
          LessonSpec(
            '3 items, 1 room',
            'ready-made 3D room',
            HugeIcons.strokeRoundedHome01,
            stars: 3,
          ),
          LessonSpec(
            '5 items',
            'fixed viewpoints',
            HugeIcons.strokeRoundedCastle01,
            stars: 3,
          ),
          LessonSpec(
            '5 items backwards',
            'walking it in reverse',
            HugeIcons.strokeRoundedKey01,
            stars: 2,
          ),
          LessonSpec(
            '7 items',
            'two rooms',
            HugeIcons.strokeRoundedFlag01,
            active: true,
          ),
        ],
      ),
      SectionSpec(
        name: 'Island route',
        technique: 'WIM dual view',
        icon: HugeIcons.strokeRoundedCompass,
        locked: true,
        lessons: [
          LessonSpec(
            '10 stations',
            'with a miniature map',
            HugeIcons.strokeRoundedCompass,
          ),
          LessonSpec(
            '15 stations',
            'virtual island',
            HugeIcons.strokeRoundedMapPin,
          ),
          LessonSpec(
            '20 stations',
            'in first person',
            HugeIcons.strokeRoundedRoute01,
          ),
          LessonSpec(
            '27 items',
            'championship list',
            HugeIcons.strokeRoundedFlag02,
          ),
        ],
      ),
      SectionSpec(
        name: 'My own palace',
        technique: 'real route • mental',
        icon: HugeIcons.strokeRoundedCastle02,
        locked: true,
        lessons: [
          LessonSpec(
            'My room, 5 items',
            'a familiar space',
            HugeIcons.strokeRoundedCastle02,
          ),
          LessonSpec(
            'Flat walk, 10 items',
            'room to room',
            HugeIcons.strokeRoundedFortress,
          ),
          LessonSpec(
            'Street walk, 20 items',
            'daily walking route',
            HugeIcons.strokeRoundedFootprints,
          ),
          LessonSpec(
            'In mind, no map',
            'pure mental palace',
            HugeIcons.strokeRoundedCrown,
          ),
        ],
      ),
    ],
  ),
  ChapterSpec(
    memory: 3,
    realm: 'Imagery Lab',
    tagline: 'Paint bizarre pictures out of words.',
    tint: amber,
    sections: [
      SectionSpec(
        name: 'Dual coding',
        technique: 'word + image together',
        icon: HugeIcons.strokeRoundedEye,
        lessons: [
          LessonSpec(
            '5 items pictured',
            'concrete words',
            HugeIcons.strokeRoundedEye,
            stars: 3,
          ),
          LessonSpec(
            '8 items',
            'with motion',
            HugeIcons.strokeRoundedImage01,
            stars: 3,
          ),
          LessonSpec(
            '12 abstract words',
            'picture superiority',
            HugeIcons.strokeRoundedBook01,
            stars: 2,
          ),
          LessonSpec(
            '15 abstract words',
            'a symbol for everything',
            HugeIcons.strokeRoundedIdea01,
            active: true,
          ),
        ],
      ),
      SectionSpec(
        name: 'Odd one out',
        technique: 'Von Restorff isolation',
        // Egyetlen fizetoeszkoz: engram (lasd collectibles.dart).
        icon: HugeIcons.strokeRoundedBrainCircuit,
        locked: true,
        lessons: [
          LessonSpec(
            'Odd one of 5',
            'a single striking item',
            HugeIcons.strokeRoundedBrainCircuit,
          ),
          LessonSpec(
            'Odd one of 8',
            'among similar cues',
            HugeIcons.strokeRoundedTarget01,
          ),
          LessonSpec(
            'Of 12, mixed',
            'size and color isolation',
            HugeIcons.strokeRoundedShapes,
          ),
          LessonSpec(
            'Of 15, timed',
            'engram isolation',
            HugeIcons.strokeRoundedFlag01,
          ),
        ],
      ),
      SectionSpec(
        name: 'Bizarre cinema',
        technique: 'humor effect',
        icon: HugeIcons.strokeRoundedPaintBrush01,
        locked: true,
        lessons: [
          LessonSpec(
            '3 bizarre images',
            'absurd pairings',
            HugeIcons.strokeRoundedPaintBrush01,
          ),
          LessonSpec(
            '5 moving scenes',
            'exaggeration + motion',
            HugeIcons.strokeRoundedSmile,
          ),
          LessonSpec(
            '8 exaggerated images',
            'giant and tiny',
            HugeIcons.strokeRoundedBulb,
          ),
          LessonSpec(
            '10 chained scenes',
            'one continuous movie',
            HugeIcons.strokeRoundedCrown,
          ),
        ],
      ),
    ],
  ),
  ChapterSpec(
    memory: 4,
    realm: 'Journal & Loci Walk',
    tagline: 'Walk through your day again, at night too.',
    tint: coral,
    sections: [
      SectionSpec(
        name: 'Daily journal',
        technique: 'sequential replay',
        icon: HugeIcons.strokeRoundedNotebook01,
        lessons: [
          LessonSpec(
            '3 events today',
            'in order',
            HugeIcons.strokeRoundedNotebook01,
            stars: 3,
          ),
          LessonSpec(
            '5 events in a row',
            'with nothing skipped',
            HugeIcons.strokeRoundedNotebook02,
            stars: 3,
          ),
          LessonSpec(
            'Morning to evening, 7',
            'the full arc',
            HugeIcons.strokeRoundedCalendar01,
            stars: 2,
          ),
          LessonSpec(
            'Yesterday + today',
            'two days chained',
            HugeIcons.strokeRoundedClock01,
            active: true,
          ),
        ],
      ),
      SectionSpec(
        name: 'Time & place anchors',
        technique: 'contextual anchoring',
        icon: HugeIcons.strokeRoundedMapPin,
        locked: true,
        lessons: [
          LessonSpec(
            'Where-when, 3 pairs',
            'tied to places',
            HugeIcons.strokeRoundedMapPin,
          ),
          LessonSpec(
            '5 pairs',
            'with a compass',
            HugeIcons.strokeRoundedCompass,
          ),
          LessonSpec(
            '7 pairs',
            'with time slots',
            HugeIcons.strokeRoundedHourglass,
          ),
          LessonSpec(
            '10 pairs mixed',
            'random order',
            HugeIcons.strokeRoundedTarget01,
          ),
        ],
      ),
      SectionSpec(
        name: 'Evening walk',
        technique: 'loci replay • sleep',
        icon: HugeIcons.strokeRoundedMoon01,
        locked: true,
        lessons: [
          LessonSpec(
            'Palace, 5 stations',
            'before bed',
            HugeIcons.strokeRoundedMoon01,
          ),
          LessonSpec(
            '10 stations at night',
            'micro review',
            HugeIcons.strokeRoundedMoon02,
          ),
          LessonSpec(
            '20 stations',
            'full walkthrough',
            HugeIcons.strokeRoundedBedDouble,
          ),
          LessonSpec(
            'Night consolidation',
            'morning recall',
            HugeIcons.strokeRoundedCrown,
          ),
        ],
      ),
    ],
  ),
  ChapterSpec(
    memory: 5,
    realm: 'Name–Face Synthesizer',
    tagline: 'Networks from names, faces and words.',
    tint: violetDark,
    sections: [
      SectionSpec(
        name: 'Baker breaker',
        technique: "Morris 3 steps • d ≈ 2.4",
        icon: HugeIcons.strokeRoundedFaceId,
        lessons: [
          LessonSpec(
            '2 names + face cue',
            'dominant feature',
            HugeIcons.strokeRoundedFaceId,
            stars: 3,
          ),
          LessonSpec(
            '4 names',
            'name-image + interaction',
            HugeIcons.strokeRoundedUser,
            stars: 3,
          ),
          LessonSpec(
            '6 names, after 30 sec',
            'delayed recall',
            HugeIcons.strokeRoundedSmile,
            stars: 2,
          ),
          LessonSpec(
            '8 names minutes later',
            'durable storage',
            HugeIcons.strokeRoundedEye,
            active: true,
          ),
        ],
      ),
      SectionSpec(
        name: 'Keyword chain',
        technique: 'Atkinson–Raugh method',
        icon: HugeIcons.strokeRoundedTranslate,
        locked: true,
        lessons: [
          LessonSpec(
            '3 foreign words',
            'native-language keyword',
            HugeIcons.strokeRoundedTranslate,
          ),
          LessonSpec(
            '5 words',
            'with a visual scene',
            HugeIcons.strokeRoundedChatTranslate,
          ),
          LessonSpec(
            '8 words',
            'technical terms',
            HugeIcons.strokeRoundedBook04,
          ),
          LessonSpec(
            '12 words unaided',
            'standalone chain',
            HugeIcons.strokeRoundedMic02,
          ),
        ],
      ),
      SectionSpec(
        name: 'Meaning web',
        technique: 'depth of processing',
        icon: HugeIcons.strokeRoundedBrain01,
        locked: true,
        lessons: [
          LessonSpec(
            '3 word families',
            'with etymology',
            HugeIcons.strokeRoundedBrain01,
          ),
          LessonSpec(
            '5 webs',
            'conceptual nodes',
            HugeIcons.strokeRoundedIdea01,
          ),
          LessonSpec(
            '8 chains',
            'deep elaboration',
            HugeIcons.strokeRoundedBulb,
          ),
          LessonSpec(
            '12-minute blitz',
            'master exam',
            HugeIcons.strokeRoundedTrophy,
          ),
        ],
      ),
    ],
  ),
];

/// Spark-lecke leképezése a tanterv `LessonSpec` alakjára.
///
/// A `const chapters` változatlanul a tartalék tanterv; ez csak akkor
/// fut, ha a Meta-válasz élő (nem-fallback). A technika-tipp a
/// `MetaTask.explanation` mezőből jön (loci / képi társítás / kulcsszó).
LessonSpec lessonFromMetaTask(MetaTask task) {
  final title = task.prompt.isEmpty ? 'Meta-lecke' : task.prompt;
  final detail =
      task.explanation.isEmpty ? 'AI-gyakorlat' : task.explanation;
  return LessonSpec(title, detail, HugeIcons.strokeRoundedBrain01);
}
