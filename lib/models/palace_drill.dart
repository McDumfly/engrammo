library;

import 'dart:math';

import '../l10n/app_localizations.dart';
import 'item_banks.dart'
    show extraConcreteNounsFor, extraPictureScenesFor, isHuLocale;
import 'meta_task.dart';

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

Map<String, List<String>> palaceRoutesFor([String locale = 'en']) =>
    isHuLocale(locale) ? palaceRoutesHu : palaceRoutes;

const palaceRoutesHu = <String, List<String>>{
  'otthon': [
    'bejárati ajtó',
    'előszobatükör',
    'fogas',
    'nappali kanapé',
    'olvasólámpa',
    'könyvespolc',
    'konyhai tűzhely',
    'konyhaasztal',
    'hálószobai ágy',
    'fürdőszobai mosdó',
  ],
  'utca': [
    'kertkapu',
    'buszmegálló',
    'pékségkirakat',
    'sarki szökőkút',
    'öreg tölgy',
    'könyvtárlépcső',
    'piaci bódé',
    'templomajtó',
    'hídkorlát',
    'iskolaudvari kerítés',
  ],
  'park': [
    'parkbejárat',
    'rózsaágyás',
    'kőpad',
    'kacsástó',
    'fahíd',
    'piknikasztal',
    'játszótéri hinta',
    'magas fenyő',
    'ivókút',
    'üvegpavilon',
  ],
};

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

List<String> concreteNounsFor([String locale = 'en']) =>
    isHuLocale(locale) ? concreteNounsHu : concreteNouns;

const concreteNounsHu = <String>[
  'alma',
  'kalapács',
  'gyertya',
  'híd',
  'kert',
  'lámpa',
  'óceán',
  'kulcs',
  'tigris',
  'hegedű',
  'vár',
  'rakéta',
  'tükör',
  'iránytű',
  'sárkány',
  'zongora',
  'horgony',
  'léggömb',
  'korona',
  'gyémánt',
  'sas',
  'szökőkút',
  'földgömb',
  'kikötő',
  'sziget',
  'dzsungel',
  'lámpás',
  'hegy',
  'tű',
  'gyümölcsös',
  'piramis',
  'paplan',
  'szivárvány',
  'nyereg',
  'templom',
  'esernyő',
  'vulkán',
  'szélmalom',
  'jacht',
  'zeppelin',
];

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

Map<String, List<String>> pictureScenesFor([String locale = 'en']) =>
    isHuLocale(locale) ? pictureScenesHu : pictureScenes;

const pictureScenesHu = <String, List<String>>{
  'reggeli konyha': [
    'teáskanna',
    'pirítós',
    'macska a széken',
    'kék bögre',
    'ablaki növény',
    'fali óra',
  ],
  'utcai piac': [
    'almáskocsi',
    'csíkos napellenző',
    'rézmérleg',
    'virágosvödrök',
    'síró kisbaba',
    'galambok',
  ],
  'csendes tengerpart': [
    'piros vitorlás',
    'homokvár',
    'csíkos törölköző',
    'sirály',
    'fagylaltoskocsi',
    'világítótorony',
  ],
  'régi könyvtár': [
    'csigalépcső',
    'zöld lámpa',
    'földgömb',
    'alvó kutya',
    'poros atlasz',
    'tölgyfa íróasztal',
  ],
  'hegyi kunyhó': [
    'kandalló',
    'medvebőr szőnyeg',
    'lámpás',
    'hótalp',
    'forró leves',
    'fagerendák',
  ],
  'városi park': [
    'szökőkút',
    'sakkozók',
    'léggömbárus',
    'kőpad',
    'mókusok',
    'rézfúvós zenekar',
  ],
  'pályaudvar': [
    'indulási tábla',
    'piros bőrönd',
    'kávésbódé',
    'galambcsapat',
    'jegykapu',
    'alvó utas',
  ],
  'üvegház': [
    'orchideák',
    'öntözőkanna',
    'függő páfrányok',
    'teknős',
    'üvegtető',
    'fűszerágyások',
  ],
};

int drillItemCount(int difficulty) => 3 + difficulty.clamp(1, 5);

