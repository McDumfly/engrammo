/// Research-backed drill builders for spatial (loci) and visual (picture)
/// lessons, plus the SAM-label merge used by the spatial track.
///
/// Every builder here is a pure function with an offline local fallback,
/// so lessons teach the same validated technique with or without an API
/// key. Live Meta models only enrich the stimulus:
///
/// - spatial: Muse Image draws the palace scene, SAM 3.1 segments it into
///   ordered stations ([stationsFromLabels]), Spark (or the local pool)
///   supplies the words to place. Paradigm: method of loci
///   (Maguire et al. 2003; Dresler et al. 2017; Wagner et al. 2021).
/// - visual: Muse Image draws the scene, recall probes a detail.
///   Paradigm: picture recognition / picture superiority
///   (Shepard 1967; Standing 1973; Paivio dual-coding theory).
///
/// Bibliography: `docs/RESEARCH.md` sections 1-2.
library;

import 'dart:math';

import 'meta_task.dart';

/// Familiar, fixed-order routes with distinct stations.
///
/// Loci must be well known in advance, strictly ordered and mutually
/// distinct — similar stations interfere with each other (distinctiveness
/// principle; Krokos et al. VR palace study). Home and street routes are
/// the classic instruction (Dresler et al. 2017 trained on familiar
/// routes first).
const palaceRoutes = <String, List<String>>{
  'home': [
    'front door',
    'hallway mirror',
    'coat rack',
    'living-room couch',
    'reading lamp',
    'bookshelf',
    'kitchen stove',
    'kitchen table',
    'bedroom bed',
    'bathroom sink',
  ],
  'street': [
    'garden gate',
    'bus stop',
    'bakery window',
    'corner fountain',
    'old oak tree',
    'library steps',
    'market stall',
    'church door',
    'bridge railing',
    'schoolyard fence',
  ],
  'park': [
    'park entrance',
    'rose bed',
    'stone bench',
    'duck pond',
    'wooden bridge',
    'picnic table',
    'playground swing',
    'tall pine',
    'drinking fountain',
    'glass pavilion',
  ],
};

/// Highly imageable concrete nouns (dual-coding friendly: every word
/// gets a visual plus a verbal code, Paivio). Short everyday words keep
/// encoding time per station near the recommended ~10 seconds.
const concreteNouns = <String>[
  'apple',
  'hammer',
  'candle',
  'bridge',
  'garden',
  'lamp',
  'ocean',
  'key',
  'tiger',
  'violin',
  'castle',
  'rocket',
  'mirror',
  'compass',
  'dragon',
  'piano',
  'anchor',
  'balloon',
  'crown',
  'diamond',
  'eagle',
  'fountain',
  'globe',
  'harbor',
  'island',
  'jungle',
  'lantern',
  'mountain',
  'needle',
  'orchard',
  'pyramid',
  'quilt',
  'rainbow',
  'saddle',
  'temple',
  'umbrella',
  'volcano',
  'windmill',
  'yacht',
  'zeppelin',
];

/// Everyday scenes for the picture-recall drill. Each scene lists
/// plausible elements; the probe asks recognition ("which was in the
/// scene?"), the same paradigm as Shepard (1967) and Standing (1973),
/// who showed thousands of pictures are recognized after a single
/// viewing. One element per scene is deliberately distinctive
/// (Von Restorff 1933 isolation effect) and becomes the queried target
/// more often at higher difficulty.
const pictureScenes = <String, List<String>>{
  'morning kitchen': [
    'kettle',
    'toast',
    'cat on the chair',
    'blue mug',
    'window plant',
    'wall clock',
  ],
  'street market': [
    'apple cart',
    'striped awning',
    'brass scale',
    'flower buckets',
    'crying baby',
    'pigeons',
  ],
  'quiet beach': [
    'red sailboat',
    'sandcastle',
    'striped towel',
    'seagull',
    'ice-cream cart',
    'lighthouse',
  ],
  'old library': [
    'spiral staircase',
    'green lamp',
    'globe',
    'sleeping dog',
    'dusty atlas',
    'oak desk',
  ],
  'mountain cabin': [
    'fireplace',
    'bear rug',
    'lantern',
    'snowshoes',
    'hot soup',
    'wooden beams',
  ],
  'city park': [
    'fountain',
    'chess players',
    'balloon seller',
    'stone bench',
    'squirrels',
    'brass band',
  ],
  'train station': [
    'departure board',
    'red suitcase',
    'coffee kiosk',
    'pigeon flock',
    'ticket gate',
    'sleeping traveler',
  ],
  'greenhouse': [
    'orchids',
    'watering can',
    'hanging ferns',
    'tortoise',
    'glass roof',
    'herb beds',
  ],
};

/// Number of items a drill of [difficulty] (1..5) probes.
///
/// 4 items at difficulty 1 up to 8 at difficulty 5: starts inside the
/// ~4-chunk working-memory window (Cowan 2001) and grows toward the
/// lab milestone lists (Dresler et al. 2017), keeping success near the
/// ~85% difficulty sweet spot (Wilson et al. 2019).
int drillItemCount(int difficulty) => 3 + difficulty.clamp(1, 5);

int _seedHash(String seed) {
  var h = 0x811c9dc5;
  for (final c in seed.codeUnits) {
    h ^= c;
    h = (h * 0x01000193) & 0xffffffff;
  }
  return h;
}

/// Route name picked deterministically from [seed].
String routeForSeed(String seed) {
  final names = palaceRoutes.keys.toList();
  return names[_seedHash('route:$seed') % names.length];
}

