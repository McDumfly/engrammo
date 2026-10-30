import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';

import '../l10n/app_localizations.dart';
import '../l10n/curriculum_hu.dart';
import '../theme/app_colors.dart'
    show orange, coral, sky, teal, blue, blueDark;
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

class MemoryTrackSpec {
  final String name;
  final String module;
  final List<List<dynamic>> icon;
  final Color tint;
  const MemoryTrackSpec(this.name, this.module, this.icon, this.tint);
}

const memoryTracks = <MemoryTrackSpec>[
  MemoryTrackSpec(
    'Sensory',
    'From first echo to golden ear',
    HugeIcons.strokeRoundedAudioWave01,
    sky,
  ),
  MemoryTrackSpec(
    'Working memory',
    'From 4 digits to longer numbers',
    HugeIcons.strokeRoundedLayers01,
    blue,
  ),
  MemoryTrackSpec(
    'Spatial',
    'From one room to grand palace',
    HugeIcons.strokeRoundedCastle01,
    teal,
  ),
  MemoryTrackSpec(
    'Visual',
    'From first image to gallery final',
    HugeIcons.strokeRoundedEye,
    orange,
  ),
  MemoryTrackSpec(
    'Episodic',
    'From today to life archive',
    HugeIcons.strokeRoundedNotebook01,
    coral,
  ),
  MemoryTrackSpec(
    'Semantic',
    'From 2 names to confident recall',
    HugeIcons.strokeRoundedBrain01,
    blueDark,
  ),
];

const trackChapters = <List<int>>[
  [0, 8, 9, 10, 11, 30],
  [1, 12, 13, 14, 7, 31],
  [2, 15, 16, 6, 17, 32],
  [3, 18, 19, 20, 21, 33],
  [4, 22, 23, 24, 25, 34],
  [5, 26, 27, 28, 29, 35],
];

List<int> chaptersForTrack(int track) =>
    trackChapters[track.clamp(0, trackChapters.length - 1)];

int trackOfChapter(int chapter) {
  if (chapter < 0 || chapter >= chapters.length) return 0;
  return chapters[chapter].memory.clamp(0, memoryTracks.length - 1);
}

int chapterDepth(int chapter) {
  final order = chaptersForTrack(trackOfChapter(chapter));
  final depth = order.indexOf(chapter);
  return depth < 0 ? 0 : depth;
}

({int track, int pos}) trackPositionOfChapter(int chapter) {
  for (var t = 0; t < trackChapters.length; t++) {
    final pos = trackChapters[t].indexOf(chapter);
    if (pos >= 0) return (track: t, pos: pos);
  }
  return (track: 0, pos: 0);
}

String trackName(int track, [String locale = 'en']) =>
    trFor(locale, 'track_${track.clamp(0, 5)}_name');

String trackTag(int track, [String locale = 'en']) =>
    trFor(locale, 'track_${track.clamp(0, 5)}_tag');

bool _isHu(String locale) => locale == 'hu';

String chapterRealmIn(String locale, int chapter) {
  if (_isHu(locale) &&
      chapter >= 0 &&
      chapter < chaptersHu.length &&
      chaptersHu[chapter].realm.isNotEmpty) {
    return chaptersHu[chapter].realm;
  }
  return chapters[chapter].realm;
}

String chapterTaglineIn(String locale, int chapter) {
  if (_isHu(locale) &&
      chapter >= 0 &&
      chapter < chaptersHu.length &&
      chaptersHu[chapter].tagline.isNotEmpty) {
    return chaptersHu[chapter].tagline;
  }
  return chapters[chapter].tagline;
}

String sectionNameIn(String locale, int chapter, int section) {
  if (_isHu(locale)) {
    final hu = _huSection(chapter, section);
    if (hu != null && hu.name.isNotEmpty) return hu.name;
  }
  return chapters[chapter].sections[section].name;
}

String sectionTechniqueIn(String locale, int chapter, int section) {
  if (_isHu(locale)) {
    final hu = _huSection(chapter, section);
    if (hu != null && hu.technique.isNotEmpty) return hu.technique;
  }
  return chapters[chapter].sections[section].technique;
}

String lessonTitleIn(String locale, int chapter, int section, int lesson) {
  if (_isHu(locale)) {
    final hu = _huLesson(chapter, section, lesson);
    if (hu != null && hu.title.isNotEmpty) return hu.title;
  }
  return chapters[chapter].sections[section].lessons[lesson].title;
}

String lessonDetailIn(String locale, int chapter, int section, int lesson) {
  if (_isHu(locale)) {
    final hu = _huLesson(chapter, section, lesson);
    if (hu != null && hu.detail.isNotEmpty) return hu.detail;
  }
  return chapters[chapter].sections[section].lessons[lesson].detail;
}

SectionHu? _huSection(int chapter, int section) {
  if (chapter < 0 || chapter >= chaptersHu.length) return null;
  final sections = chaptersHu[chapter].sections;
  if (section < 0 || section >= sections.length) return null;
  return sections[section];
}