/// Case/accent-insensitive recall matching: `Kék Bögre` equals
/// `kek bogre`. Used by the SAM mask game, where the player types what
/// the black masks hide.
String normalizeRecallAnswer(String s) {
  const accents = {
    'á': 'a', 'à': 'a', 'â': 'a', 'ä': 'a', 'ã': 'a', 'å': 'a',
    'é': 'e', 'è': 'e', 'ê': 'e', 'ë': 'e',
    'í': 'i', 'ì': 'i', 'î': 'i', 'ï': 'i',
    'ó': 'o', 'ò': 'o', 'ô': 'o', 'ö': 'o', 'ő': 'o', 'õ': 'o', 'ø': 'o',
    'ú': 'u', 'ù': 'u', 'û': 'u', 'ü': 'u', 'ű': 'u',
    'ý': 'y', 'ÿ': 'y',
    'ç': 'c', 'č': 'c', 'ć': 'c',
    'ñ': 'n', 'ň': 'n',
    'š': 's', 'ş': 's', 'ß': 'ss',
    'ž': 'z', 'ź': 'z', 'ż': 'z',
    'đ': 'd', 'ď': 'd',
    'ğ': 'g', 'ł': 'l', 'ř': 'r', 'ţ': 't', 'þ': 'th',
  };
  final lower = s.toLowerCase().trim().replaceAll(RegExp(r'\s+'), ' ');
  return String.fromCharCodes([
    for (final c in lower.runes) ...(accents[String.fromCharCode(c)] ?? String.fromCharCode(c)).runes,
  ]);
}

/// Returns the index of the first unrevealed candidate matching [input],
/// or -1 when the guess names nothing new.
int matchRecallAnswer(
  String input,
  List<String> candidates,
  Set<int> revealed,
) {
  final guess = normalizeRecallAnswer(input);
  if (guess.isEmpty) return -1;
  for (var i = 0; i < candidates.length; i++) {
    if (revealed.contains(i)) continue;
    if (normalizeRecallAnswer(candidates[i]) == guess) return i;
  }
  return -1;
}

/// Everyday things people actually memorize: the palace game deals one
/// of these lists per round instead of prescribing station→word pairs.
class MemorableList {
  final String title;
  final List<String> items;
  const MemorableList({required this.title, required this.items});
}

const _memorablePoolsHu = <String, List<String>>{
  'Bevásárlólista': [
    'tej', 'kenyér', 'tojás', 'vaj', 'alma', 'sajt', 'paradicsom',
    'liszt', 'cukor', 'kávé', 'tea', 'méz', 'rizs', 'tészta', 'banán',
    'narancs', 'burgonya', 'hagyma', 'paprika', 'tejföl',
  ],
  'Teendők mára': [
    'csekkbefizetés', 'gyógyszertár', 'kulcsmásolás', 'virágöntözés',
    'postacsomag', 'fogorvos időpont', 'könyvtári könyv', 'autómosás',
    'számlaellenőrzés', 'ajándékcsomagolás', 'ablaktisztítás',
    'cipőjavítás',
  ],
  'Útravaló lista': [
    'útlevél', 'jegy', 'töltő', 'esernyő', 'napszemüveg', 'kabát',
    'gyógyszer', 'könyv', 'kulacs', 'térkép', 'papírzsebkendő',
    'szendvics',
  ],
  'Tanulnivaló szavak': [
    'alma', 'kalapács', 'gyertya', 'híd', 'kert', 'lámpa', 'óceán',
    'kulcs', 'tigris', 'hegedű', 'vár', 'rakéta', 'tükör',
    'iránytű', 'sárkány', 'zongora', 'horgony', 'léggömb',
  ],
};

const _memorablePoolsEn = <String, List<String>>{
  'Shopping list': [
    'milk', 'bread', 'eggs', 'butter', 'apple', 'cheese', 'tomato',
    'flour', 'sugar', 'coffee', 'tea', 'honey', 'rice', 'pasta',
    'banana', 'orange', 'potato', 'onion', 'pepper', 'yogurt',
  ],
  "Today's errands": [
    'pay the bill', 'pharmacy', 'copy a key', 'water the plants',
    'parcel pickup', 'dentist appointment', 'library book', 'car wash',
    'check the invoice', 'wrap the gift', 'clean the windows',
    'shoe repair',
  ],
  'Packing list': [
    'passport', 'ticket', 'charger', 'umbrella', 'sunglasses',
    'jacket', 'medicine', 'book', 'water bottle', 'map', 'tissues',
    'sandwich',
  ],
  'Study words': [
    'apple', 'hammer', 'candle', 'bridge', 'garden', 'lamp',
    'ocean', 'key', 'tiger', 'violin', 'castle', 'rocket',
    'mirror', 'compass', 'dragon', 'piano', 'anchor', 'balloon',
  ],
};