/// Scene name picked deterministically from [seed].
String sceneForSeed(String seed) {
  final names = pictureScenes.keys.toList();
  return names[_seedHash('scene:$seed') % names.length];
}

/// Ordered, distinct loci for a drill: first [count] stations of the
/// seeded route. Order is fixed — loci are always walked, never jumped.
List<String> localStations(String seed, int count) {
  final route = palaceRoutes[routeForSeed(seed)]!;
  return route.take(count.clamp(1, route.length)).toList();
}

/// Concrete nouns for a drill, shuffled by [seed], no repeats.
List<String> localDrillWords(String seed, int count) {
  final pool = List<String>.of(concreteNouns)
    ..shuffle(Random(_seedHash('words:$seed')));
  return pool.take(count.clamp(1, pool.length)).toList();
}

/// Merges SAM 3.1 segment labels over the local route.
///
/// Live labels come first (deduped, trimmed, empties dropped) so a real
/// segmentation of the palace image defines the walk; missing slots are
/// filled from the familiar local route. The result is always ordered,
/// distinct and exactly [count] long — the three properties loci need.
List<String> stationsFromLabels(
  List<String> labels,
  String seed,
  int count,
) {
  final n = count.clamp(1, 10);
  final merged = <String>[];
  for (final raw in labels) {
    final label = raw.trim();
    if (label.isEmpty || merged.contains(label)) continue;
    merged.add(label);
    if (merged.length >= n) break;
  }
  if (merged.length < n) {
    for (final station in localStations(seed, 10)) {
      if (merged.contains(station)) continue;
      merged.add(station);
      if (merged.length >= n) break;
    }
  }
  return merged;
}

/// Prompt for the Muse palace illustration of [routeName].
String palaceImagePrompt(String routeName, int difficulty) {
  final stations = palaceRoutes[routeName] ?? palaceRoutes['home']!;
  final n = drillItemCount(difficulty);
  return 'Cozy memory-palace illustration of a $routeName walk with '
      '${stations.take(n).join(', ')} as clearly separated, numbered '
      'stations in walking order, warm light, storybook style';
}

/// Prompt for the Muse illustration of [sceneName].
String pictureImagePrompt(String sceneName) {
  final elements = pictureScenes[sceneName] ?? const <String>[];
  return 'Vivid, detailed illustration of a $sceneName showing '
      '${elements.take(5).join(', ')}, storybook style, sharp details';
}

/// Local method-of-loci drill: place one word per station, in order,
/// then recall which word sits at one station.
///
/// Stimulus: station → word pairs. Probe: cued recall at a single
/// station with 4 options (1 placed + 3 lures from the same pool).
/// This is the Dresler et al. (2017) training loop in miniature:
/// encode on a timed walk, retrieve by walking, correct immediately.
MetaTask localPalaceTask({required int difficulty, required String seed}) {
  final n = drillItemCount(difficulty);
  final route = routeForSeed(seed);
  final stations = localStations(seed, n);
  final words = localDrillWords(seed, n);
  final rnd = Random(_seedHash('target:$seed'));
  final target = rnd.nextInt(n);
  final targetWord = words[target];
  final lures = List<String>.of(concreteNouns)..shuffle(rnd);
  final options = <String>[targetWord];
  for (final lure in lures) {
    if (options.length >= 4) break;
    if (!words.contains(lure)) options.add(lure);
  }
  options.shuffle(rnd);
  return MetaTask(
    prompt: 'Walk your $route palace — one image per station!',
    items: List<String>.of(words),
    stations: stations,
    question: 'What did you place at the ${stations[target]}?',
    options: options,
    correct: options.indexOf(targetWord),
    explanation:
        'Loci: one bizarre, moving image per station, always in walking '
        'order. Champions memorize with this exact method — 6 weeks of '
        'training rewires beginner brains toward the athlete pattern. '
        '(Maguire et al. 2003; Dresler et al. 2017)',
    paradigm: 'loci-drill',
    source: 'Maguire et al. 2003; Dresler et al. 2017',
    createdAt: DateTime.now(),
  );
}

/// Local picture-recall drill: study a scene, then recognize one of
/// its elements among lures from other scenes.
///
/// Recognition-after-one-viewing is the Shepard (1967) / Standing
/// (1973) paradigm: even thousands of pictures stick. The drill trains
/// the encoding side — naming details instantly so each gets a verbal
/// plus a visual code (Paivio dual-coding theory).
MetaTask localPictureTask({required int difficulty, required String seed}) {
  final n = drillItemCount(difficulty);
  final scene = sceneForSeed(seed);
  final present = List<String>.of(pictureScenes[scene]!.take(n));
  final rnd = Random(_seedHash('target:$seed'));
  final target = present[rnd.nextInt(present.length)];
  final lurePool = <String>[
    for (final entry in pictureScenes.entries)
      if (entry.key != scene) ...entry.value,
  ]..shuffle(rnd);
  final options = <String>[target];
  for (final lure in lurePool) {
    if (options.length >= 4) break;
    if (!present.contains(lure)) options.add(lure);
  }
  options.shuffle(rnd);
  return MetaTask(
    prompt: 'Study this $scene — name every detail!',
    items: present,
    question: 'Which of these was in the $scene?',
    options: options,
    correct: options.indexOf(target),
    explanation:
        'Pictures get two memory codes (visual + verbal) instead of one, '
        'and distinctive details pop out of memory. Name what you see '
        'instantly — words anchor pictures. '
        '(Shepard 1967; Standing 1973; Von Restorff 1933)',
    paradigm: 'picture-recall',
    source: 'Shepard 1967; Standing 1973; Paivio dual-coding',
    createdAt: DateTime.now(),
  );
}