LessonHu? _huLesson(int chapter, int section, int lesson) {
  final hu = _huSection(chapter, section);
  if (hu == null || lesson < 0 || lesson >= hu.lessons.length) return null;
  return hu.lessons[lesson];
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
            active: true,
          ),
          LessonSpec(
            '2 names in a row',
            'instant recall',
            HugeIcons.strokeRoundedMic01,
          ),
          LessonSpec(
            'During introductions',
            'set your own role aside',
            HugeIcons.strokeRoundedUser,
          ),
          LessonSpec(
            '3 names, 5 seconds',
            'ask for the spelling',
            HugeIcons.strokeRoundedTimer01,
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
    tint: blue,
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
            active: true,
          ),
          LessonSpec(
            '6 digits',
            'with phonetic images',
            HugeIcons.strokeRoundedHashtag,
          ),
          LessonSpec(
            '9 digits',
            'three chunks',
            HugeIcons.strokeRoundedGrid3x3,
          ),
          LessonSpec(
            '12 digits',
            'with a code system',
            HugeIcons.strokeRoundedLayers01,
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
            'Long-list review',
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
            active: true,
          ),
          LessonSpec(
            '5 items',
            'fixed viewpoints',
            HugeIcons.strokeRoundedCastle01,
          ),
          LessonSpec(
            '5 items backwards',
            'walking it in reverse',
            HugeIcons.strokeRoundedKey01,
          ),
          LessonSpec('7 items', 'two rooms', HugeIcons.strokeRoundedFlag01),
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
            'long list',
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
    tint: orange,
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
            active: true,
          ),
          LessonSpec('8 items', 'with motion', HugeIcons.strokeRoundedImage01),
          LessonSpec(
            '12 abstract words',
            'picture superiority',
            HugeIcons.strokeRoundedBook01,
          ),
          LessonSpec(
            '15 abstract words',
            'a symbol for everything',
            HugeIcons.strokeRoundedIdea01,
          ),
        ],
      ),
      SectionSpec(
        name: 'Odd one out',
        technique: 'Von Restorff isolation',
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
            active: true,
          ),
          LessonSpec(
            '5 events in a row',
            'with nothing skipped',
            HugeIcons.strokeRoundedNotebook02,
          ),
          LessonSpec(
            'Morning to evening, 7',
            'the full arc',
            HugeIcons.strokeRoundedCalendar01,
          ),
          LessonSpec(
            'Yesterday + today',
            'two days chained',
            HugeIcons.strokeRoundedClock01,
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
    tint: blueDark,
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
            active: true,
          ),
          LessonSpec(
            '4 names',
            'name-image + interaction',
            HugeIcons.strokeRoundedUser,
          ),
          LessonSpec(
            '6 names, after 30 sec',
            'delayed recall',
            HugeIcons.strokeRoundedSmile,
          ),
          LessonSpec(
            '8 names minutes later',
            'durable storage',
            HugeIcons.strokeRoundedEye,
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
            'mixed review',
            HugeIcons.strokeRoundedTrophy,
          ),
        ],
      ),
    ],
  ),
  ChapterSpec(
    memory: 2,
    realm: 'Pro Lab',
    tagline: 'Pro techniques, step by step: palace, codes, names.',
    tint: orange,
    sections: [
      SectionSpec(
        name: 'Palace workshop',
        technique: 'method of loci • Maguire 2003',
        icon: HugeIcons.strokeRoundedCastle01,
        lessons: [
          LessonSpec(
            'Your first 5 stations',
            'one route, fixed order',
            HugeIcons.strokeRoundedCastle01,
            active: true,
          ),
          LessonSpec(
            '10 stations, one route',
            'distinct loci only',
            HugeIcons.strokeRoundedMapPin,
          ),
          LessonSpec(
            'Place 10 words',
            'one scene per station',
            HugeIcons.strokeRoundedNote01,
          ),
          LessonSpec(
            '15-word walk',
            'timed encoding',
            HugeIcons.strokeRoundedTimer01,
          ),
          LessonSpec(
            '20 stations blind',
            'no peeking',
            HugeIcons.strokeRoundedEye,
          ),
          LessonSpec(
            'Full palace recall',
            'clean walk exam',
            HugeIcons.strokeRoundedMedal01,
          ),
        ],
      ),
      SectionSpec(
        name: 'Number systems',
        technique: 'Major + PAO • Ericsson & Kintsch',
        icon: HugeIcons.strokeRoundedCalculator01,
        locked: true,
        lessons: [
          LessonSpec(
            'Major 0-9',
            'ten fixed images',
            HugeIcons.strokeRoundedCalculator01,
          ),
          LessonSpec(
            'PAO first trio',
            'person-action-object',
            HugeIcons.strokeRoundedUserGroup,
          ),
          LessonSpec(
            '00-19 images',
            'twenty pairs fixed',
            HugeIcons.strokeRoundedHashtag,
          ),
          LessonSpec(
            '6-digit scenes',
            'one station each',
            HugeIcons.strokeRoundedGrid3x3,
          ),
          LessonSpec(
            '12-digit chains',
            'two stations linked',
            HugeIcons.strokeRoundedLink01,
          ),
          LessonSpec(
            '30 digits, one pass',
            'system exam',
            HugeIcons.strokeRoundedMedal02,
          ),
        ],
      ),
      SectionSpec(
        name: 'Name & word lab',
        technique: 'keyword + face-name • Atkinson 1975',
        icon: HugeIcons.strokeRoundedFaceId,
        locked: true,
        lessons: [
          LessonSpec(
            'Keyword basics',
            'sound-alike + image',
            HugeIcons.strokeRoundedTranslate,
          ),
          LessonSpec(
            '5 foreign words',
            'both directions',
            HugeIcons.strokeRoundedChatTranslate,
          ),
          LessonSpec(
            'Face-name 3-step',
            'feature-image-interact',
            HugeIcons.strokeRoundedFaceId,
          ),
          LessonSpec(
            '6 faces, delayed',
            'recall after 5 min',
            HugeIcons.strokeRoundedClock01,
          ),
          LessonSpec(
            '10 words, one story',
            'running chain',
            HugeIcons.strokeRoundedBook04,
          ),
          LessonSpec(
            'Mixed recall',
            'mixed names + words',
            HugeIcons.strokeRoundedCrown,
          ),
        ],
      ),
    ],
  ),
  ChapterSpec(
    memory: 1,
    realm: 'Grand Gauntlet',
    tagline: 'Timed finals in sprint formats — practice, not records.',
    tint: coral,
    sections: [
      SectionSpec(
        name: 'Speed numbers',
        technique: '80-digit sprint • finals format',
        icon: HugeIcons.strokeRoundedStopWatch,
        lessons: [
          LessonSpec(
            '20 digits, 60 sec',
            'steady pace',
            HugeIcons.strokeRoundedStopWatch,
            active: true,
          ),
          LessonSpec(
            '40 digits, 60 sec',
            'double load',
            HugeIcons.strokeRoundedTimer01,
          ),
          LessonSpec(
            '60 digits, 45 sec',
            'pressure on',
            HugeIcons.strokeRoundedFire,
          ),
          LessonSpec(
            '80 digits, 60 sec',
            'final distance',
            HugeIcons.strokeRoundedFlag01,
          ),
          LessonSpec(
            '80 digits, 30 sec',
            'sprint pace',
            HugeIcons.strokeRoundedRocket,
          ),
          LessonSpec(
            '80 digits, 20 sec',
            'top pace',
            HugeIcons.strokeRoundedCrown,
          ),
        ],
      ),
      SectionSpec(
        name: 'Card shark',
        technique: 'PAO card system • timed format',
        icon: HugeIcons.strokeRoundedClubs01,
        locked: true,
        lessons: [
          LessonSpec(
            '10 cards in order',
            'three scenes',
            HugeIcons.strokeRoundedClubs01,
          ),
          LessonSpec(
            'Half deck, 5 min',
            'nine scenes',
            HugeIcons.strokeRoundedSpades,
          ),
          LessonSpec(
            'Full deck, 10 min',
            'seventeen scenes',
            HugeIcons.strokeRoundedDiamond01,
          ),
          LessonSpec(
            'Full deck, 5 min',
            'halved time',
            HugeIcons.strokeRoundedHeart,
          ),
          LessonSpec(
            'Full deck, 2 min',
            'brisk pace',
            HugeIcons.strokeRoundedDice,
          ),
          LessonSpec(
            'Speed cards, 60 sec',
            'final round',
            HugeIcons.strokeRoundedTrophy,
          ),
        ],
      ),
      SectionSpec(
        name: 'Palace marathon',
        technique: '27-item walk • Dresler 2017',
        icon: HugeIcons.strokeRoundedMountain,
        locked: true,
        lessons: [
          LessonSpec(
            '15-item walk',
            'one palace',
            HugeIcons.strokeRoundedMountain,
          ),
          LessonSpec(
            '20-item walk',
            'extended route',
            HugeIcons.strokeRoundedMapPin,
          ),
          LessonSpec(
            '27-item walk',
            'lab milestone',
            HugeIcons.strokeRoundedFlag01,
          ),
          LessonSpec(
            '50-item palace',
            'grand route',
            HugeIcons.strokeRoundedCastle01,
          ),
          LessonSpec(
            '100-word palace',
            'multi-palace chain',
            HugeIcons.strokeRoundedLayers01,
          ),
          LessonSpec(
            'Grand final',
            'mixed foundation review',
            HugeIcons.strokeRoundedCrown,
          ),
        ],
      ),
    ],
  ),
  ChapterSpec(
    memory: 0,
    realm: 'Echo Chamber',
    tagline: 'Longer echoes: rhythm, delay, replay.',
    tint: sky,
    sections: [
      SectionSpec(
        name: 'Rhythm codes',
        technique: 'grouping by beat',
        icon: HugeIcons.strokeRoundedAudioWave01,
        lessons: [
          LessonSpec(
            '4 beats, one bar',
            'clap the pattern',
            HugeIcons.strokeRoundedAudioWave01,
          ),
          LessonSpec(
            '6 beats, two bars',
            'two grouped bars',
            HugeIcons.strokeRoundedMic01,
          ),
          LessonSpec(
            '8 beats, odd meter',
            'broken rhythm',
            HugeIcons.strokeRoundedTimer01,
          ),
          LessonSpec(
            '10 beats, call back',
            'long pattern',
            HugeIcons.strokeRoundedFlag01,
          ),
        ],
      ),
      SectionSpec(
        name: 'Delayed echo',
        technique: 'holding the trace',
        icon: HugeIcons.strokeRoundedHourglass,
        locked: true,
        lessons: [
          LessonSpec(
            '3 items, 10 sec',
            'wait, then recall',
            HugeIcons.strokeRoundedHourglass,
          ),
          LessonSpec(
            '5 items, 20 sec',
            'silent hold',
            HugeIcons.strokeRoundedClock01,
          ),
          LessonSpec(
            '5 items, 60 sec',
            'with distraction',
            HugeIcons.strokeRoundedShield01,
          ),
          LessonSpec(
            '7 items, 30 sec',
            'delayed final',
            HugeIcons.strokeRoundedMedal01,
          ),
        ],
      ),
      SectionSpec(
        name: 'Overlapping voices',
        technique: 'cocktail-party focus',
        icon: HugeIcons.strokeRoundedEar,
        locked: true,
        lessons: [
          LessonSpec(
            'Two voices, one target',
            'follow one stream',
            HugeIcons.strokeRoundedEar,
          ),
          LessonSpec(
            'Three voices',
            'crowded room',
            HugeIcons.strokeRoundedUserGroup,
          ),
          LessonSpec(
            'Voice plus music',
            'melody on top',
            HugeIcons.strokeRoundedBellRing,
          ),
          LessonSpec(
            'Party exam',
            'noisy recall',
            HugeIcons.strokeRoundedCrown,
          ),
        ],
      ),
    ],
  ),
  ChapterSpec(
    memory: 0,
    realm: 'Sound Palace',
    tagline: 'Bolt sounds onto places and pictures.',
    tint: sky,
    sections: [
      SectionSpec(
        name: 'Sound pictures',
        technique: 'auditory dual coding',
        icon: HugeIcons.strokeRoundedImage01,
        lessons: [
          LessonSpec(
            '3 sounds pictured',
            'one image each',
            HugeIcons.strokeRoundedImage01,
          ),
          LessonSpec(
            '5 sounds pictured',
            'moving images',
            HugeIcons.strokeRoundedEye,
          ),
          LessonSpec(
            '7 sounds pictured',
            'absurd pairings',
            HugeIcons.strokeRoundedPaintBrush01,
          ),
          LessonSpec(
            '10 sounds pictured',
            'full gallery',
            HugeIcons.strokeRoundedFlag01,
          ),
        ],
      ),
      SectionSpec(
        name: 'Melody routes',
        technique: 'loci for sequences',
        icon: HugeIcons.strokeRoundedRoute01,
        locked: true,
        lessons: [
          LessonSpec(
            '4 sounds, 4 stations',
            'known route',
            HugeIcons.strokeRoundedRoute01,
          ),
          LessonSpec(
            '6 sounds on route',
            'room to room',
            HugeIcons.strokeRoundedHome01,
          ),
          LessonSpec(
            '8 sounds on route',
            'extended walk',
            HugeIcons.strokeRoundedMapPin,
          ),
          LessonSpec(
            '10 sounds on route',
            'clean walk exam',
            HugeIcons.strokeRoundedMedal01,
          ),
        ],
      ),
      SectionSpec(
        name: 'Timbre tags',
        technique: 'distinctive encoding',
        icon: HugeIcons.strokeRoundedMic02,
        locked: true,
        lessons: [
          LessonSpec(
            'High vs low',
            'pitch tags',
            HugeIcons.strokeRoundedMic02,
          ),
          LessonSpec(
            'Loud vs soft',
            'volume tags',
            HugeIcons.strokeRoundedMic01,
          ),
          LessonSpec(
            'Fast vs slow',
            'tempo tags',
            HugeIcons.strokeRoundedTimer01,
          ),
          LessonSpec(
            'Mixed tags exam',
            'all cues at once',
            HugeIcons.strokeRoundedCrown,
          ),
        ],
      ),
    ],
  ),
  ChapterSpec(
    memory: 0,
    realm: 'Concert Hall',
    tagline: 'Fast, loud, long: pressure training.',
    tint: sky,
    sections: [
      SectionSpec(
        name: 'Speed echo',
        technique: 'fast encoding',
        icon: HugeIcons.strokeRoundedStopWatch,
        lessons: [
          LessonSpec(
            '5 items, 5 sec',
            'one second each',
            HugeIcons.strokeRoundedStopWatch,
          ),
          LessonSpec(
            '7 items, 5 sec',
            'faster stream',
            HugeIcons.strokeRoundedTimer01,
          ),
          LessonSpec(
            '10 items, 10 sec',
            'concert tempo',
            HugeIcons.strokeRoundedFire,
          ),
          LessonSpec(
            '12 items, 10 sec',
            'sprint final',
            HugeIcons.strokeRoundedFlag01,
          ),
        ],
      ),
      SectionSpec(
        name: 'Crowd filter',
        technique: 'attention under load',
        icon: HugeIcons.strokeRoundedShield01,
        locked: true,
        lessons: [
          LessonSpec(
            '5 items, crowd noise',
            'steady filter',
            HugeIcons.strokeRoundedShield01,
          ),
          LessonSpec(
            '7 items, loud crowd',
            'pressure on',
            HugeIcons.strokeRoundedTarget01,
          ),
          LessonSpec(
            '7 items, mixed noise',
            'music plus chat',
            HugeIcons.strokeRoundedAudioWave01,
          ),
          LessonSpec(
            '10 items, full hall',
            'crowd exam',
            HugeIcons.strokeRoundedMedal02,
          ),
        ],
      ),
      SectionSpec(
        name: 'Long replays',
        technique: 'extended echoic span',
        icon: HugeIcons.strokeRoundedClock01,
        locked: true,
        lessons: [
          LessonSpec(
            '12 items, slow',
            'careful intake',
            HugeIcons.strokeRoundedClock01,
          ),
          LessonSpec(
            '15 items, slow',
            'long sequence',
            HugeIcons.strokeRoundedNotebook01,
          ),
          LessonSpec(
            '15 items, normal',
            'hall pace',
            HugeIcons.strokeRoundedHourglass,
          ),
          LessonSpec(
            '20 items, one pass',
            'marathon echo',
            HugeIcons.strokeRoundedCrown,
          ),
        ],
      ),
    ],
  ),
  ChapterSpec(
    memory: 0,
    realm: 'Golden Ear',
    tagline: 'The listening final: names, sequences, delays.',
    tint: sky,
    sections: [
      SectionSpec(
        name: 'Number sprint',
        technique: 'phone numbers by ear',
        icon: HugeIcons.strokeRoundedCalculator01,
        lessons: [
          LessonSpec(
            '7 digits by ear',
            'one hearing',
            HugeIcons.strokeRoundedCalculator01,
          ),
          LessonSpec(
            '10 digits by ear',
            'chunked live',
            HugeIcons.strokeRoundedHashtag,
          ),
          LessonSpec(
            '12 digits in noise',
            'street test',
            HugeIcons.strokeRoundedShield01,
          ),
          LessonSpec(
            '15 digits, one pass',
            'sprint exam',
            HugeIcons.strokeRoundedMedal01,
          ),
        ],
      ),
      SectionSpec(
        name: 'Speech shadowing',
        technique: 'repeat-while-listening',
        icon: HugeIcons.strokeRoundedMic01,
        locked: true,
        lessons: [
          LessonSpec(
            'Short phrases',
            'echo at once',
            HugeIcons.strokeRoundedMic01,
          ),
          LessonSpec(
            'Long sentences',
            'half-beat delay',
            HugeIcons.strokeRoundedMic02,
          ),
          LessonSpec(
            'Fast speech',
            'newsreader pace',
            HugeIcons.strokeRoundedTimer01,
          ),
          LessonSpec(
            'Story shadowing',
            'two minutes straight',
            HugeIcons.strokeRoundedFlag01,
          ),
        ],
      ),
      SectionSpec(
        name: 'Golden ear review',
        technique: 'trained listening review',
        icon: HugeIcons.strokeRoundedCrown,
        locked: true,
        lessons: [
          LessonSpec(
            'Names in noise',
            'party final',
            HugeIcons.strokeRoundedEar,
          ),
          LessonSpec(
            '20-item sequence',
            'concert final',
            HugeIcons.strokeRoundedAudioWave01,
          ),
          LessonSpec(
            'Delayed everything',
            'recall after delay',
            HugeIcons.strokeRoundedHourglass,
          ),
          LessonSpec(
            'Golden ear',
            'listening review',
            HugeIcons.strokeRoundedTrophy,
          ),
        ],
      ),
    ],
  ),
  ChapterSpec(
    memory: 1,
    realm: 'Number Atelier',
    tagline: 'A fixed image for every number.',
    tint: blue,
    sections: [
      SectionSpec(
        name: 'Major 00-19',
        technique: 'consonant codes',
        icon: HugeIcons.strokeRoundedCalculator01,
        lessons: [
          LessonSpec(
            'Major 0-4',
            'five fixed images',
            HugeIcons.strokeRoundedCalculator01,
          ),
          LessonSpec(
            'Major 5-9',
            'ten fixed images',
            HugeIcons.strokeRoundedHashtag,
          ),
          LessonSpec(
            'Pairs 10-14',
            'first pairs',
            HugeIcons.strokeRoundedGrid3x3,
          ),
          LessonSpec(
            'Pairs 15-19',
            'twenty codes',
            HugeIcons.strokeRoundedFlag01,
          ),
        ],
      ),
      SectionSpec(
        name: 'Image pairs',
        technique: 'instant pair recall',
        icon: HugeIcons.strokeRoundedLink01,
        locked: true,
        lessons: [
          LessonSpec(
            '10 pairs, slow',
            'no hesitation goal',
            HugeIcons.strokeRoundedLink01,
          ),
          LessonSpec(
            '20 pairs, slow',
            'full set walk',
            HugeIcons.strokeRoundedLayers01,
          ),
          LessonSpec(
            '20 pairs, fast',
            'two seconds each',
            HugeIcons.strokeRoundedTimer01,
          ),
          LessonSpec(
            'Pairs exam',
            'instant recall',
            HugeIcons.strokeRoundedMedal01,
          ),
        ],
      ),
      SectionSpec(
        name: 'First PAO scenes',
        technique: 'person-action-object',
        icon: HugeIcons.strokeRoundedUserGroup,
        locked: true,
        lessons: [
          LessonSpec(
            'One PAO scene',
            'six digits, one image',
            HugeIcons.strokeRoundedUserGroup,
          ),
          LessonSpec(
            'Three scenes',
            'eighteen digits',
            HugeIcons.strokeRoundedBlocks,
          ),
          LessonSpec(
            'Five scenes',
            'thirty digits',
            HugeIcons.strokeRoundedCube,
          ),
          LessonSpec(
            'PAO debut review',
            'steady recall',
            HugeIcons.strokeRoundedCrown,
          ),
        ],
      ),
    ],
  ),
  ChapterSpec(
    memory: 1,
    realm: 'Card Studio',
    tagline: 'Every card becomes a person.',
    tint: blue,
    sections: [
      SectionSpec(
        name: 'Suit persons',
        technique: 'fixed card images',
        icon: HugeIcons.strokeRoundedClubs01,
        lessons: [
          LessonSpec(
            'One suit, 13 faces',
            'hearts first',
            HugeIcons.strokeRoundedHeart,
          ),
          LessonSpec(
            'Two suits',
            'twenty-six faces',
            HugeIcons.strokeRoundedSpades,
          ),
          LessonSpec(
            'Four suits',
            'full cast',
            HugeIcons.strokeRoundedClubs01,
          ),
          LessonSpec(
            'Cast exam',
            'any card, instant',
            HugeIcons.strokeRoundedMedal01,
          ),
        ],
      ),
      SectionSpec(
        name: 'Action links',
        technique: 'two-card scenes',
        icon: HugeIcons.strokeRoundedLink01,
        locked: true,
        lessons: [
          LessonSpec(
            '4 cards, 2 scenes',
            'person meets person',
            HugeIcons.strokeRoundedLink01,
          ),
          LessonSpec(
            '6 cards, 2 scenes',
            'PAO pairs',
            HugeIcons.strokeRoundedDiamond01,
          ),
          LessonSpec(
            '9 cards, 3 scenes',
            'flowing run',
            HugeIcons.strokeRoundedDice,
          ),
          LessonSpec(
            '12 cards in order',
            'four scenes clean',
            HugeIcons.strokeRoundedFlag01,
          ),
        ],
      ),
      SectionSpec(
        name: 'Half-deck flows',
        technique: 'palace card runs',
        icon: HugeIcons.strokeRoundedSpades,
        locked: true,
        lessons: [
          LessonSpec(
            '13 cards, 10 min',
            'slow and clean',
            HugeIcons.strokeRoundedSpades,
          ),
          LessonSpec(
            '20 cards, 10 min',
            'longer run',
            HugeIcons.strokeRoundedClock01,
          ),
          LessonSpec(
            '26 cards, 10 min',
            'half deck',
            HugeIcons.strokeRoundedLayers01,
          ),
          LessonSpec(
            'Half-deck exam',
            'no missed scene',
            HugeIcons.strokeRoundedCrown,
          ),
        ],
      ),
    ],
  ),
  ChapterSpec(
    memory: 1,
    realm: 'Mental Abacus',
    tagline: 'Hold more, flip faster, update cleanly.',
    tint: blue,
    sections: [
      SectionSpec(
        name: 'Running totals',
        technique: 'updating drill',
        icon: HugeIcons.strokeRoundedHash,
        lessons: [
          LessonSpec(
            'Add 5 numbers',
            'hold the total',
            HugeIcons.strokeRoundedHash,
          ),
          LessonSpec(
            'Add and drop',
            'update the total',
            HugeIcons.strokeRoundedRefresh,
          ),
          LessonSpec(
            'Add 10 numbers',
            'long running sum',
            HugeIcons.strokeRoundedCalculator01,
          ),
          LessonSpec(
            'Totals review',
            'steady accuracy',
            HugeIcons.strokeRoundedMedal01,
          ),
        ],
      ),
      SectionSpec(
        name: 'Backward chains',
        technique: 'reverse span',
        icon: HugeIcons.strokeRoundedArrowLeft01,
        locked: true,
        lessons: [
          LessonSpec(
            '4 back',
            'short reversal',
            HugeIcons.strokeRoundedArrowLeft01,
          ),
          LessonSpec(
            '6 back',
            'full flip',
            HugeIcons.strokeRoundedRefresh,
          ),
          LessonSpec(
            '8 back',
            'long reversal',
            HugeIcons.strokeRoundedTimer01,
          ),
          LessonSpec(
            'Backward exam',
            'no peeking',
            HugeIcons.strokeRoundedFlag01,
          ),
        ],
      ),
      SectionSpec(
        name: 'Dual tasks',
        technique: 'executive load',
        icon: HugeIcons.strokeRoundedBrainCircuit,
        locked: true,
        lessons: [
          LessonSpec(
            'Hold plus count',
            'two jobs at once',
            HugeIcons.strokeRoundedBrainCircuit,
          ),
          LessonSpec(
            'Hold plus sort',
            'reorder mid-hold',
            HugeIcons.strokeRoundedBlocks,
          ),
          LessonSpec(
            'Double sequence',
            'two streams',
            HugeIcons.strokeRoundedLayers01,
          ),
          LessonSpec(
            'Dual exam',
            'both streams clean',
            HugeIcons.strokeRoundedCrown,
          ),
        ],
      ),
    ],
  ),
  ChapterSpec(
    memory: 2,
    realm: 'Palace District',
    tagline: 'More palaces, more stations, kept distinct.',
    tint: teal,
    sections: [
      SectionSpec(
        name: 'Second palace',
        technique: 'fresh route • 15 stations',
        icon: HugeIcons.strokeRoundedHome01,
        lessons: [
          LessonSpec(
            'New route, 5 stations',
            'a second home',
            HugeIcons.strokeRoundedHome01,
          ),
          LessonSpec(
            '10 stations',
            'distinct loci only',
            HugeIcons.strokeRoundedMapPin,
          ),
          LessonSpec(
            '15 stations',
            'full second palace',
            HugeIcons.strokeRoundedCastle01,
          ),
          LessonSpec(
            'Two-palace quiz',
            'no cross-talk',
            HugeIcons.strokeRoundedFlag01,
          ),
        ],
      ),
      SectionSpec(
        name: 'Palace linking',
        technique: 'chained routes',
        icon: HugeIcons.strokeRoundedRoute01,
        locked: true,
        lessons: [
          LessonSpec(
            'Bridge two palaces',
            'one grand walk',
            HugeIcons.strokeRoundedRoute01,
          ),
          LessonSpec(
            '30 stations linked',
            'district walk',
            HugeIcons.strokeRoundedCompass,
          ),
          LessonSpec(
            '40 stations linked',
            'long district',
            HugeIcons.strokeRoundedLayers01,
          ),
          LessonSpec(
            'District exam',
            'clean full walk',
            HugeIcons.strokeRoundedMedal01,
          ),
        ],
      ),
      SectionSpec(
        name: 'Palace upkeep',
        technique: 'ghost-busting • reuse',
        icon: HugeIcons.strokeRoundedShield01,
        locked: true,
        lessons: [
          LessonSpec(
            'Ghost hunt',
            'spot stale images',
            HugeIcons.strokeRoundedSearch01,
          ),
          LessonSpec(
            'Wipe and reuse',
            'clean a palace',
            HugeIcons.strokeRoundedRefresh,
          ),
          LessonSpec(
            'Rest a palace',
            'rotate three routes',
            HugeIcons.strokeRoundedClock01,
          ),
          LessonSpec(
            'Upkeep exam',
            'fresh images only',
            HugeIcons.strokeRoundedCrown,
          ),
        ],
      ),
    ],
  ),
  ChapterSpec(
    memory: 2,
    realm: 'Speed Encoding',
    tagline: 'One look per station, full speed.',
    tint: teal,
    sections: [
      SectionSpec(
        name: '5-second scenes',
        technique: 'timed placement',
        icon: HugeIcons.strokeRoundedStopWatch,
        lessons: [
          LessonSpec(
            '5 scenes, slow',
            'ten seconds each',
            HugeIcons.strokeRoundedStopWatch,
          ),
          LessonSpec(
            '10 scenes, timed',
            'five seconds each',
            HugeIcons.strokeRoundedTimer01,
          ),
          LessonSpec(
            '15 scenes, timed',
            'no second looks',
            HugeIcons.strokeRoundedFire,
          ),
          LessonSpec(
            'Speed scene exam',
            'fast and sticky',
            HugeIcons.strokeRoundedMedal01,
          ),
        ],
      ),
      SectionSpec(
        name: 'One-pass walks',
        technique: 'no re-entry encoding',
        icon: HugeIcons.strokeRoundedFootprints,
        locked: true,
        lessons: [
          LessonSpec(
            '10 items, one pass',
            'walk once',
            HugeIcons.strokeRoundedFootprints,
          ),
          LessonSpec(
            '15 items, one pass',
            'commit and go',
            HugeIcons.strokeRoundedRoute01,
          ),
          LessonSpec(
            '20 items, one pass',
            'trust the walk',
            HugeIcons.strokeRoundedFlag01,
          ),
          LessonSpec(
            'One-pass exam',
            'single walk recall',
            HugeIcons.strokeRoundedFlag02,
          ),
        ],
      ),
      SectionSpec(
        name: 'Error repair',
        technique: 'station triage',
        icon: HugeIcons.strokeRoundedTarget01,
        locked: true,
        lessons: [
          LessonSpec(
            'Find the gap',
            'locate weak stations',
            HugeIcons.strokeRoundedTarget01,
          ),
          LessonSpec(
            'Rebuild 3 stations',
            'stronger images',
            HugeIcons.strokeRoundedPencilEdit02,
          ),
          LessonSpec(
            'Full re-walk',
            'verify the fix',
            HugeIcons.strokeRoundedRefresh,
          ),
          LessonSpec(
            'Repair exam',
            'zero-gap walk',
            HugeIcons.strokeRoundedCrown,
          ),
        ],
      ),
    ],
  ),
  ChapterSpec(
    memory: 2,
    realm: 'Grand Palace',
    tagline: 'The long walk: 100 stations, one route.',
    tint: teal,
    sections: [
      SectionSpec(
        name: 'Grand route',
        technique: '50-station palace',
        icon: HugeIcons.strokeRoundedCastle01,
        lessons: [
          LessonSpec(
            '30 stations',
            'grand opening',
            HugeIcons.strokeRoundedCastle01,
          ),
          LessonSpec(
            '40 stations',
            'extended wings',
            HugeIcons.strokeRoundedFortress,
          ),
          LessonSpec(
            '50 stations',
            'full grand route',
            HugeIcons.strokeRoundedMapPin,
          ),
          LessonSpec(
            'Grand route exam',
            'one clean walk',
            HugeIcons.strokeRoundedMedal01,
          ),
        ],
      ),
      SectionSpec(
        name: 'Multi-palace chain',
        technique: '100-station chain',
        icon: HugeIcons.strokeRoundedLayers01,
        locked: true,
        lessons: [
          LessonSpec(
            '60 stations',
            'two palaces chained',
            HugeIcons.strokeRoundedLayers01,
          ),
          LessonSpec(
            '80 stations',
            'three palaces',
            HugeIcons.strokeRoundedLink01,
          ),
          LessonSpec(
            '100 stations',
            'long distance',
            HugeIcons.strokeRoundedFlag01,
          ),
          LessonSpec(
            'Chain review',
            'steady links',
            HugeIcons.strokeRoundedMedal02,
          ),
        ],
      ),
      SectionSpec(
        name: 'Grand walk',
        technique: 'long-route review',
        icon: HugeIcons.strokeRoundedCrown,
        locked: true,
        lessons: [
          LessonSpec(
            '50 words, one walk',
            'grand final leg 1',
            HugeIcons.strokeRoundedNote01,
          ),
          LessonSpec(
            '100 words, one walk',
            'grand final leg 2',
            HugeIcons.strokeRoundedBook01,
          ),
          LessonSpec(
            'Blind re-walk',
            'recall next morning',
            HugeIcons.strokeRoundedMoon01,
          ),
          LessonSpec(
            'Grand palace',
            'long-route review',
            HugeIcons.strokeRoundedTrophy,
          ),
        ],
      ),
    ],
  ),
  ChapterSpec(
    memory: 3,
    realm: 'Detail Studio',
    tagline: 'Twins, patterns, colors: spot everything.',
    tint: orange,
    sections: [
      SectionSpec(
        name: 'Twin spotter',
        technique: 'fine discrimination',
        icon: HugeIcons.strokeRoundedEye,
        lessons: [
          LessonSpec(
            'Spot 1 difference',
            'two near-twins',
            HugeIcons.strokeRoundedEye,
          ),
          LessonSpec(
            'Spot 3 differences',
            'busy twins',
            HugeIcons.strokeRoundedSearch01,
          ),
          LessonSpec(
            'Spot 5 differences',
            'timed twins',
            HugeIcons.strokeRoundedTimer01,
          ),
          LessonSpec(
            'Twin review',
            'sharp eyes',
            HugeIcons.strokeRoundedMedal01,
          ),
        ],
      ),
      SectionSpec(
        name: 'Pattern vault',
        technique: 'abstract encoding',
        icon: HugeIcons.strokeRoundedGrid3x3,
        locked: true,
        lessons: [
          LessonSpec(
            '3x3 patterns',
            'name each motif',
            HugeIcons.strokeRoundedGrid3x3,
          ),
          LessonSpec(
            '5x5 patterns',
            'chunk the grid',
            HugeIcons.strokeRoundedShapes,
          ),
          LessonSpec(
            'Rotations',
            'same, but turned',
            HugeIcons.strokeRoundedRefresh,
          ),
          LessonSpec(
            'Vault exam',
            'draw from memory',
            HugeIcons.strokeRoundedFlag01,
          ),
        ],
      ),
      SectionSpec(
        name: 'Color codes',
        technique: 'color tagging',
        icon: HugeIcons.strokeRoundedPaintBrush01,
        locked: true,
        lessons: [
          LessonSpec(
            '4 color tags',
            'one meaning each',
            HugeIcons.strokeRoundedPaintBrush01,
          ),
          LessonSpec(
            '8 color tags',
            'full palette',
            HugeIcons.strokeRoundedBulb,
          ),
          LessonSpec(
            'Colors in order',
            'sequence recall',
            HugeIcons.strokeRoundedFlag01,
          ),
          LessonSpec(
            'Color exam',
            'no swapped tags',
            HugeIcons.strokeRoundedCrown,
          ),
        ],
      ),
    ],
  ),
  ChapterSpec(
    memory: 3,
    realm: 'Movie Director',
    tagline: 'Chain scenes into connected films.',
    tint: orange,
    sections: [
      SectionSpec(
        name: 'Scene chains',
        technique: 'linked imagery',
        icon: HugeIcons.strokeRoundedLink01,
        lessons: [
          LessonSpec(
            '3-scene chain',
            'one flowing shot',
            HugeIcons.strokeRoundedLink01,
          ),
          LessonSpec(
            '5-scene chain',
            'action links',
            HugeIcons.strokeRoundedImage01,
          ),
          LessonSpec(
            '8-scene chain',
            'short film',
            HugeIcons.strokeRoundedClubs01,
          ),
          LessonSpec(
            'Chain exam',
            'unbroken film',
            HugeIcons.strokeRoundedMedal01,
          ),
        ],
      ),
      SectionSpec(
        name: 'Storyboards',
        technique: 'ordered frames',
        icon: HugeIcons.strokeRoundedNote01,
        locked: true,
        lessons: [
          LessonSpec(
            '4 frames',
            'beginning to end',
            HugeIcons.strokeRoundedNote01,
          ),
          LessonSpec(
            '6 frames',
            'with a twist',
            HugeIcons.strokeRoundedBook01,
          ),
          LessonSpec(
            '10 frames',
            'full storyboard',
            HugeIcons.strokeRoundedLayers01,
          ),
          LessonSpec(
            'Storyboard exam',
            'every frame placed',
            HugeIcons.strokeRoundedFlag01,
          ),
        ],
      ),
      SectionSpec(
        name: 'Speed sketches',
        technique: 'fast visual capture',
        icon: HugeIcons.strokeRoundedTimer01,
        locked: true,
        lessons: [
          LessonSpec(
            'Sketch in 10 sec',
            'essence only',
            HugeIcons.strokeRoundedTimer01,
          ),
          LessonSpec(
            'Sketch in 5 sec',
            'one key feature',
            HugeIcons.strokeRoundedStopWatch,
          ),
          LessonSpec(
            '10 fast sketches',
            'gallery sprint',
            HugeIcons.strokeRoundedFire,
          ),
          LessonSpec(
            'Sketch exam',
            'recognizable fast',
            HugeIcons.strokeRoundedCrown,
          ),
        ],
      ),
    ],
  ),
  ChapterSpec(
    memory: 3,
    realm: 'Photo Archive',
    tagline: 'Fifty pictures, filed and findable.',
    tint: orange,
    sections: [
      SectionSpec(
        name: 'Gallery walks',
        technique: 'visual loci',
        icon: HugeIcons.strokeRoundedImage01,
        lessons: [
          LessonSpec(
            '10 pictures filed',
            'one gallery wall',
            HugeIcons.strokeRoundedImage01,
          ),
          LessonSpec(
            '20 pictures filed',
            'two walls',
            HugeIcons.strokeRoundedHome01,
          ),
          LessonSpec(
            '30 pictures filed',
            'full gallery',
            HugeIcons.strokeRoundedCastle01,
          ),
          LessonSpec(
            'Gallery exam',
            'guided tour',
            HugeIcons.strokeRoundedMedal01,
          ),
        ],
      ),
      SectionSpec(
        name: 'Set review',
        technique: 'spaced visual review',
        icon: HugeIcons.strokeRoundedCalendar01,
        locked: true,
        lessons: [
          LessonSpec(
            'Review after 1 day',
            'fresh check',
            HugeIcons.strokeRoundedCalendar01,
          ),
          LessonSpec(
            'Review after 3 days',
            'spaced check',
            HugeIcons.strokeRoundedClock01,
          ),
          LessonSpec(
            'Review after a week',
            'durable check',
            HugeIcons.strokeRoundedHourglass,
          ),
          LessonSpec(
            'Review exam',
            'nothing lost',
            HugeIcons.strokeRoundedFlag01,
          ),
        ],
      ),
      SectionSpec(
        name: 'Blur repair',
        technique: 'fading-trace rescue',
        icon: HugeIcons.strokeRoundedGlasses,
        locked: true,
        lessons: [
          LessonSpec(
            'Find faded ones',
            'honest audit',
            HugeIcons.strokeRoundedGlasses,
          ),
          LessonSpec(
            'Re-encode 5',
            'sharper images',
            HugeIcons.strokeRoundedPencilEdit02,
          ),
          LessonSpec(
            'Re-encode 10',
            'full restoration',
            HugeIcons.strokeRoundedRefresh,
          ),
          LessonSpec(
            'Archive exam',
            'crisp recall',
            HugeIcons.strokeRoundedCrown,
          ),
        ],
      ),
    ],
  ),
  ChapterSpec(
    memory: 3,
    realm: 'Grand Gallery',
    tagline: 'The gallery final: fast and focused.',
    tint: orange,
    sections: [
      SectionSpec(
        name: '30-image sprint',
        technique: 'volume encoding',
        icon: HugeIcons.strokeRoundedRocket,
        lessons: [
          LessonSpec(
            '15 images, 5 min',
            'steady pace',
            HugeIcons.strokeRoundedRocket,
          ),
          LessonSpec(
            '20 images, 5 min',
            'push the pace',
            HugeIcons.strokeRoundedStopWatch,
          ),
          LessonSpec(
            '30 images, 5 min',
            'final distance',
            HugeIcons.strokeRoundedFire,
          ),
          LessonSpec(
            'Sprint review',
            'steady recall',
            HugeIcons.strokeRoundedMedal01,
          ),
        ],
      ),
      SectionSpec(
        name: 'Abstract finals',
        technique: 'hard-pattern practice',
        icon: HugeIcons.strokeRoundedShapes,
        locked: true,
        lessons: [
          LessonSpec(
            '10 abstracts',
            'forced imagery',
            HugeIcons.strokeRoundedShapes,
          ),
          LessonSpec(
            '15 abstracts',
            'timed set',
            HugeIcons.strokeRoundedTimer01,
          ),
          LessonSpec(
            '20 abstracts',
            'hard set',
            HugeIcons.strokeRoundedPuzzle,
          ),
          LessonSpec(
            'Abstract review',
            'pattern set',
            HugeIcons.strokeRoundedMedal02,
          ),
        ],
      ),
      SectionSpec(
        name: 'Gallery review',
        technique: 'full-archive review',
        icon: HugeIcons.strokeRoundedTrophy,
        locked: true,
        lessons: [
          LessonSpec(
            '50 pictures',
            'full archive walk',
            HugeIcons.strokeRoundedImage01,
          ),
          LessonSpec(
            'Twins plus noise',
            'hostile gallery',
            HugeIcons.strokeRoundedShield01,
          ),
          LessonSpec(
            'Next-day recall',
            'sleep-tested',
            HugeIcons.strokeRoundedMoon01,
          ),
          LessonSpec(
            'Grand gallery',
            'full-archive review',
            HugeIcons.strokeRoundedTrophy,
          ),
        ],
      ),
    ],
  ),
  ChapterSpec(
    memory: 4,
    realm: 'Time Machine',
    tagline: 'Replay your week like a film.',
    tint: coral,
    sections: [
      SectionSpec(
        name: 'Week replay',
        technique: 'backward review',
        icon: HugeIcons.strokeRoundedCalendar01,
        lessons: [
          LessonSpec(
            '3 days back',
            'reverse order',
            HugeIcons.strokeRoundedCalendar01,
          ),
          LessonSpec(
            '5 days back',
            'full workweek',
            HugeIcons.strokeRoundedClock01,
          ),
          LessonSpec(
            '7 days back',
            'whole week',
            HugeIcons.strokeRoundedHourglass,
          ),
          LessonSpec(
            'Week exam',
            'no blank days',
            HugeIcons.strokeRoundedMedal01,
          ),
        ],
      ),
      SectionSpec(
        name: 'Timeline pegs',
        technique: 'dated anchors',
        icon: HugeIcons.strokeRoundedMapPin,
        locked: true,
        lessons: [
          LessonSpec(
            '5 dated pegs',
            'month anchors',
            HugeIcons.strokeRoundedMapPin,
          ),
          LessonSpec(
            '10 dated pegs',
            'year anchors',
            HugeIcons.strokeRoundedFlag01,
          ),
          LessonSpec(
            'Hang events on pegs',
            'dated recall',
            HugeIcons.strokeRoundedLink01,
          ),
          LessonSpec(
            'Timeline exam',
            'every date placed',
            HugeIcons.strokeRoundedFlag02,
          ),
        ],
      ),
      SectionSpec(
        name: 'Future rehearsal',
        technique: 'prospective memory',
        icon: HugeIcons.strokeRoundedBellRing,
        locked: true,
        lessons: [
          LessonSpec(
            '1 intention',
            'cue plus action',
            HugeIcons.strokeRoundedBellRing,
          ),
          LessonSpec(
            '3 intentions',
            'daily trio',
            HugeIcons.strokeRoundedCheckmarkCircle02,
          ),
          LessonSpec(
            '5 intentions',
            'a day of promises',
            HugeIcons.strokeRoundedTarget01,
          ),
          LessonSpec(
            'Promise exam',
            'nothing dropped',
            HugeIcons.strokeRoundedCrown,
          ),
        ],
      ),
    ],
  ),
  ChapterSpec(
    memory: 4,
    realm: 'Event Detective',
    tagline: 'Who said what, in which order.',
    tint: coral,
    sections: [
      SectionSpec(
        name: 'Detail drill',
        technique: 'fine episodic capture',
        icon: HugeIcons.strokeRoundedSearch01,
        lessons: [
          LessonSpec(
            'Room scan',
            'ten details',
            HugeIcons.strokeRoundedSearch01,
          ),
          LessonSpec(
            'Scene scan',
            'fifteen details',
            HugeIcons.strokeRoundedEye,
          ),
          LessonSpec(
            'Street scan',
            'twenty details',
            HugeIcons.strokeRoundedCompass,
          ),
          LessonSpec(
            'Detail exam',
            'careful recall',
            HugeIcons.strokeRoundedMedal01,
          ),
        ],
      ),
      SectionSpec(
        name: 'Conversation replay',
        technique: 'dialogue recall',
        icon: HugeIcons.strokeRoundedAiChat02,
        locked: true,
        lessons: [
          LessonSpec(
            'Who said it',
            'three speakers',
            HugeIcons.strokeRoundedAiChat02,
          ),
          LessonSpec(
            'Exact words',
            'key quotes',
            HugeIcons.strokeRoundedNote01,
          ),
          LessonSpec(
            'Long talk replay',
            'ten exchanges',
            HugeIcons.strokeRoundedMic01,
          ),
          LessonSpec(
            'Dialogue exam',
            'quoted moments',
            HugeIcons.strokeRoundedFlag01,
          ),
        ],
      ),
      SectionSpec(
        name: 'Order keeper',
        technique: 'sequence fidelity',
        icon: HugeIcons.strokeRoundedFlag01,
        locked: true,
        lessons: [
          LessonSpec(
            '5 steps in order',
            'no swaps',
            HugeIcons.strokeRoundedFlag01,
          ),
          LessonSpec(
            '8 steps in order',
            'long procedure',
            HugeIcons.strokeRoundedTimer01,
          ),
          LessonSpec(
            '12 steps in order',
            'full protocol',
            HugeIcons.strokeRoundedTarget01,
          ),
          LessonSpec(
            'Order exam',
            'steady sequence',
            HugeIcons.strokeRoundedCrown,
          ),
        ],
      ),
    ],
  ),
  ChapterSpec(
    memory: 4,
    realm: 'Dream Consolidator',
    tagline: 'Sleep on it — on purpose.',
    tint: coral,
    sections: [
      SectionSpec(
        name: 'Bedtime protocol',
        technique: 'pre-sleep review',
        icon: HugeIcons.strokeRoundedMoon01,
        lessons: [
          LessonSpec(
            'One palace nightly',
            'ten-minute walk',
            HugeIcons.strokeRoundedMoon01,
          ),
          LessonSpec(
            'Day replay nightly',
            'backwards film',
            HugeIcons.strokeRoundedBedDouble,
          ),
          LessonSpec(
            'Hard items last',
            'targeted review',
            HugeIcons.strokeRoundedTarget01,
          ),
          LessonSpec(
            'Protocol exam',
            'seven nights straight',
            HugeIcons.strokeRoundedMedal01,
          ),
        ],
      ),
      SectionSpec(
        name: 'Morning test',
        technique: 'sleep-gated recall',
        icon: HugeIcons.strokeRoundedClock01,
        locked: true,
        lessons: [
          LessonSpec(
            'Recall at wake',
            'before phone',
            HugeIcons.strokeRoundedClock01,
          ),
          LessonSpec(
            'Score the night',
            'kept vs lost',
            HugeIcons.strokeRoundedNote01,
          ),
          LessonSpec(
            'Relearn losses',
            'morning repair',
            HugeIcons.strokeRoundedRefresh,
          ),
          LessonSpec(
            'Morning exam',
            'sleep-proof recall',
            HugeIcons.strokeRoundedFlag01,
          ),
        ],
      ),
      SectionSpec(
        name: 'Weekly review',
        technique: 'expanding schedule',
        icon: HugeIcons.strokeRoundedNotebook02,
        locked: true,
        lessons: [
          LessonSpec(
            'Week 1 review',
            'first spacing',
            HugeIcons.strokeRoundedNotebook02,
          ),
          LessonSpec(
            'Month review',
            'long spacing',
            HugeIcons.strokeRoundedCalendar01,
          ),
          LessonSpec(
            'Season review',
            'durable archive',
            HugeIcons.strokeRoundedHourglass,
          ),
          LessonSpec(
            'Schedule exam',
            'nothing expires',
            HugeIcons.strokeRoundedCrown,
          ),
        ],
      ),
    ],
  ),
  ChapterSpec(
    memory: 4,
    realm: 'Life Archive',
    tagline: 'A month of your life, on demand.',
    tint: coral,
    sections: [
      SectionSpec(
        name: 'Month replay',
        technique: 'long-range autobiography',
        icon: HugeIcons.strokeRoundedNotebook01,
        lessons: [
          LessonSpec(
            '2 weeks back',
            'day by day',
            HugeIcons.strokeRoundedNotebook01,
          ),
          LessonSpec(
            '3 weeks back',
            'weekly highlights',
            HugeIcons.strokeRoundedCalendar01,
          ),
          LessonSpec(
            'Full month',
            'thirty days',
            HugeIcons.strokeRoundedHourglass,
          ),
          LessonSpec(
            'Month review',
            'full month',
            HugeIcons.strokeRoundedMedal01,
          ),
        ],
      ),
      SectionSpec(
        name: 'Milestone exam',
        technique: 'dated life events',
        icon: HugeIcons.strokeRoundedMedal01,
        locked: true,
        lessons: [
          LessonSpec(
            '5 milestones',
            'this year',
            HugeIcons.strokeRoundedMedal01,
          ),
          LessonSpec(
            '10 milestones',
            'dated and ordered',
            HugeIcons.strokeRoundedFlag01,
          ),
          LessonSpec(
            '20 milestones',
            'life chapters',
            HugeIcons.strokeRoundedBook01,
          ),
          LessonSpec(
            'Milestone final',
            'dated order',
            HugeIcons.strokeRoundedMedal02,
          ),
        ],
      ),
      SectionSpec(
        name: 'Life journal review',
        technique: 'journal review',
        icon: HugeIcons.strokeRoundedCrown,
        locked: true,
        lessons: [
          LessonSpec(
            'Any day, any detail',
            'random date drill',
            HugeIcons.strokeRoundedDice,
          ),
          LessonSpec(
            'Conversation quotes',
            'week-old quotes',
            HugeIcons.strokeRoundedAiChat02,
          ),
          LessonSpec(
            'Season in order',
            'ninety days',
            HugeIcons.strokeRoundedCalendar01,
          ),
          LessonSpec(
            'Life archive',
            'journal review',
            HugeIcons.strokeRoundedTrophy,
          ),
        ],
      ),
    ],
  ),
  ChapterSpec(
    memory: 5,
    realm: 'Face Gallery',
    tagline: 'Crowds of faces, practiced one by one.',
    tint: blueDark,
    sections: [
      SectionSpec(
        name: 'Crowd faces',
        technique: 'many-face encoding',
        icon: HugeIcons.strokeRoundedUserGroup,
        lessons: [
          LessonSpec(
            '6 faces, instant',
            'feature first',
            HugeIcons.strokeRoundedUserGroup,
          ),
          LessonSpec(
            '10 faces',
            'gallery round',
            HugeIcons.strokeRoundedFaceId,
          ),
          LessonSpec(
            '15 faces',
            'crowd round',
            HugeIcons.strokeRoundedUser,
          ),
          LessonSpec(
            'Crowd review',
            'names in place',
            HugeIcons.strokeRoundedMedal01,
          ),
        ],
      ),
      SectionSpec(
        name: 'Lookalikes',
        technique: 'fine face discrimination',
        icon: HugeIcons.strokeRoundedFaceMimic,
        locked: true,
        lessons: [
          LessonSpec(
            'Tell 2 apart',
            'one key feature',
            HugeIcons.strokeRoundedFaceMimic,
          ),
          LessonSpec(
            'Tell 4 apart',
            'feature matrix',
            HugeIcons.strokeRoundedEye,
          ),
          LessonSpec(
            'Tell 6 apart',
            'family reunion',
            HugeIcons.strokeRoundedUserGroup,
          ),
          LessonSpec(
            'Lookalike exam',
            'no swapped names',
            HugeIcons.strokeRoundedFlag01,
          ),
        ],
      ),
      SectionSpec(
        name: 'Delayed names',
        technique: 'durable face-name links',
        icon: HugeIcons.strokeRoundedHourglass,
        locked: true,
        lessons: [
          LessonSpec(
            '6 names, 5 min later',
            'coffee-break test',
            HugeIcons.strokeRoundedHourglass,
          ),
          LessonSpec(
            '10 names, 1 hour later',
            'delayed round',
            HugeIcons.strokeRoundedClock01,
          ),
          LessonSpec(
            '10 names, next day',
            'sleep-tested',
            HugeIcons.strokeRoundedMoon01,
          ),
          LessonSpec(
            'Delayed exam',
            'names that last',
            HugeIcons.strokeRoundedCrown,
          ),
        ],
      ),
    ],
  ),
  ChapterSpec(
    memory: 5,
    realm: 'Word Hoard',
    tagline: 'A hundred foreign words that stick.',
    tint: blueDark,
    sections: [
      SectionSpec(
        name: 'Root codes',
        technique: 'etymology pegs',
        icon: HugeIcons.strokeRoundedBook01,
        lessons: [
          LessonSpec(
            '10 Latin roots',
            'one image each',
            HugeIcons.strokeRoundedBook01,
          ),
          LessonSpec(
            '20 roots',
            'word families',
            HugeIcons.strokeRoundedLink01,
          ),
          LessonSpec(
            'Decode 15 words',
            'roots in the wild',
            HugeIcons.strokeRoundedSearch01,
          ),
          LessonSpec(
            'Root exam',
            'etymology instant',
            HugeIcons.strokeRoundedMedal01,
          ),
        ],
      ),
      SectionSpec(
        name: '50-word sprint',
        technique: 'keyword at speed',
        icon: HugeIcons.strokeRoundedTranslate,
        locked: true,
        lessons: [
          LessonSpec(
            '15 words, 10 min',
            'steady keywords',
            HugeIcons.strokeRoundedTranslate,
          ),
          LessonSpec(
            '30 words, 10 min',
            'push the pace',
            HugeIcons.strokeRoundedTimer01,
          ),
          LessonSpec(
            '50 words, 15 min',
            'full sprint',
            HugeIcons.strokeRoundedFire,
          ),
          LessonSpec(
            'Sprint exam',
            'both directions',
            HugeIcons.strokeRoundedFlag01,
          ),
        ],
      ),
      SectionSpec(
        name: 'Two-way chains',
        technique: 'bidirectional recall',
        icon: HugeIcons.strokeRoundedChatTranslate,
        locked: true,
        lessons: [
          LessonSpec(
            '10 words both ways',
            'there and back',
            HugeIcons.strokeRoundedChatTranslate,
          ),
          LessonSpec(
            '20 words both ways',
            'both directions',
            HugeIcons.strokeRoundedRefresh,
          ),
          LessonSpec(
            '30 words shuffled',
            'random order',
            HugeIcons.strokeRoundedDice,
          ),
          LessonSpec(
            'Chain exam',
            'steady both ways',
            HugeIcons.strokeRoundedCrown,
          ),
        ],
      ),
    ],
  ),
  ChapterSpec(
    memory: 5,
    realm: 'Knowledge Web',
    tagline: 'Facts, speeches, numbers — structured.',
    tint: blueDark,
    sections: [
      SectionSpec(
        name: 'Fact palaces',
        technique: 'structured loci',
        icon: HugeIcons.strokeRoundedBrain01,
        lessons: [
          LessonSpec(
            '10 facts filed',
            'one room of facts',
            HugeIcons.strokeRoundedBrain01,
          ),
          LessonSpec(
            '20 facts filed',
            'two rooms',
            HugeIcons.strokeRoundedHome01,
          ),
          LessonSpec(
            '30 facts filed',
            'full palace',
            HugeIcons.strokeRoundedCastle01,
          ),
          LessonSpec(
            'Facts exam',
            'any fact, instant',
            HugeIcons.strokeRoundedMedal01,
          ),
        ],
      ),
      SectionSpec(
        name: 'Speech skeletons',
        technique: 'talk loci',
        icon: HugeIcons.strokeRoundedMic01,
        locked: true,
        lessons: [
          LessonSpec(
            '5-point talk',
            'no notes',
            HugeIcons.strokeRoundedMic01,
          ),
          LessonSpec(
            '10-point talk',
            'ordered skeleton',
            HugeIcons.strokeRoundedNote01,
          ),
          LessonSpec(
            '15-minute talk',
            'full keynote',
            HugeIcons.strokeRoundedTimer01,
          ),
          LessonSpec(
            'Keynote exam',
            'stage-ready',
            HugeIcons.strokeRoundedFlag01,
          ),
        ],
      ),
      SectionSpec(
        name: 'Number facts',
        technique: 'pegged quantities',
        icon: HugeIcons.strokeRoundedCalculator01,
        locked: true,
        lessons: [
          LessonSpec(
            '5 dates',
            'history pegs',
            HugeIcons.strokeRoundedCalculator01,
          ),
          LessonSpec(
            '10 constants',
            'science pegs',
            HugeIcons.strokeRoundedAtom01,
          ),
          LessonSpec(
            '15 figures',
            'mixed quantities',
            HugeIcons.strokeRoundedHashtag,
          ),
          LessonSpec(
            'Figures review',
            'steady accuracy',
            HugeIcons.strokeRoundedCrown,
          ),
        ],
      ),
    ],
  ),
  ChapterSpec(
    memory: 5,
    realm: 'Name Hall',
    tagline: 'Timed names and words, at your best pace.',
    tint: blueDark,
    sections: [
      SectionSpec(
        name: 'Name sprint',
        technique: 'timed face-name rounds',
        icon: HugeIcons.strokeRoundedFaceId,
        lessons: [
          LessonSpec(
            '10 names, 5 min',
            'steady 3-step',
            HugeIcons.strokeRoundedFaceId,
          ),
          LessonSpec(
            '15 names, 5 min',
            'brisk pace',
            HugeIcons.strokeRoundedTimer01,
          ),
          LessonSpec(
            '20 names, 5 min',
            'final distance',
            HugeIcons.strokeRoundedFire,
          ),
          LessonSpec(
            'Name sprint review',
            'clean sheet',
            HugeIcons.strokeRoundedMedal01,
          ),
        ],
      ),
      SectionSpec(
        name: 'Word blitz',
        technique: 'timed word rounds',
        icon: HugeIcons.strokeRoundedBook04,
        locked: true,
        lessons: [
          LessonSpec(
            '20 words, 5 min',
            'keyword blitz',
            HugeIcons.strokeRoundedBook04,
          ),
          LessonSpec(
            '30 words, 5 min',
            'chained fast',
            HugeIcons.strokeRoundedLink01,
          ),
          LessonSpec(
            '50 words, 15 min',
            'long round',
            HugeIcons.strokeRoundedTrophy,
          ),
          LessonSpec(
            'Blitz review',
            'careful recall',
            HugeIcons.strokeRoundedMedal02,
          ),
        ],
      ),
      SectionSpec(
        name: 'Final review',
        technique: 'mixed names + words review',
        icon: HugeIcons.strokeRoundedTrophy,
        locked: true,
        lessons: [
          LessonSpec(
            'Names plus words',
            'mixed final',
            HugeIcons.strokeRoundedPuzzle,
          ),
          LessonSpec(
            'Delayed final',
            'recall next day',
            HugeIcons.strokeRoundedMoon01,
          ),
          LessonSpec(
            'Noisy final',
            'with distractions',
            HugeIcons.strokeRoundedShield01,
          ),
          LessonSpec(
            'Name hall',
            'mixed names + words review',
            HugeIcons.strokeRoundedTrophy,
          ),
        ],
      ),
    ],
  ),
  ChapterSpec(
    memory: 0,
    realm: 'Street Ears',
    tagline: 'Real voices, real rooms, your own lists.',
    tint: sky,
    sections: [
      SectionSpec(
        name: 'Live voices',
        technique: 'real introductions practice',
        icon: HugeIcons.strokeRoundedEar,
        lessons: [
          LessonSpec(
            '3 live names',
            'at real meetings',
            HugeIcons.strokeRoundedEar,
          ),
          LessonSpec(
            '5 live names',
            'spelling asked',
            HugeIcons.strokeRoundedUser,
          ),
          LessonSpec(
            'Noisy greetings',
            'with chatter on',
            HugeIcons.strokeRoundedShield01,
          ),
          LessonSpec(
            'Voices review',
            'next-day check',
            HugeIcons.strokeRoundedFlag01,
          ),
        ],
      ),
      SectionSpec(
        name: 'Own errands',
        technique: 'heard lists aloud',
        icon: HugeIcons.strokeRoundedMic01,
        locked: true,
        lessons: [
          LessonSpec(
            '4 errands heard',
            'said back once',
            HugeIcons.strokeRoundedMic01,
          ),
          LessonSpec(
            '6 errands heard',
            'rhythm grouped',
            HugeIcons.strokeRoundedAudioWave01,
          ),
          LessonSpec(
            'Errands in noise',
            'street recall',
            HugeIcons.strokeRoundedShield01,
          ),
          LessonSpec(
            'Errands review',
            'sealed-list check',
            HugeIcons.strokeRoundedFlag01,
          ),
        ],
      ),
      SectionSpec(
        name: 'Evening sounds',
        technique: 'day replay habit',
        icon: HugeIcons.strokeRoundedMoon01,
        locked: true,
        lessons: [
          LessonSpec(
            'Tonight replay',
            '3 hard sounds',
            HugeIcons.strokeRoundedMoon01,
          ),
          LessonSpec(
            '3-evening run',
            'notes kept',
            HugeIcons.strokeRoundedNotebook01,
          ),
          LessonSpec(
            'Week replay',
            'day 1 again',
            HugeIcons.strokeRoundedRefresh,
          ),
          LessonSpec(
            'Sounds review',
            'steady recall',
            HugeIcons.strokeRoundedFlag01,
          ),
        ],
      ),
    ],
  ),
  ChapterSpec(
    memory: 1,
    realm: 'Number Field',
    tagline: 'Real numbers you actually need.',
    tint: blue,
    sections: [
      SectionSpec(
        name: 'Real numbers',
        technique: 'chunked phone codes',
        icon: HugeIcons.strokeRoundedCalculator01,
        lessons: [
          LessonSpec(
            '1 number owned',
            'dialed from memory',
            HugeIcons.strokeRoundedCalculator01,
          ),
          LessonSpec(
            '2 numbers owned',
            'morning recall',
            HugeIcons.strokeRoundedHashtag,
          ),
          LessonSpec(
            'Long number',
            'three-chunk scene',
            HugeIcons.strokeRoundedGrid3x3,
          ),
          LessonSpec(
            'Numbers review',
            'week-later check',
            HugeIcons.strokeRoundedFlag01,
          ),
        ],
      ),
      SectionSpec(
        name: 'Shopping runs',
        technique: 'sealed-list shops',
        icon: HugeIcons.strokeRoundedHashtag,
        locked: true,
        lessons: [
          LessonSpec(
            '4 items sealed',
            'pocket check',
            HugeIcons.strokeRoundedHashtag,
          ),
          LessonSpec(
            '8 items sealed',
            'till recall',
            HugeIcons.strokeRoundedLayers01,
          ),
          LessonSpec(
            'Mixed errands',
            'backwards check',
            HugeIcons.strokeRoundedRefresh,
          ),
          LessonSpec(
            'Shopping review',
            'fresh list',
            HugeIcons.strokeRoundedFlag01,
          ),
        ],
      ),
      SectionSpec(
        name: 'Dates kept',
        technique: 'face-linked dates',
        icon: HugeIcons.strokeRoundedTimer01,
        locked: true,
        lessons: [
          LessonSpec(
            '2 dates fixed',
            'photo cues',
            HugeIcons.strokeRoundedTimer01,
          ),
          LessonSpec(
            '5 dates fixed',
            'evening recall',
            HugeIcons.strokeRoundedNotebook01,
          ),
          LessonSpec(
            'Random quiz',
            'asked by friend',
            HugeIcons.strokeRoundedUser,
          ),
          LessonSpec(
            'Dates review',
            'month-later check',
            HugeIcons.strokeRoundedFlag01,
          ),
        ],
      ),
    ],
  ),
  ChapterSpec(
    memory: 2,
    realm: 'Two Palaces',
    tagline: 'Your rooms, your routes, your lists.',
    tint: teal,
    sections: [
      SectionSpec(
        name: 'Home route',
        technique: 'own 10 stations',
        icon: HugeIcons.strokeRoundedHome01,
        lessons: [
          LessonSpec(
            '10 stations set',
            'door to bedroom',
            HugeIcons.strokeRoundedHome01,
          ),
          LessonSpec(
            '10 words placed',
            'one scene each',
            HugeIcons.strokeRoundedCastle01,
          ),
          LessonSpec(
            'Blind walk',
            'next morning',
            HugeIcons.strokeRoundedEye,
          ),
          LessonSpec(
            'Home review',
            'misses re-walked',
            HugeIcons.strokeRoundedFlag01,
          ),
        ],
      ),
      SectionSpec(
        name: 'Street route',
        technique: 'own 15 stations',
        icon: HugeIcons.strokeRoundedCastle01,
        locked: true,
        lessons: [
          LessonSpec(
            '15 spots picked',
            'sharp and distinct',
            HugeIcons.strokeRoundedCastle01,
          ),
          LessonSpec(
            '15 items placed',
            'study or work',
            HugeIcons.strokeRoundedNotebook01,
          ),
          LessonSpec(
            'Forward recall',
            'no jumping',
            HugeIcons.strokeRoundedFlag01,
          ),
          LessonSpec(
            'Street review',
            'fresh 15',
            HugeIcons.strokeRoundedRefresh,
          ),
        ],
      ),
      SectionSpec(
        name: 'Two routes',
        technique: 'own 20-item lists',
        icon: HugeIcons.strokeRoundedFlag01,
        locked: true,
        lessons: [
          LessonSpec(
            '20 split placed',
            '10 plus 10',
            HugeIcons.strokeRoundedLayers01,
          ),
          LessonSpec(
            'Evening walk',
            'both routes',
            HugeIcons.strokeRoundedMoon01,
          ),
          LessonSpec(
            'Morning recall',
            'written from memory',
            HugeIcons.strokeRoundedNotebook01,
          ),
          LessonSpec(
            'Routes review',
            'taught once',
            HugeIcons.strokeRoundedUser,
          ),
        ],
      ),
    ],
  ),
  ChapterSpec(
    memory: 3,
    realm: 'Daily Images',
    tagline: 'Work and study, pictured.',
    tint: orange,
    sections: [
      SectionSpec(
        name: 'Work pictures',
        technique: 'abstract to image',
        icon: HugeIcons.strokeRoundedEye,
        lessons: [
          LessonSpec(
            '4 tasks pictured',
            'big and moving',
            HugeIcons.strokeRoundedEye,
          ),
          LessonSpec(
            '6 tasks pictured',
            'corners attached',
            HugeIcons.strokeRoundedGrid3x3,
          ),
          LessonSpec(
            'Noon recall',
            'list checked',
            HugeIcons.strokeRoundedTimer01,
          ),
          LessonSpec(
            'Tasks review',
            'fresh 6',
            HugeIcons.strokeRoundedFlag01,
          ),
        ],
      ),
      SectionSpec(
        name: 'Photo holds',
        technique: 'next-day details',
        icon: HugeIcons.strokeRoundedBook04,
        locked: true,
        lessons: [
          LessonSpec(
            '6 details named',
            'one photo',
            HugeIcons.strokeRoundedBook04,
          ),
          LessonSpec(
            'Exaggerated tags',
            'twins apart',
            HugeIcons.strokeRoundedTarget01,
          ),
          LessonSpec(
            'Next-day rebuild',
            'no peeking',
            HugeIcons.strokeRoundedMoon01,
          ),
          LessonSpec(
            'Photo review',
            'fresh photo',
            HugeIcons.strokeRoundedRefresh,
          ),
        ],
      ),
      SectionSpec(
        name: 'Meeting strips',
        technique: 'linked point images',
        icon: HugeIcons.strokeRoundedFlag01,
        locked: true,
        lessons: [
          LessonSpec(
            '3 points linked',
            'small actions',
            HugeIcons.strokeRoundedLink01,
          ),
          LessonSpec(
            '5 points linked',
            'full strip',
            HugeIcons.strokeRoundedNotebook01,
          ),
          LessonSpec(
            'Morning replay',
            'minutes checked',
            HugeIcons.strokeRoundedMoon01,
          ),
          LessonSpec(
            'Strips review',
            'fresh meeting',
            HugeIcons.strokeRoundedFlag01,
          ),
        ],
      ),
    ],
  ),
  ChapterSpec(
    memory: 4,
    realm: 'Week Replay',
    tagline: 'Stories and evenings, kept.',
    tint: coral,
    sections: [
      SectionSpec(
        name: 'Day chains',
        technique: 'one-chain stories',
        icon: HugeIcons.strokeRoundedNotebook01,
        lessons: [
          LessonSpec(
            '6 terms chained',
            'single adventure',
            HugeIcons.strokeRoundedNotebook01,
          ),
          LessonSpec(
            '10 terms chained',
            'retold aloud',
            HugeIcons.strokeRoundedMic01,
          ),
          LessonSpec(
            'Next-day retell',
            'misses noted',
            HugeIcons.strokeRoundedMoon01,
          ),
          LessonSpec(
            'Chains review',
            'fresh 10',
            HugeIcons.strokeRoundedFlag01,
          ),
        ],
      ),
      SectionSpec(
        name: 'Evening log',
        technique: '7-night replay',
        icon: HugeIcons.strokeRoundedMoon01,
        locked: true,
        lessons: [
          LessonSpec(
            'Tonight backwards',
            'scene by scene',
            HugeIcons.strokeRoundedMoon01,
          ),
          LessonSpec(
            '3 nights logged',
            'hard recalls',
            HugeIcons.strokeRoundedNotebook01,
          ),
          LessonSpec(
            '7 nights logged',
            'week held',
            HugeIcons.strokeRoundedFlag01,
          ),
          LessonSpec(
            'Log review',
            'day 1 from cues',
            HugeIcons.strokeRoundedRefresh,
          ),
        ],
      ),
      SectionSpec(
        name: 'Retold aloud',
        technique: 'single-reading retells',
        icon: HugeIcons.strokeRoundedMic01,
        locked: true,
        lessons: [
          LessonSpec(
            'One article once',
            'movie-like read',
            HugeIcons.strokeRoundedBook04,
          ),
          LessonSpec(
            'Evening retell',
            'to one listener',
            HugeIcons.strokeRoundedUser,
          ),
          LessonSpec(
            'Next-day retell',
            'skips compared',
            HugeIcons.strokeRoundedMoon01,
          ),
          LessonSpec(
            'Retell review',
            'fresh article',
            HugeIcons.strokeRoundedFlag01,
          ),
        ],
      ),
    ],
  ),
  ChapterSpec(
    memory: 5,
    realm: 'Names Out',
    tagline: 'Real names, real words, real talks.',
    tint: blueDark,
    sections: [
      SectionSpec(
        name: 'Live names',
        technique: '3-step at events',
        icon: HugeIcons.strokeRoundedFaceId,
        lessons: [
          LessonSpec(
            '3 event names',
            'feature first',
            HugeIcons.strokeRoundedFaceId,
          ),
          LessonSpec(
            '5 event names',
            'hooks stuck',
            HugeIcons.strokeRoundedUser,
          ),
          LessonSpec(
            'Greeted by name',
            'two hellos',
            HugeIcons.strokeRoundedMic01,
          ),
          LessonSpec(
            'Names review',
            'next-day list',
            HugeIcons.strokeRoundedFlag01,
          ),
        ],
      ),
      SectionSpec(
        name: 'Word weeks',
        technique: 'keyword daily pairs',
        icon: HugeIcons.strokeRoundedBook04,
        locked: true,
        lessons: [
          LessonSpec(
            '2 words daily',
            'both directions',
            HugeIcons.strokeRoundedBook04,
          ),
          LessonSpec(
            '10 words held',
            'week quiz',
            HugeIcons.strokeRoundedFlag01,
          ),
          LessonSpec(
            '20 words held',
            'shuffled test',
            HugeIcons.strokeRoundedRefresh,
          ),
          LessonSpec(
            'Words review',
            'misses retested',
            HugeIcons.strokeRoundedMoon01,
          ),
        ],
      ),
      SectionSpec(
        name: 'Talks plus facts',
        technique: 'skeleton plus rooms',
        icon: HugeIcons.strokeRoundedMic01,
        locked: true,
        lessons: [
          LessonSpec(
            '3-point update',
            'no notes',
            HugeIcons.strokeRoundedMic01,
          ),
          LessonSpec(
            '5-point talk',
            'listener check',
            HugeIcons.strokeRoundedUser,
          ),
          LessonSpec(
            '10 facts filed',
            'own study',
            HugeIcons.strokeRoundedBrain01,
          ),
          LessonSpec(
            'Talks review',
            'stations called',
            HugeIcons.strokeRoundedFlag01,
          ),
        ],
      ),
    ],
  ),
];

LessonSpec lessonFromMetaTask(MetaTask task) {
  final title = task.prompt.isEmpty ? 'Meta drill' : task.prompt;
  final detail = task.explanation.isEmpty ? 'AI practice' : task.explanation;
  return LessonSpec(title, detail, HugeIcons.strokeRoundedBrain01);
}