/// Deals a titled everyday list: one pool per round, [count] distinct
/// items, topped up from the concrete nouns when a pool runs short.
MemorableList memorableListFor(String seed, int count, [String locale = 'en']) {
  final pools = isHuLocale(locale) ? _memorablePoolsHu : _memorablePoolsEn;
  final titles = pools.keys.toList();
  final title = titles[_seedHash('list:$seed') % titles.length];
  final pool = List<String>.of(pools[title]!)
    ..shuffle(Random(_seedHash('items:$seed')));
  final items = pool.take(count.clamp(2, 10)).toList();
  if (items.length < count.clamp(2, 10)) {
    final extra = List<String>.of(allConcreteNounsFor(locale))
      ..shuffle(Random(_seedHash('extra:$seed')));
    for (final w in extra) {
      if (items.length >= count.clamp(2, 10)) break;
      if (!items.contains(w)) items.add(w);
    }
  }
  return MemorableList(title: title, items: items);
}

List<String> get allConcreteNouns => allConcreteNounsFor('en');

List<String> allConcreteNounsFor([String locale = 'en']) => [
  ...concreteNounsFor(locale),
  ...extraConcreteNounsFor(locale),
];

Map<String, List<String>> get allPictureScenes => allPictureScenesFor('en');

Map<String, List<String>> allPictureScenesFor([String locale = 'en']) => {
  ...pictureScenesFor(locale),
  ...extraPictureScenesFor(locale),
};

int _seedHash(String seed) {
  var h = 0x811c9dc5;
  for (final c in seed.codeUnits) {
    h ^= c;
    h = (h * 0x01000193) & 0xffffffff;
  }
  return h;
}

String routeForSeed(String seed, [String locale = 'en']) {
  final names = palaceRoutesFor(locale).keys.toList();
  return names[_seedHash('route:$seed') % names.length];
}

String sceneForSeed(String seed, [String locale = 'en']) {
  final names = allPictureScenesFor(locale).keys.toList();
  return names[_seedHash('scene:$seed') % names.length];
}

List<String> localStations(String seed, int count, [String locale = 'en']) {
  final route = palaceRoutesFor(locale)[routeForSeed(seed, locale)]!;
  return route.take(count.clamp(1, route.length)).toList();
}

List<String> localDrillWords(String seed, int count, [String locale = 'en']) {
  final pool = List<String>.of(allConcreteNounsFor(locale))
    ..shuffle(Random(_seedHash('words:$seed')));
  return pool.take(count.clamp(1, pool.length)).toList();
}

List<String> stationsFromLabels(
  List<String> labels,
  String seed,
  int count, [
  String locale = 'en',
]) {
  final n = count.clamp(1, 10);
  final merged = <String>[];
  for (final raw in labels) {
    final label = raw.trim();
    if (label.isEmpty || merged.contains(label)) continue;
    merged.add(label);
    if (merged.length >= n) break;
  }
  if (merged.length < n) {
    for (final station in localStations(seed, 10, locale)) {
      if (merged.contains(station)) continue;
      merged.add(station);
      if (merged.length >= n) break;
    }
  }
  return merged;
}

/// Scene hint for a Palace Builder (chapters[2]) lesson: every one of the
/// 12 lessons renders a different viewpoint so the generated palace picture
/// matches the lesson title (ready-made room, miniature map, first-person
/// street, …). Unknown sections fall back to a plain room.
String spatialSceneForLesson(int section, int lesson) {
  if (section <= 0) {
    const scenes = ['room', 'viewpoints', 'reverse', 'rooms'];
    return scenes[lesson.clamp(0, scenes.length - 1)];
  }
  if (section == 1) {
    const scenes = ['map', 'island', 'first-person', 'route'];
    return scenes[lesson.clamp(0, scenes.length - 1)];
  }
  const scenes = ['own-room', 'flat', 'street', 'mind'];
  return scenes[lesson.clamp(0, scenes.length - 1)];
}

String _sceneSuffix(String scene) {
  switch (scene) {
    case 'map':
      return 'seen as a miniature treasure map from above, each station '
          'a labeled landmark icon';
    case 'island':
      return 'tropical island flyover view, each station a distinct '
          'landmark (dock, palm, hut, waterfall)';
    case 'first-person':
    case 'route':
      return 'first-person walking view down a winding path, stations '
          'as bold foreground objects in walking order';
    case 'street':
      return 'familiar city street at golden hour, stations as shop '
          'fronts and corners in walking order';
    case 'viewpoints':
      return 'same cozy room from three fixed camera angles, stations '
          'marked in each view';
    case 'reverse':
      return 'cozy room walk with glowing arrows pointing backwards, '
          'stations numbered in reverse walking order';
    case 'rooms':
    case 'flat':
      return 'two connected cozy rooms with a visible doorway, stations '
          'spread across both rooms in walking order';
    case 'own-room':
    case 'mind':
      return 'dreamlike minimal interior, few bold shapes, stations as '
          'large unmistakable objects';
    case 'room':
    default:
      return 'warm light, storybook style';
  }
}

String palaceImagePrompt(
  String routeName,
  int difficulty, [
  String locale = 'en',
  String scene = '',
]) {
  final routes = palaceRoutesFor(locale);
  final stations = routes[routeName] ?? routes.values.first;
  final n = drillItemCount(difficulty);
  return 'Cozy memory-palace illustration of a $routeName walk with '
      '${stations.take(n).join(', ')} as clearly separated, numbered '
      'stations in walking order, ${_sceneSuffix(scene)}';
}

String pictureImagePrompt(String sceneName, [String locale = 'en']) {
  final elements = allPictureScenesFor(locale)[sceneName] ?? const <String>[];
  return 'Vivid, detailed illustration of a $sceneName showing '
      '${elements.take(5).join(', ')}, storybook style, sharp details';
}

MetaTask localPalaceTask({
  required int difficulty,
  required String seed,
  String locale = 'en',

  /// Exact station count override for practice rounds whose length sits
  /// outside the registry 4-8 window (same loci procedure, any length).
  int? count,
}) {
  final n = (count ?? drillItemCount(difficulty)).clamp(3, 10);
  final route = routeForSeed(seed, locale);
  final stations = localStations(seed, n, locale);
  final words = localDrillWords(seed, n, locale);
  final rnd = Random(_seedHash('target:$seed'));
  final target = rnd.nextInt(n);
  final targetWord = words[target];
  final lures = List<String>.of(allConcreteNounsFor(locale))..shuffle(rnd);
  final options = <String>[targetWord];
  for (final lure in lures) {
    if (options.length >= 4) break;
    if (!words.contains(lure)) options.add(lure);
  }
  options.shuffle(rnd);
  return MetaTask(
    prompt: trFor(locale, 'task_palace_prompt', {'route': route}),
    items: List<String>.of(words),
    stations: stations,
    question: trFor(locale, 'task_palace_q', {'station': stations[target]}),
    options: options,
    correct: options.indexOf(targetWord),
    explanation: trFor(locale, 'task_palace_expl'),
    paradigm: 'loci-drill',
    source: 'Maguire et al. 2003; Dresler et al. 2017',
    createdAt: DateTime.now(),
  );
}

MetaTask localPictureTask({
  required int difficulty,
  required String seed,
  String locale = 'en',
}) {
  final scenes = allPictureScenesFor(locale);
  final n = drillItemCount(difficulty);
  final scene = sceneForSeed(seed, locale);
  final present = List<String>.of(scenes[scene]!.take(n));
  final rnd = Random(_seedHash('target:$seed'));
  final target = present[rnd.nextInt(present.length)];
  final lurePool = <String>[
    for (final entry in scenes.entries)
      if (entry.key != scene) ...entry.value,
  ]..shuffle(rnd);
  final options = <String>[target];
  for (final lure in lurePool) {
    if (options.length >= 4) break;
    if (!present.contains(lure)) options.add(lure);
  }
  options.shuffle(rnd);
  return MetaTask(
    prompt: trFor(locale, 'task_picture_prompt', {'scene': scene}),
    items: present,
    question: trFor(locale, 'task_picture_q', {'scene': scene}),
    options: options,
    correct: options.indexOf(target),
    explanation: trFor(locale, 'task_picture_expl'),
    paradigm: 'picture-recall',
    source: 'Shepard 1967; Standing 1973; Paivio dual-coding',
    createdAt: DateTime.now(),
  );
}
