library;

class StoryIdeaUnit {
  final String label;
  final List<String> keywords;
  const StoryIdeaUnit(this.label, this.keywords);
}

class StoryItem {
  final String id;
  final String text;
  final String question;
  final String correct;
  final List<String> lures;
  final List<StoryIdeaUnit> units;
  final bool hard;
  final int form;
  const StoryItem({
    required this.id,
    required this.text,
    required this.question,
    required this.correct,
    required this.lures,
    required this.units,
    this.hard = false,
    this.form = -1,
  });
}

const assessmentStories = <StoryItem>[
  StoryItem(
    id: 'story-a-easy',
    form: 0,
    text: 'Yesterday Anna bought 3 apples and a blue scarf at the market.',
    question: 'What did Anna buy besides the scarf?',
    correct: '3 apples',
    lures: ['2 pears', '1 hat', 'A basket'],
    units: [
      StoryIdeaUnit('Anna', ['anna']),
      StoryIdeaUnit('3 apples', ['3 apples', 'three apples', 'apples']),
      StoryIdeaUnit('blue scarf', ['blue scarf', 'scarf']),
    ],
  ),
  StoryItem(
    id: 'story-a-hard',
    form: 0,
    hard: true,
    text:
        'On Tuesday Maria borrowed 2 novels and a red umbrella from the '
        'library, then met Jim at 5.',
    question: 'What did Maria borrow besides the umbrella?',
    correct: '2 novels',
    lures: ['3 magazines', 'A map', '1 novel'],
    units: [
      StoryIdeaUnit('Maria', ['maria']),
      StoryIdeaUnit('2 novels', ['2 novels', 'two novels', 'novels']),
      StoryIdeaUnit('red umbrella', ['red umbrella', 'umbrella']),
      StoryIdeaUnit('library', ['library']),
      StoryIdeaUnit('met Jim at 5', ['met jim', 'jim', '5', 'five']),
    ],
  ),
  StoryItem(
    id: 'story-b-easy',
    form: 1,
    text: 'This morning Tom found 2 keys and a green wallet in the park.',
    question: 'What did Tom find besides the wallet?',
    correct: '2 keys',
    lures: ['3 coins', 'A phone', 'A glove'],
    units: [
      StoryIdeaUnit('Tom', ['tom']),
      StoryIdeaUnit('2 keys', ['2 keys', 'two keys', 'keys']),
      StoryIdeaUnit('green wallet', ['green wallet', 'wallet']),
    ],
  ),
  StoryItem(
    id: 'story-b-hard',
    form: 1,
    hard: true,
    text:
        'On Friday Lisa lent 4 books and a silver camera to her '
        'neighbor, then called Ann at 6.',
    question: 'What did Lisa lend besides the camera?',
    correct: '4 books',
    lures: ['2 books', 'A laptop', 'A bike'],
    units: [
      StoryIdeaUnit('Lisa', ['lisa']),
      StoryIdeaUnit('4 books', ['4 books', 'four books', 'books']),
      StoryIdeaUnit('silver camera', ['silver camera', 'camera']),
      StoryIdeaUnit('neighbor', ['neighbor', 'neighbour']),
      StoryIdeaUnit('called Ann at 6', ['called ann', 'ann', '6', 'six']),
    ],
  ),
  StoryItem(
    id: 'story-c-easy',
    form: 2,
    text: 'At noon David picked 5 pears and a straw hat in the orchard.',
    question: 'What did David pick besides the hat?',
    correct: '5 pears',
    lures: ['4 apples', '2 baskets', 'A rake'],
    units: [
      StoryIdeaUnit('David', ['david']),
      StoryIdeaUnit('5 pears', ['5 pears', 'five pears', 'pears']),
      StoryIdeaUnit('straw hat', ['straw hat', 'hat']),
    ],
  ),
  StoryItem(
    id: 'story-c-hard',
    form: 2,
    hard: true,
    text:
        'On Sunday Eva sold 3 lamps and a wooden clock at the fair, '
        'then paid Ben at 7.',
    question: 'What did Eva sell besides the clock?',
    correct: '3 lamps',
    lures: ['2 chairs', 'A rug', '5 candles'],
    units: [
      StoryIdeaUnit('Eva', ['eva']),
      StoryIdeaUnit('3 lamps', ['3 lamps', 'three lamps', 'lamps']),
      StoryIdeaUnit('wooden clock', ['wooden clock', 'clock']),
      StoryIdeaUnit('fair', ['fair']),
      StoryIdeaUnit('paid Ben at 7', ['paid ben', 'ben', '7', 'seven']),
    ],
  ),
  StoryItem(
    id: 'story-d-easy',
    form: 3,
    text:
        'In the evening Nora cooked fish soup and baked a round loaf '
        'for her guests.',
    question: 'What did Nora bake for her guests?',
    correct: 'A round loaf',
    lures: ['A pie', 'Two baguettes', 'A chocolate cake'],
    units: [
      StoryIdeaUnit('Nora', ['nora']),
      StoryIdeaUnit('fish soup', ['fish soup', 'soup']),
      StoryIdeaUnit('round loaf', ['round loaf', 'loaf']),
    ],
  ),
  StoryItem(
    id: 'story-d-hard',
    form: 3,
    hard: true,
    text:
        'Before the storm Clara closed 5 windows and fed the black cat '
        'on the porch.',
    question: 'What did Clara do besides closing the windows?',
    correct: 'Fed the black cat',
    lures: ['Fed the white dog', 'Locked the gate', 'Lit a lantern'],
    units: [
      StoryIdeaUnit('Clara', ['clara']),
      StoryIdeaUnit('5 windows', ['5 windows', 'five windows', 'windows']),
      StoryIdeaUnit('black cat', ['black cat', 'cat']),
      StoryIdeaUnit('porch', ['porch']),
      StoryIdeaUnit('before the storm', ['storm']),
    ],
  ),
];

const spareStories = <StoryItem>[
  StoryItem(
    id: 'story-s01',
    text:
        'At dawn the old ferry carried 12 cars and a red fire truck '
        'across the river.',
    question: 'What crossed the river besides the cars?',
    correct: 'A red fire truck',
    lures: ['A blue bus', 'A police car', 'An ambulance'],
    units: [
      StoryIdeaUnit('ferry', ['ferry']),
      StoryIdeaUnit('12 cars', ['12 cars', 'twelve cars', 'cars']),
      StoryIdeaUnit('red fire truck', ['red fire truck', 'fire truck']),
    ],
  ),
  StoryItem(
    id: 'story-s02',
    text:
        'After lunch the twins borrowed 2 bikes and a green tent from '
        'their uncle.',
    question: 'What did the twins borrow besides the tent?',
    correct: '2 bikes',
    lures: ['3 bikes', 'A canoe', 'A guitar'],
    units: [
      StoryIdeaUnit('twins', ['twins', 'twin']),
      StoryIdeaUnit('2 bikes', ['2 bikes', 'two bikes', 'bikes']),
      StoryIdeaUnit('green tent', ['green tent', 'tent']),
    ],
  ),
  StoryItem(
    id: 'story-s03',
    text: 'At noon the museum guide showed 40 pupils a golden mask from Egypt.',
    question: 'What did the guide show the pupils?',
    correct: 'A golden mask',
    lures: ['A silver sword', 'A marble statue', 'An old map'],
    units: [
      StoryIdeaUnit('museum guide', ['museum guide', 'guide']),
      StoryIdeaUnit('40 pupils', ['40 pupils', 'forty pupils', 'pupils']),
      StoryIdeaUnit('golden mask', ['golden mask', 'mask']),
    ],
  ),
  StoryItem(
    id: 'story-s04',
    text: 'On Monday Peter mailed 3 letters and a small parcel at the post office.',
    question: 'What did Peter mail besides the parcel?',
    correct: '3 letters',
    lures: ['2 letters', '4 postcards', 'A newspaper'],
    units: [
      StoryIdeaUnit('Peter', ['peter']),
      StoryIdeaUnit('3 letters', ['3 letters', 'three letters', 'letters']),
      StoryIdeaUnit('small parcel', ['small parcel', 'parcel']),
    ],
  ),
  StoryItem(
    id: 'story-s05',
    text:
        'In March the farmer planted 6 rows of corn and a lone oak '
        'behind the barn.',
    question: 'What did the farmer plant besides the oak?',
    correct: '6 rows of corn',
    lures: ['4 rows of wheat', '2 apple trees', 'A fence'],
    units: [
      StoryIdeaUnit('farmer', ['farmer']),
      StoryIdeaUnit('6 rows of corn', ['rows of corn', 'corn', '6 rows']),
      StoryIdeaUnit('lone oak', ['lone oak', 'oak']),
    ],
  ),
  StoryItem(
    id: 'story-s06',
    text: 'At dusk the baker packed 8 loaves and a warm pie for the shelter.',
    question: 'What did the baker pack besides the pie?',
    correct: '8 loaves',
    lures: ['6 rolls', '4 cakes', 'A basket'],
    units: [
      StoryIdeaUnit('baker', ['baker']),
      StoryIdeaUnit('8 loaves', ['8 loaves', 'eight loaves', 'loaves']),
      StoryIdeaUnit('warm pie', ['warm pie', 'pie']),
    ],
  ),
  StoryItem(
    id: 'story-s07',
    text: 'Before noon the sailor tied 2 ropes and a brass bell to the mast.',
    question: 'What did the sailor tie besides the bell?',
    correct: '2 ropes',
    lures: ['3 chains', 'A flag', 'A lantern'],
    units: [
      StoryIdeaUnit('sailor', ['sailor']),
      StoryIdeaUnit('2 ropes', ['2 ropes', 'two ropes', 'ropes']),
      StoryIdeaUnit('brass bell', ['brass bell', 'bell']),
    ],
  ),
  StoryItem(
    id: 'story-s08',
    text: 'During recess Mia traded 4 marbles and a shiny sticker with her friend.',
    question: 'What did Mia trade besides the sticker?',
    correct: '4 marbles',
    lures: ['2 cards', '6 beads', 'A pen'],
    units: [
      StoryIdeaUnit('Mia', ['mia']),
      StoryIdeaUnit('4 marbles', ['4 marbles', 'four marbles', 'marbles']),
      StoryIdeaUnit('shiny sticker', ['shiny sticker', 'sticker']),
    ],
  ),
  StoryItem(
    id: 'story-s09',
    hard: true,
    text:
        'On Thursday Carl fixed 2 clocks and a broken radio in his '
        'shop, then rang Kate at 8.',
    question: 'What did Carl fix besides the radio?',
    correct: '2 clocks',
    lures: ['3 watches', 'A lamp', '5 toys'],
    units: [
      StoryIdeaUnit('Carl', ['carl']),
      StoryIdeaUnit('2 clocks', ['2 clocks', 'two clocks', 'clocks']),
      StoryIdeaUnit('broken radio', ['broken radio', 'radio']),
      StoryIdeaUnit('shop', ['shop']),
      StoryIdeaUnit('rang Kate at 8', ['rang kate', 'kate', '8', 'eight']),
    ],
  ),
  StoryItem(
    id: 'story-s10',
    hard: true,
    text:
        'After dinner Ruth washed 6 plates and a glass tray in the '
        'kitchen, then woke Sam at 9.',
    question: 'What did Ruth wash besides the tray?',
    correct: '6 plates',
    lures: ['4 cups', '2 pots', 'A kettle'],
    units: [
      StoryIdeaUnit('Ruth', ['ruth']),
      StoryIdeaUnit('6 plates', ['6 plates', 'six plates', 'plates']),
      StoryIdeaUnit('glass tray', ['glass tray', 'tray']),
      StoryIdeaUnit('kitchen', ['kitchen']),
      StoryIdeaUnit('woke Sam at 9', ['woke sam', 'sam', '9', 'nine']),
    ],
  ),
  StoryItem(
    id: 'story-s11',
    hard: true,
    text:
        'In April the pilot flew 3 routes and a night cargo run over '
        'the hills, then met Lou at 4.',
    question: 'What did the pilot fly besides the cargo run?',
    correct: '3 routes',
    lures: ['2 loops', '5 tours', 'A test flight'],
    units: [
      StoryIdeaUnit('pilot', ['pilot']),
      StoryIdeaUnit('3 routes', ['3 routes', 'three routes', 'routes']),
      StoryIdeaUnit('night cargo run', ['cargo run', 'cargo']),
      StoryIdeaUnit('hills', ['hills']),
      StoryIdeaUnit('met Lou at 4', ['met lou', 'lou', '4', 'four']),
    ],
  ),
  StoryItem(
    id: 'story-s12',
    hard: true,
    text:
        'On Wednesday Joy painted 2 doors and a garden bench by the '
        'lake, then joined Max at 3.',
    question: 'What did Joy paint besides the bench?',
    correct: '2 doors',
    lures: ['3 fences', 'A boat', '4 shutters'],
    units: [
      StoryIdeaUnit('Joy', ['joy']),
      StoryIdeaUnit('2 doors', ['2 doors', 'two doors', 'doors']),
      StoryIdeaUnit('garden bench', ['garden bench', 'bench']),
      StoryIdeaUnit('lake', ['lake']),
      StoryIdeaUnit('joined Max at 3', ['joined max', 'max', '3', 'three']),
    ],
  ),
  StoryItem(
    id: 'story-s13',
    hard: true,
    text:
        'At midnight the guard checked 7 gates and a dark cellar under '
        'the hall, then phoned Ed at 1.',
    question: 'What did the guard check besides the cellar?',
    correct: '7 gates',
    lures: ['5 doors', '3 yards', 'A tower'],
    units: [
      StoryIdeaUnit('guard', ['guard']),
      StoryIdeaUnit('7 gates', ['7 gates', 'seven gates', 'gates']),
      StoryIdeaUnit('dark cellar', ['dark cellar', 'cellar']),
      StoryIdeaUnit('hall', ['hall']),
      StoryIdeaUnit('phoned Ed at 1', ['phoned ed', 'ed', '1', 'one']),
    ],
  ),
  StoryItem(
    id: 'story-s14',
    hard: true,
    text:
        'In June the diver found 5 shells and a brass key near the '
        'reef, then waved to Ann at 2.',
    question: 'What did the diver find besides the key?',
    correct: '5 shells',
    lures: ['3 pearls', '7 coins', 'A bottle'],
    units: [
      StoryIdeaUnit('diver', ['diver']),
      StoryIdeaUnit('5 shells', ['5 shells', 'five shells', 'shells']),
      StoryIdeaUnit('brass key', ['brass key', 'key']),
      StoryIdeaUnit('reef', ['reef']),
      StoryIdeaUnit('waved to Ann at 2', ['waved', 'ann', '2', 'two']),
    ],
  ),
  StoryItem(
    id: 'story-s15',
    hard: true,
    text:
        'On Saturday the tailor sewed 4 coats and a silk vest in the '
        'attic, then paid Sue at 10.',
    question: 'What did the tailor sew besides the vest?',
    correct: '4 coats',
    lures: ['2 shirts', '6 skirts', 'A quilt'],
    units: [
      StoryIdeaUnit('tailor', ['tailor']),
      StoryIdeaUnit('4 coats', ['4 coats', 'four coats', 'coats']),
      StoryIdeaUnit('silk vest', ['silk vest', 'vest']),
      StoryIdeaUnit('attic', ['attic']),
      StoryIdeaUnit('paid Sue at 10', ['paid sue', 'sue', '10', 'ten']),
    ],
  ),
  StoryItem(
    id: 'story-s16',
    hard: true,
    text:
        'Before lunch the vet treated 3 foals and a lame goose on the '
        'farm, then called Dan at 11.',
    question: 'What did the vet treat besides the goose?',
    correct: '3 foals',
    lures: ['2 calves', '5 pups', 'A pony'],
    units: [
      StoryIdeaUnit('vet', ['vet']),
      StoryIdeaUnit('3 foals', ['3 foals', 'three foals', 'foals', 'foal']),
      StoryIdeaUnit('lame goose', ['lame goose', 'goose', 'geese']),
      StoryIdeaUnit('farm', ['farm']),
      StoryIdeaUnit('called Dan at 11', ['called dan', 'dan', '11', 'eleven']),
    ],
  ),
];

bool isHuLocale(String locale) => locale == 'hu';

StoryItem assessmentStory(int form, bool hard, [String locale = 'en']) {
  final bank = isHuLocale(locale) ? assessmentStoriesHu : assessmentStories;
  for (final s in bank) {
    if (s.form == form % 4 && s.hard == hard) return s;
  }
  return bank.first;
}

List<StoryIdeaUnit> storyUnitsFor(String text) {
  for (final s in assessmentStories) {
    if (s.text == text) return s.units;
  }
  for (final s in spareStories) {
    if (s.text == text) return s.units;
  }
  for (final s in assessmentStoriesHu) {
    if (s.text == text) return s.units;
  }
  for (final s in spareStoriesHu) {
    if (s.text == text) return s.units;
  }
  return const [];
}

class CategoryItem {
  final String category;
  final String correct;
  final List<String> lures;
  final bool hard;
  final int form;
  const CategoryItem({
    required this.category,
    required this.correct,
    required this.lures,
    this.hard = false,
    this.form = -1,
  });
}

const assessmentCategories = <CategoryItem>[
  CategoryItem(
    category: 'Fruits',
    correct: 'Apple',
    lures: ['Cucumber', 'Potato', 'Onion'],
    form: 0,
  ),
  CategoryItem(
    category: 'Mammals',
    correct: 'Dolphin',
    lures: ['Shark', 'Octopus', 'Crocodile'],
    hard: true,
    form: 0,
  ),
  CategoryItem(
    category: 'Vegetables',
    correct: 'Carrot',
    lures: ['Pepper', 'Pear', 'Grape'],
    form: 1,
  ),
  CategoryItem(
    category: 'Birds',
    correct: 'Penguin',
    lures: ['Bat', 'Butterfly', 'Bee'],
    hard: true,
    form: 1,
  ),
  CategoryItem(
    category: 'Tools',
    correct: 'Hammer',
    lures: ['Nail', 'Flowerpot', 'Candle'],
    form: 2,
  ),
  CategoryItem(
    category: 'Musical instruments',
    correct: 'Violin',
    lures: ['Radio', 'Ladder', 'Mirror'],
    hard: true,
    form: 2,
  ),
  CategoryItem(
    category: 'Vehicles',
    correct: 'Bicycle',
    lures: ['Stroller', 'Swing', 'Tent'],
    form: 3,
  ),
  CategoryItem(
    category: 'Furniture',
    correct: 'Bookshelf',
    lures: ['Carpet', 'Lamp', 'Curtain'],
    hard: true,
    form: 3,
  ),
];

const spareCategories = <CategoryItem>[
  CategoryItem(
    category: 'Fish',
    correct: 'Salmon',
    lures: ['Dolphin', 'Squid', 'Frog'],
  ),
  CategoryItem(
    category: 'Insects',
    correct: 'Ant',
    lures: ['Spider', 'Worm', 'Snail'],
  ),
  CategoryItem(
    category: 'Flowers',
    correct: 'Rose',
    lures: ['Clover', 'Fern', 'Moss'],
  ),
  CategoryItem(
    category: 'Trees',
    correct: 'Oak',
    lures: ['Ivy', 'Reed', 'Cactus'],
  ),
  CategoryItem(
    category: 'Drinks',
    correct: 'Coffee',
    lures: ['Soup', 'Syrup', 'Honey'],
  ),
  CategoryItem(
    category: 'Desserts',
    correct: 'Cake',
    lures: ['Bread', 'Cheese', 'Butter'],
  ),
  CategoryItem(
    category: 'Sports',
    correct: 'Tennis',
    lures: ['Chess', 'Dance', 'Yoga'],
  ),
  CategoryItem(
    category: 'Professions',
    correct: 'Doctor',
    lures: ['Patient', 'Client', 'Guest'],
  ),
  CategoryItem(
    category: 'Body parts',
    correct: 'Elbow',
    lures: ['Sleeve', 'Glove', 'Watch'],
  ),
  CategoryItem(
    category: 'Buildings',
    correct: 'Library',
    lures: ['Tent', 'Cabin', 'Garage'],
    hard: true,
  ),
  CategoryItem(
    category: 'Planets',
    correct: 'Mars',
    lures: ['Moon', 'Comet', 'Star'],
    hard: true,
  ),
  CategoryItem(
    category: 'Reptiles',
    correct: 'Lizard',
    lures: ['Salamander', 'Toad', 'Eel'],
    hard: true,
  ),
  CategoryItem(
    category: 'Kitchenware',
    correct: 'Kettle',
    lures: ['Vase', 'Bucket', 'Ashtray'],
    hard: true,
  ),
  CategoryItem(
    category: 'Footwear',
    correct: 'Boot',
    lures: ['Sock', 'Stirrup', 'Skate'],
    hard: true,
  ),
  CategoryItem(
    category: 'Dairy foods',
    correct: 'Yogurt',
    lures: ['Tofu', 'Lard', 'Custard'],
    hard: true,
  ),
  CategoryItem(
    category: 'Herbs',
    correct: 'Basil',
    lures: ['Grass', 'Fern', 'Moss'],
    hard: true,
  ),
];

CategoryItem assessmentCategory(int form, bool hard, [String locale = 'en']) {
  final bank =
      isHuLocale(locale) ? assessmentCategoriesHu : assessmentCategories;
  for (final c in bank) {
    if (c.form == form % 4 && c.hard == hard) return c;
  }
  return bank.first;
}

class FaceNameItem {
  final String feature;
  final String name;
  final String hook;
  final List<String> lures;
  const FaceNameItem({
    required this.feature,
    required this.name,
    required this.hook,
    required this.lures,
  });
}

const faceNameBank = <FaceNameItem>[
  FaceNameItem(
    feature: 'bushy eyebrows',
    name: 'Baker',
    hook: 'white hat',
    lures: ['Miller', 'Carter', 'Fisher'],
  ),
  FaceNameItem(
    feature: 'scar on the chin',
    name: 'Archer',
    hook: 'bow and arrow',
    lures: ['Hunter', 'Fletcher', 'Bowman'],
  ),
  FaceNameItem(
    feature: 'round glasses',
    name: 'Wheeler',
    hook: 'cart wheel',
    lures: ['Carter', 'Driver', 'Porter'],
  ),
  FaceNameItem(
    feature: 'deep voice',
    name: 'Bell',
    hook: 'brass bell',
    lures: ['Chime', 'Horn', 'Drummer'],
  ),
  FaceNameItem(
    feature: 'silver earring',
    name: 'Silver',
    hook: 'shiny coin',
    lures: ['Steel', 'Copper', 'Golden'],
  ),
  FaceNameItem(
    feature: 'freckles',
    name: 'Gardener',
    hook: 'flower bed',
    lures: ['Farmer', 'Planter', 'Forester'],
  ),
  FaceNameItem(
    feature: 'tall forehead',
    name: 'Tower',
    hook: 'stone tower',
    lures: ['Castle', 'Bridger', 'Hall'],
  ),
  FaceNameItem(
    feature: 'quick smile',
    name: 'Swift',
    hook: 'running shoes',
    lures: ['Rusher', 'Dancer', 'Jumper'],
  ),
  FaceNameItem(
    feature: 'crooked nose',
    name: 'Hook',
    hook: 'pirate hook',
    lures: ['Crook', 'Bender', 'Fisher'],
  ),
  FaceNameItem(
    feature: 'red beard',
    name: 'Fox',
    hook: 'red fox tail',
    lures: ['Wolf', 'Hare', 'Lynx'],
  ),
  FaceNameItem(
    feature: 'gold tooth',
    name: 'Miner',
    hook: 'gold nugget',
    lures: ['Digger', 'Panner', 'Smith'],
  ),
  FaceNameItem(
    feature: 'tattooed arm',
    name: 'Sailor',
    hook: 'anchor tattoo',
    lures: ['Rower', 'Diver', 'Fisher'],
  ),
  FaceNameItem(
    feature: 'long braid',
    name: 'Weaver',
    hook: 'loom threads',
    lures: ['Spinner', 'Knitter', 'Tailor'],
  ),
  FaceNameItem(
    feature: 'heavy boots',
    name: 'Walker',
    hook: 'muddy footprints',
    lures: ['Hiker', 'Marcher', 'Runner'],
  ),
  FaceNameItem(
    feature: 'thin mustache',
    name: 'Barber',
    hook: 'shiny razor',
    lures: ['Shaver', 'Stylist', 'Clippers'],
  ),
  FaceNameItem(
    feature: 'bright scarf',
    name: 'Dyer',
    hook: 'paint pots',
    lures: ['Painter', 'Stainer', 'Tintner'],
  ),
];

class ForeignWordItem {
  final String foreign;
  final String keyword;
  final String meaning;
  final List<String> lures;
  const ForeignWordItem({
    required this.foreign,
    required this.keyword,
    required this.meaning,
    required this.lures,
  });
}

const foreignWordBank = <ForeignWordItem>[
  ForeignWordItem(
    foreign: 'carta',
    keyword: 'cart',
    meaning: 'letter',
    lures: ['parcel', 'ticket', 'notebook'],
  ),
  ForeignWordItem(
    foreign: 'gato',
    keyword: 'gate',
    meaning: 'cat',
    lures: ['dog', 'rabbit', 'mouse'],
  ),
  ForeignWordItem(
    foreign: 'libro',
    keyword: 'library',
    meaning: 'book',
    lures: ['shelf', 'page', 'pencil'],
  ),
  ForeignWordItem(
    foreign: 'fiore',
    keyword: 'fee',
    meaning: 'flower',
    lures: ['grass', 'leaf', 'branch'],
  ),
  ForeignWordItem(
    foreign: 'pane',
    keyword: 'pan',
    meaning: 'bread',
    lures: ['cake', 'cheese', 'butter'],
  ),
  ForeignWordItem(
    foreign: 'sole',
    keyword: 'soul',
    meaning: 'sun',
    lures: ['moon', 'star', 'cloud'],
  ),
  ForeignWordItem(
    foreign: 'barca',
    keyword: 'bark',
    meaning: 'boat',
    lures: ['ship', 'bridge', 'harbor'],
  ),
  ForeignWordItem(
    foreign: 'chiave',
    keyword: 'cave',
    meaning: 'key',
    lures: ['lock', 'door', 'chain'],
  ),
  ForeignWordItem(
    foreign: 'casa',
    keyword: 'castle',
    meaning: 'house',
    lures: ['hut', 'tent', 'tower'],
  ),
  ForeignWordItem(
    foreign: 'acqua',
    keyword: 'aqua',
    meaning: 'water',
    lures: ['juice', 'milk', 'rain'],
  ),
  ForeignWordItem(
    foreign: 'latte',
    keyword: 'lattice',
    meaning: 'milk',
    lures: ['cream', 'yogurt', 'juice'],
  ),
  ForeignWordItem(
    foreign: 'mela',
    keyword: 'melody',
    meaning: 'apple',
    lures: ['pear', 'plum', 'peach'],
  ),
  ForeignWordItem(
    foreign: 'cane',
    keyword: 'cane',
    meaning: 'dog',
    lures: ['wolf', 'fox', 'puppy'],
  ),
  ForeignWordItem(
    foreign: 'cavallo',
    keyword: 'cavalry',
    meaning: 'horse',
    lures: ['donkey', 'mule', 'pony'],
  ),
  ForeignWordItem(
    foreign: 'uccello',
    keyword: 'cello',
    meaning: 'bird',
    lures: ['nest', 'feather', 'beak'],
  ),
  ForeignWordItem(
    foreign: 'pesce',
    keyword: 'pesky',
    meaning: 'fish',
    lures: ['shark', 'whale', 'eel'],
  ),
  ForeignWordItem(
    foreign: 'albero',
    keyword: 'albedo',
    meaning: 'tree',
    lures: ['bush', 'shrub', 'trunk'],
  ),
  ForeignWordItem(
    foreign: 'fiume',
    keyword: 'fume',
    meaning: 'river',
    lures: ['stream', 'creek', 'canal'],
  ),
  ForeignWordItem(
    foreign: 'montagna',
    keyword: 'montage',
    meaning: 'mountain',
    lures: ['hill', 'cliff', 'peak'],
  ),
  ForeignWordItem(
    foreign: 'strada',
    keyword: 'strata',
    meaning: 'road',
    lures: ['path', 'lane', 'alley'],
  ),
  ForeignWordItem(
    foreign: 'porta',
    keyword: 'port',
    meaning: 'door',
    lures: ['gate', 'hatch', 'portal'],
  ),
  ForeignWordItem(
    foreign: 'finestra',
    keyword: 'finest',
    meaning: 'window',
    lures: ['shutter', 'curtain', 'sill'],
  ),
  ForeignWordItem(
    foreign: 'sedia',
    keyword: 'sedan',
    meaning: 'chair',
    lures: ['stool', 'bench', 'couch'],
  ),
  ForeignWordItem(
    foreign: 'tavolo',
    keyword: 'tavern',
    meaning: 'table',
    lures: ['desk', 'counter', 'shelf'],
  ),
  ForeignWordItem(
    foreign: 'letto',
    keyword: 'letter',
    meaning: 'bed',
    lures: ['cot', 'mattress', 'hammock'],
  ),
  ForeignWordItem(
    foreign: 'specchio',
    keyword: 'speck',
    meaning: 'mirror',
    lures: ['glass', 'frame', 'portrait'],
  ),
  ForeignWordItem(
    foreign: 'luna',
    keyword: 'loon',
    meaning: 'moon',
    lures: ['planet', 'comet', 'eclipse'],
  ),
  ForeignWordItem(
    foreign: 'notte',
    keyword: 'note',
    meaning: 'night',
    lures: ['dusk', 'dawn', 'midnight'],
  ),
  ForeignWordItem(
    foreign: 'mano',
    keyword: 'manor',
    meaning: 'hand',
    lures: ['finger', 'palm', 'wrist'],
  ),
  ForeignWordItem(
    foreign: 'piede',
    keyword: 'pied piper',
    meaning: 'foot',
    lures: ['ankle', 'toe', 'heel'],
  ),
  ForeignWordItem(
    foreign: 'occhio',
    keyword: 'ochre',
    meaning: 'eye',
    lures: ['brow', 'lash', 'pupil'],
  ),
  ForeignWordItem(
    foreign: 'formaggio',
    keyword: 'format',
    meaning: 'cheese',
    lures: ['butter', 'curd', 'yogurt'],
  ),
];

const extraPictureScenes = <String, List<String>>{
  'sunny bakery': [
    'flour cloud',
    'pretzel rack',
    'sleeping cat',
    'brass bell',
    'cherry pie',
    'wooden peel',
  ],
  'harbor dock': [
    'coiled rope',
    'crying gull',
    'red buoy',
    'fish crates',
    'lighthouse beam',
    'oily rainbow',
  ],
  'autumn forest': [
    'red maple',
    'deer trail',
    'mossy log',
    'crow call',
    'acorn pile',
    'fog bank',
  ],
  'night observatory': [
    'brass telescope',
    'star chart',
    'red lamp',
    'spiral stairs',
    'coffee mug',
    'open dome',
  ],
  'school gym': [
    'climbing ropes',
    'whistle',
    'stacked mats',
    'scoreboard',
    'basketball rack',
    'chalk tray',
  ],
  'barber shop': [
    'striped pole',
    'leather chair',
    'shaving foam',
    'wall mirrors',
    'tonic bottles',
    'waiting bench',
  ],
  'lakeside campsite': [
    'orange tent',
    'campfire smoke',
    'canoe rack',
    'lantern post',
    'marshmallow bag',
    'loon call',
  ],
  'art gallery': [
    'marble bust',
    'velvet rope',
    'skylight',
    'creaking floor',
    'guard stool',
    'bronze plaque',
  ],
};

class ProspectiveItem {
  final String when;
  final String then;
  final List<String> lures;
  const ProspectiveItem({
    required this.when,
    required this.then,
    required this.lures,
  });
}

const prospectiveBank = <ProspectiveItem>[
  ProspectiveItem(
    when: 'I lock the front door',
    then: 'take the trash bag',
    lures: ['water the plants', 'feed the cat', 'close the windows'],
  ),
  ProspectiveItem(
    when: 'I finish lunch',
    then: 'take the vitamin',
    lures: ['call the bank', 'pay the bill', 'book the dentist'],
  ),
  ProspectiveItem(
    when: 'I sit at my desk',
    then: 'open the lesson plan',
    lures: ['check the news', 'reply to one mail', 'sharpen pencils'],
  ),
  ProspectiveItem(
    when: 'The 6 pm alarm rings',
    then: 'start the rice cooker',
    lures: ['walk the dog', 'iron a shirt', 'empty the bin'],
  ),
  ProspectiveItem(
    when: 'I pass the pharmacy',
    then: 'buy the prescription',
    lures: ['buy stamps', 'copy the key', 'post the letter'],
  ),
  ProspectiveItem(
    when: 'The teacher ends the lesson',
    then: 'write the homework down',
    lures: ['pack the gym bag', 'charge the phone', 'clean the desk'],
  ),
  ProspectiveItem(
    when: 'I plug the phone in',
    then: 'set the morning alarm',
    lures: ['wipe the screen', 'update the apps', 'back up photos'],
  ),
  ProspectiveItem(
    when: 'I see the gym bag',
    then: 'pack the water bottle',
    lures: ['fold the towel', 'tie the shoes', 'grab the keys'],
  ),
  ProspectiveItem(
    when: 'The meeting ends',
    then: 'send the summary mail',
    lures: ['file the notes', 'book the room', 'print the agenda'],
  ),
  ProspectiveItem(
    when: 'I get the payslip',
    then: 'move savings aside',
    lures: ['order lunch', 'top up the card', 'check the balance'],
  ),
  ProspectiveItem(
    when: 'I leave the shop',
    then: 'check the receipt',
    lures: ['count the change', 'bag the fruit', 'lock the bike'],
  ),
  ProspectiveItem(
    when: 'The sun sets',
    then: 'close the shutters',
    lures: ['light the lamp', 'cover the grill', 'bring in the chairs'],
  ),
  ProspectiveItem(
    when: 'I board the bus',
    then: 'review three cards',
    lures: ['text a friend', 'count the stops', 'read the ads'],
  ),
  ProspectiveItem(
    when: 'I open the fridge',
    then: 'note the missing milk',
    lures: ['toss the leftovers', 'wipe the shelf', 'chill the juice'],
  ),
  ProspectiveItem(
    when: 'Friday at five comes',
    then: 'plan next week',
    lures: ['clean the inbox', 'water the office plant', 'log the hours'],
  ),
  ProspectiveItem(
    when: 'I hear thunder',
    then: 'unplug the router',
    lures: ['shut the gate', 'move the laundry', 'park the bike'],
  ),
];

class PoemItem {
  final String line1;
  final String line2;
  final List<String> lures;
  const PoemItem({
    required this.line1,
    required this.line2,
    required this.lures,
  });
}

const poemBank = <PoemItem>[
  PoemItem(
    line1: 'The harbor bell rings soft and low,',
    line2: 'And painted boats begin to glow.',
    lures: [
      'And silver fish begin to fly.',
      'While sleepy gulls drift through the sky.',
      'And market stalls are stacked with snow.',
    ],
  ),
  PoemItem(
    line1: 'A paper lantern climbs the hill,',
    line2: 'The evening fields are green and still.',
    lures: [
      'The morning streets are loud and shrill.',
      'The river bends around the mill.',
      'And crickets tune their tiny trill.',
    ],
  ),
  PoemItem(
    line1: 'My grandmother kept a copper key,',
    line2: 'It opened doors to rooms of tea.',
    lures: [
      'It locked the gate beside the sea.',
      'It chimed at noon for you and me.',
      'It mapped the roads to Galilee.',
    ],
  ),
  PoemItem(
    line1: 'The baker whistles with the lark,',
    line2: 'And loaves turn gold before the dark.',
    lures: [
      'And sparrows gather in the park.',
      'While shadows stretch across the ark.',
      'And ovens hum their evening mark.',
    ],
  ),
  PoemItem(
    line1: 'A red fox crosses garden snow,',
    line2: 'It leaves a tale where cold winds blow.',
    lures: [
      'It hunts for plums where warm winds blow.',
      'It naps beneath the mistletoe.',
      'It counts the stars that rise below.',
    ],
  ),
  PoemItem(
    line1: 'The old oak keeps the summer rain,',
    line2: 'Then gives it back to roots again.',
    lures: [
      'Then sings it back through windowpane.',
      'And hides it from the harvest train.',
      'While acorns drum their green refrain.',
    ],
  ),
  PoemItem(
    line1: 'A lighthouse keeper brews his tea,',
    line2: 'And shares the dawn with gull and sea.',
    lures: [
      'And counts the ships that cannot flee.',
      'While foghorns call from quay to quay.',
      'And trades tall tales for honeyed plea.',
    ],
  ),
  PoemItem(
    line1: 'The market wakes with crates of pear,',
    line2: 'Sweet autumn smells fill the air.',
    lures: [
      'Cold winter rain is everywhere.',
      'Loud children race from stair to stair.',
      'Warm bread is sliced with tender care.',
    ],
  ),
  PoemItem(
    line1: 'A sleepy train rolls past the farm,',
    line2: 'Its whistle keeps the night from harm.',
    lures: [
      'Its wheels keep time with hoof and charm.',
      'Its lamps burn bright through cold alarm.',
      'Its smoke draws rings of softest yarn.',
    ],
  ),
  PoemItem(
    line1: 'The violinist tunes one string,',
    line2: 'And empty halls begin to sing.',
    lures: [
      'And painted birds begin to wing.',
      'While autumn leaves take flight and swing.',
      'And candles drip their golden ring.',
    ],
  ),
  PoemItem(
    line1: 'A garden snail with silver trail,',
    line2: 'Outlasts the wind, the hail, the gale.',
    lures: [
      'Outruns the Postman and the mail.',
      'And dreams of ships with paper sail.',
      'While roses nod beyond the rail.',
    ],
  ),
  PoemItem(
    line1: 'The clockmaker winds each gear with pride,',
    line2: 'And midnight marches far and wide.',
    lures: [
      'And noonday naps are cast aside.',
      'While pendulums in rhythm glide.',
      'And morning bells are amplified.',
    ],
  ),
];

const dayEventPool = <String>[
  'woke to the alarm',
  'brushed teeth',
  'brewed morning coffee',
  'fed the cat',
  'checked the bus time',
  'rode the bus downtown',
  'bought a warm roll',
  'opened the classroom door',
  'wrote the date on the board',
  'borrowed a red pen',
  'ate lunch with friends',
  'called mother back',
  'posted the parcel',
  'jogged around the park',
  'watered the balcony plants',
  'cooked pasta for dinner',
  'read twenty pages',
  'set the alarm again',
];

const extraConcreteNouns = <String>[
  'acorn',
  'backpack',
  'bucket',
  'button',
  'canyon',
  'cherry',
  'dagger',
  'drum',
  'flute',
  'grape',
  'harp',
  'helmet',
  'jacket',
  'kettle',
  'ladder',
  'magnet',
  'nest',
  'raft',
  'sword',
  'tent',
  'trumpet',
  'vase',
  'wallet',
  'zebra',
];

List<StoryItem> spareStoriesFor([String locale = 'en']) =>
    isHuLocale(locale) ? spareStoriesHu : spareStories;

List<CategoryItem> spareCategoriesFor([String locale = 'en']) =>
    isHuLocale(locale) ? spareCategoriesHu : spareCategories;

List<FaceNameItem> faceNameBankFor([String locale = 'en']) =>
    isHuLocale(locale) ? faceNameBankHu : faceNameBank;

List<ForeignWordItem> foreignWordBankFor([String locale = 'en']) =>
    isHuLocale(locale) ? foreignWordBankHu : foreignWordBank;

List<ProspectiveItem> prospectiveBankFor([String locale = 'en']) =>
    isHuLocale(locale) ? prospectiveBankHu : prospectiveBank;

List<PoemItem> poemBankFor([String locale = 'en']) =>
    isHuLocale(locale) ? poemBankHu : poemBank;

List<String> dayEventPoolFor([String locale = 'en']) =>
    isHuLocale(locale) ? dayEventPoolHu : dayEventPool;

List<String> extraConcreteNounsFor([String locale = 'en']) =>
    isHuLocale(locale) ? extraConcreteNounsHu : extraConcreteNouns;

Map<String, List<String>> extraPictureScenesFor([String locale = 'en']) =>
    isHuLocale(locale) ? extraPictureScenesHu : extraPictureScenes;

const assessmentStoriesHu = <StoryItem>[
  StoryItem(
    id: 'story-a-easy-hu',
    form: 0,
    text: 'Tegnap Anna 3 almát és egy kék sálat vett a piacon.',
    question: 'Mit vett Anna a sálon kívül?',
    correct: '3 almát',
    lures: ['2 körtét', '1 kalapot', 'Egy kosarat'],
    units: [
      StoryIdeaUnit('Anna', ['anna']),
      StoryIdeaUnit('3 alma', ['3 alma', 'harom alma', 'alma', 'almat']),
      StoryIdeaUnit('kék sál', ['kek sal', 'sal']),
    ],
  ),
  StoryItem(
    id: 'story-a-hard-hu',
    form: 0,
    hard: true,
    text:
        'Kedden Mária 2 regényt és egy piros esernyőt kölcsönzött a '
        'könyvtárból, aztán találkozott Jimmel 5-kor.',
    question: 'Mit kölcsönzött Mária az esernyőn kívül?',
    correct: '2 regényt',
    lures: ['3 magazint', 'Egy térképet', '1 regényt'],
    units: [
      StoryIdeaUnit('Mária', ['maria']),
      StoryIdeaUnit('2 regény', ['2 regeny', 'ket regeny', 'regeny', 'regenyek']),
      StoryIdeaUnit('piros esernyő', ['piros esernyo', 'esernyo']),
      StoryIdeaUnit('könyvtár', ['konyvtar']),
      StoryIdeaUnit('találkozott Jimmel 5-kor', ['jim', '5', 'ot']),
    ],
  ),
  StoryItem(
    id: 'story-b-easy-hu',
    form: 1,
    text: 'Ma reggel Tamás 2 kulcsot és egy zöld tárcát talált a parkban.',
    question: 'Mit talált Tamás a tárcán kívül?',
    correct: '2 kulcsot',
    lures: ['3 érmét', 'Egy telefont', 'Egy kesztyűt'],
    units: [
      StoryIdeaUnit('Tamás', ['tamas']),
      StoryIdeaUnit('2 kulcs', ['2 kulcs', 'ket kulcs', 'kulcs', 'kulcsok']),
      StoryIdeaUnit('zöld tárca', ['zold tarca', 'tarca']),
    ],
  ),
  StoryItem(
    id: 'story-b-hard-hu',
    form: 1,
    hard: true,
    text:
        'Pénteken Liza 4 könyvet és egy ezüst fényképezőgépet adott '
        'kölcsön a szomszédnak, aztán felhívta Annát 6-kor.',
    question: 'Mit adott kölcsön Liza a fényképezőgépen kívül?',
    correct: '4 könyvet',
    lures: ['2 könyvet', 'Egy laptopot', 'Egy biciklit'],
    units: [
      StoryIdeaUnit('Liza', ['liza']),
      StoryIdeaUnit('4 könyv', ['4 konyv', 'negy konyv', 'konyv', 'konyvek']),
      StoryIdeaUnit('ezüst fényképezőgép', ['ezust fenykepezogep', 'fenykepezogep']),
      StoryIdeaUnit('szomszéd', ['szomszed']),
      StoryIdeaUnit('felhívta Annát 6-kor', ['anna', '6', 'hat']),
    ],
  ),
  StoryItem(
    id: 'story-c-easy-hu',
    form: 2,
    text: 'Délben Dávid 5 körtét és egy szalmakalapot szedett a gyümölcsösben.',
    question: 'Mit szedett Dávid a kalapon kívül?',
    correct: '5 körtét',
    lures: ['4 almát', '2 kosarat', 'Egy gereblyét'],
    units: [
      StoryIdeaUnit('Dávid', ['david']),
      StoryIdeaUnit('5 körte', ['5 korte', 'ot korte', 'korte']),
      StoryIdeaUnit('szalmakalap', ['szalmakalap', 'kalap']),
    ],
  ),
  StoryItem(
    id: 'story-c-hard-hu',
    form: 2,
    hard: true,
    text:
        'Vasárnap Éva 3 lámpát és egy faórát adott el a vásáron, '
        'aztán fizetett Bennek 7-kor.',
    question: 'Mit adott el Éva az órán kívül?',
    correct: '3 lámpát',
    lures: ['2 széket', 'Egy szőnyeget', '5 gyertyát'],
    units: [
      StoryIdeaUnit('Éva', ['eva']),
      StoryIdeaUnit('3 lámpa', ['3 lampa', 'harom lampa', 'lampa']),
      StoryIdeaUnit('faóra', ['faora', 'ora']),
      StoryIdeaUnit('vásár', ['vasar']),
      StoryIdeaUnit('fizetett Bennek 7-kor', ['ben', '7', 'het']),
    ],
  ),
  StoryItem(
    id: 'story-d-easy-hu',
    form: 3,
    text:
        'Este Nóra halászlét főzött és egy kerek kenyeret sütött '
        'a vendégeknek.',
    question: 'Mit sütött Nóra a vendégeknek?',
    correct: 'Egy kerek kenyeret',
    lures: ['Egy pitét', 'Két bagettet', 'Egy csokitortát'],
    units: [
      StoryIdeaUnit('Nóra', ['nora']),
      StoryIdeaUnit('halászlé', ['halaszle', 'leves']),
      StoryIdeaUnit('kerek kenyér', ['kerek kenyer', 'kenyer', 'kenyeret']),
    ],
  ),
  StoryItem(
    id: 'story-d-hard-hu',
    form: 3,
    hard: true,
    text:
        'A vihar előtt Klára becsukott 5 ablakot és megetette a fekete '
        'macskát a verandán.',
    question: 'Mit tett Klára az ablakcsukáson kívül?',
    correct: 'Megetette a fekete macskát',
    lures: ['Megetette a fehér kutyát', 'Bezárta a kaput', 'Meggyújtott egy lámpást'],
    units: [
      StoryIdeaUnit('Klára', ['klara']),
      StoryIdeaUnit('5 ablak', ['5 ablak', 'ot ablak', 'ablak']),
      StoryIdeaUnit('fekete macska', ['fekete macska', 'macska']),
      StoryIdeaUnit('veranda', ['veranda']),
      StoryIdeaUnit('vihar előtt', ['vihar']),
    ],
  ),
];

const spareStoriesHu = <StoryItem>[
  StoryItem(
    id: 'story-s01-hu',
    text:
        'Hajnalban az öreg komp 12 autót és egy piros tűzoltóautót vitt '
        'át a folyón.',
    question: 'Mi kelt át a folyón az autókon kívül?',
    correct: 'Egy piros tűzoltóautó',
    lures: ['Egy kék busz', 'Egy rendőrautó', 'Egy mentő'],
    units: [
      StoryIdeaUnit('komp', ['komp']),
      StoryIdeaUnit('12 autó', ['12 auto', 'tizenket auto', 'auto']),
      StoryIdeaUnit('piros tűzoltóautó', ['piros tuzoltoauto', 'tuzoltoauto']),
    ],
  ),
  StoryItem(
    id: 'story-s02-hu',
    text:
        'Ebéd után az ikrek 2 biciklit és egy zöld sátrat kértek kölcsön '
        'a nagybátyjuktól.',
    question: 'Mit kértek kölcsön az ikrek a sátron kívül?',
    correct: '2 biciklit',
    lures: ['3 biciklit', 'Egy kenut', 'Egy gitárt'],
    units: [
      StoryIdeaUnit('ikrek', ['ikrek']),
      StoryIdeaUnit('2 bicikli', ['2 bicikli', 'ket bicikli', 'bicikli']),
      StoryIdeaUnit('zöld sátor', ['zold sator', 'sator']),
    ],
  ),
  StoryItem(
    id: 'story-s03-hu',
    text: 'Délben a múzeumi tárlatvezető 40 diáknak mutatott egy egyiptomi aranymaszkot.',
    question: 'Mit mutatott a tárlatvezető a diákoknak?',
    correct: 'Egy aranymaszkot',
    lures: ['Egy ezüstkardot', 'Egy márványszobrot', 'Egy régi térképet'],
    units: [
      StoryIdeaUnit('tárlatvezető', ['tarlatvezeto']),
      StoryIdeaUnit('40 diák', ['40 diak', 'negyven diak', 'diak']),
      StoryIdeaUnit('aranymasz', ['aranymasz', 'maszk']),
    ],
  ),
  StoryItem(
    id: 'story-s04-hu',
    text: 'Hétfőn Péter 3 levelet és egy kis csomagot adott fel a postán.',
    question: 'Mit adott fel Péter a csomagon kívül?',
    correct: '3 levelet',
    lures: ['2 levelet', '4 képeslapot', 'Egy újságot'],
    units: [
      StoryIdeaUnit('Péter', ['peter']),
      StoryIdeaUnit('3 levél', ['3 level', 'harom level', 'level', 'levelet']),
      StoryIdeaUnit('kis csomag', ['kis csomag', 'csomag']),
    ],
  ),
  StoryItem(
    id: 'story-s05-hu',
    text:
        'Márciusban a gazda 6 sor kukoricát és egy magányos tölgyet '
        'ültetett a csűr mögé.',
    question: 'Mit ültetett a gazda a tölgyön kívül?',
    correct: '6 sor kukoricát',
    lures: ['4 sor búzát', '2 almafát', 'Egy kerítést'],
    units: [
      StoryIdeaUnit('gazda', ['gazda']),
      StoryIdeaUnit('6 sor kukorica', ['sor kukorica', 'kukorica', '6 sor']),
      StoryIdeaUnit('magányos tölgy', ['maganyos tolgy', 'tolgy']),
    ],
  ),
  StoryItem(
    id: 'story-s06-hu',
    text: 'Alkonyatkor a pék 8 kenyeret és egy meleg pitét csomagolt a menhelynek.',
    question: 'Mit csomagolt a pék a pitén kívül?',
    correct: '8 kenyeret',
    lures: ['6 zsemlét', '4 tortát', 'Egy kosarat'],
    units: [
      StoryIdeaUnit('pék', ['pek']),
      StoryIdeaUnit('8 kenyér', ['8 kenyer', 'nyolc kenyer', 'kenyer']),
      StoryIdeaUnit('meleg pite', ['meleg pite', 'pite']),
    ],
  ),
  StoryItem(
    id: 'story-s07-hu',
    text: 'Dél előtt a matróz 2 kötelet és egy rézharangot kötött az árbochoz.',
    question: 'Mit kötött a matróz a harangon kívül?',
    correct: '2 kötelet',
    lures: ['3 láncot', 'Egy zászlót', 'Egy lámpást'],
    units: [
      StoryIdeaUnit('matróz', ['matroz']),
      StoryIdeaUnit('2 kötél', ['2 kotel', 'ket kotel', 'kotel']),
      StoryIdeaUnit('rézharang', ['rezharang', 'harang']),
    ],
  ),
  StoryItem(
    id: 'story-s08-hu',
    text: 'A szünetben Mia 4 üveggolyót és egy csillogó matricát cserélt el a barátjával.',
    question: 'Mit cserélt el Mia a matricán kívül?',
    correct: '4 üveggolyót',
    lures: ['2 kártyát', '6 gyöngyöt', 'Egy tollat'],
    units: [
      StoryIdeaUnit('Mia', ['mia']),
      StoryIdeaUnit('4 üveggolyó', ['4 uveggolyo', 'negy uveggolyo', 'uveggolyo']),
      StoryIdeaUnit('csillogó matrica', ['csillogo matrica', 'matrica']),
    ],
  ),
  StoryItem(
    id: 'story-s09-hu',
    hard: true,
    text:
        'Csütörtökön Karcsi megjavított 2 órát és egy rossz rádiót a '
        'műhelyében, aztán felhívta Katit 8-kor.',
    question: 'Mit javított meg Karcsi a rádión kívül?',
    correct: '2 órát',
    lures: ['3 karórát', 'Egy lámpát', '5 játékot'],
    units: [
      StoryIdeaUnit('Karcsi', ['karcsi']),
      StoryIdeaUnit('2 óra', ['2 ora', 'ket ora', 'ora']),
      StoryIdeaUnit('rossz rádió', ['rossz radio', 'radio']),
      StoryIdeaUnit('műhely', ['muhely']),
      StoryIdeaUnit('felhívta Katit 8-kor', ['kati', '8', 'nyolc']),
    ],
  ),
  StoryItem(
    id: 'story-s10-hu',
    hard: true,
    text:
        'Vacsora után Ruti elmosott 6 tányért és egy üvegtálcát a '
        'konyhában, aztán felkeltette Samut 9-kor.',
    question: 'Mit mosott el Ruti a tálcán kívül?',
    correct: '6 tányért',
    lures: ['4 csészét', '2 lábost', 'Egy teáskannát'],
    units: [
      StoryIdeaUnit('Ruti', ['ruti']),
      StoryIdeaUnit('6 tányér', ['6 tanyer', 'hat tanyer', 'tanyer']),
      StoryIdeaUnit('üvegtálca', ['uvegtalca', 'talca']),
      StoryIdeaUnit('konyha', ['konyha']),
      StoryIdeaUnit('felkeltette Samut 9-kor', ['samu', '9', 'kilenc']),
    ],
  ),
  StoryItem(
    id: 'story-s11-hu',
    hard: true,
    text:
        'Áprilisban a pilóta 3 útvonalat és egy éjszakai teherszállítást '
        'repült a dombok fölött, aztán találkozott Lajossal 4-kor.',
    question: 'Mit repült a pilóta a teherszállításon kívül?',
    correct: '3 útvonalat',
    lures: ['2 kört', '5 túrát', 'Egy próbarepülést'],
    units: [
      StoryIdeaUnit('pilóta', ['pilota']),
      StoryIdeaUnit('3 útvonal', ['3 utvonal', 'harom utvonal', 'utvonal']),
      StoryIdeaUnit('éjszakai teherszállítás', ['teherszallitas', 'cargo']),
      StoryIdeaUnit('dombok', ['domb']),
      StoryIdeaUnit('találkozott Lajossal 4-kor', ['lajos', '4', 'negy']),
    ],
  ),
  StoryItem(
    id: 'story-s12-hu',
    hard: true,
    text:
        'Szerdán Joli lefestett 2 ajtót és egy kerti padot a tónál, '
        'aztán csatlakozott Maxhoz 3-kor.',
    question: 'Mit festett le Joli a padon kívül?',
    correct: '2 ajtót',
    lures: ['3 kerítést', 'Egy csónakot', '4 zsalut'],
    units: [
      StoryIdeaUnit('Joli', ['joli']),
      StoryIdeaUnit('2 ajtó', ['2 ajto', 'ket ajto', 'ajto']),
      StoryIdeaUnit('kerti pad', ['kerti pad', 'pad']),
      StoryIdeaUnit('tó', ['to']),
      StoryIdeaUnit('csatlakozott Maxhoz 3-kor', ['max', '3', 'harom']),
    ],
  ),
  StoryItem(
    id: 'story-s13-hu',
    hard: true,
    text:
        'Éjfélkor az őr ellenőrzött 7 kaput és egy sötét pincét a csarnok '
        'alatt, aztán felhívta Edét 1-kor.',
    question: 'Mit ellenőrzött az őr a pincén kívül?',
    correct: '7 kaput',
    lures: ['5 ajtót', '3 udvart', 'Egy tornyot'],
    units: [
      StoryIdeaUnit('őr', ['or']),
      StoryIdeaUnit('7 kapu', ['7 kapu', 'het kapu', 'kapu']),
      StoryIdeaUnit('sötét pince', ['sotet pince', 'pince']),
      StoryIdeaUnit('csarnok', ['csarnok']),
      StoryIdeaUnit('felhívta Edét 1-kor', ['ede', '1', 'egy']),
    ],
  ),
  StoryItem(
    id: 'story-s14-hu',
    hard: true,
    text:
        'Júniusban a búvár talált 5 kagylót és egy rézkulcsot a zátonynál, '
        'aztán integetett Annának 2-kor.',
    question: 'Mit talált a búvár a kulcson kívül?',
    correct: '5 kagylót',
    lures: ['3 gyöngyöt', '7 érmét', 'Egy üveget'],
    units: [
      StoryIdeaUnit('búvár', ['buvar']),
      StoryIdeaUnit('5 kagyló', ['5 kaglo', 'ot kaglo', 'kaglo']),
      StoryIdeaUnit('rézkulcs', ['rezkulcs', 'kulcs']),
      StoryIdeaUnit('zátony', ['zatony']),
      StoryIdeaUnit('integetett Annának 2-kor', ['integet', 'anna', '2', 'ketto']),
    ],
  ),
  StoryItem(
    id: 'story-s15-hu',
    hard: true,
    text:
        'Szombaton a szabó megvarrt 4 kabátot és egy selyemmellényt a '
        'padláson, aztán fizetett Zsuzsának 10-kor.',
    question: 'Mit varrt meg a szabó a mellényen kívül?',
    correct: '4 kabátot',
    lures: ['2 inget', '6 szoknyát', 'Egy paplant'],
    units: [
      StoryIdeaUnit('szabó', ['szabo']),
      StoryIdeaUnit('4 kabát', ['4 kabat', 'negy kabat', 'kabat']),
      StoryIdeaUnit('selyemmellény', ['selyemmelleny', 'melleny']),
      StoryIdeaUnit('padlás', ['padlas']),
      StoryIdeaUnit('fizetett Zsuzsának 10-kor', ['zsuzsa', '10', 'tiz']),
    ],
  ),
  StoryItem(
    id: 'story-s16-hu',
    hard: true,
    text:
        'Ebéd előtt az állatorvos ellátott 3 csikót és egy sánta libát a '
        'farmon, aztán felhívta Danit 11-kor.',
    question: 'Mit látott el az állatorvos a libán kívül?',
    correct: '3 csikót',
    lures: ['2 borjút', '5 kiskutyát', 'Egy pónit'],
    units: [
      StoryIdeaUnit('állatorvos', ['allatorvos']),
      StoryIdeaUnit('3 csikó', ['3 csiko', 'harom csiko', 'csiko']),
      StoryIdeaUnit('sánta liba', ['santa liba', 'liba']),
      StoryIdeaUnit('farm', ['farm']),
      StoryIdeaUnit('felhívta Danit 11-kor', ['dani', '11', 'tizenegy']),
    ],
  ),
];

const assessmentCategoriesHu = <CategoryItem>[
  CategoryItem(
    category: 'Gyümölcsök',
    correct: 'Alma',
    lures: ['Uborka', 'Burgonya', 'Hagyma'],
    form: 0,
  ),
  CategoryItem(
    category: 'Emlősök',
    correct: 'Delfin',
    lures: ['Cápa', 'Polip', 'Krokodil'],
    hard: true,
    form: 0,
  ),
  CategoryItem(
    category: 'Zöldségek',
    correct: 'Répa',
    lures: ['Paprika', 'Körte', 'Szőlő'],
    form: 1,
  ),
  CategoryItem(
    category: 'Madarak',
    correct: 'Pingvin',
    lures: ['Denevér', 'Pillangó', 'Méh'],
    hard: true,
    form: 1,
  ),
  CategoryItem(
    category: 'Szerszámok',
    correct: 'Kalapács',
    lures: ['Szeg', 'Virágcserép', 'Gyertya'],
    form: 2,
  ),
  CategoryItem(
    category: 'Hangszerek',
    correct: 'Hegedű',
    lures: ['Rádió', 'Létra', 'Tükör'],
    hard: true,
    form: 2,
  ),
  CategoryItem(
    category: 'Járművek',
    correct: 'Bicikli',
    lures: ['Babakocsi', 'Hinta', 'Sátor'],
    form: 3,
  ),
  CategoryItem(
    category: 'Bútorok',
    correct: 'Könyvespolc',
    lures: ['Szőnyeg', 'Lámpa', 'Függöny'],
    hard: true,
    form: 3,
  ),
];

const spareCategoriesHu = <CategoryItem>[
  CategoryItem(
    category: 'Halak',
    correct: 'Lazac',
    lures: ['Delfin', 'Tintahal', 'Béka'],
  ),
  CategoryItem(
    category: 'Rovarok',
    correct: 'Hangya',
    lures: ['Pók', 'Kukac', 'Csiga'],
  ),
  CategoryItem(
    category: 'Virágok',
    correct: 'Rózsa',
    lures: ['Lóhere', 'Páfrány', 'Moha'],
  ),
  CategoryItem(
    category: 'Fák',
    correct: 'Tölgy',
    lures: ['Borostyán', 'Nád', 'Kaktusz'],
  ),
  CategoryItem(
    category: 'Italok',
    correct: 'Kávé',
    lures: ['Leves', 'Szirup', 'Méz'],
  ),
  CategoryItem(
    category: 'Desszertek',
    correct: 'Torta',
    lures: ['Kenyér', 'Sajt', 'Vaj'],
  ),
  CategoryItem(
    category: 'Sportok',
    correct: 'Tenisz',
    lures: ['Sakk', 'Tánc', 'Jóga'],
  ),
  CategoryItem(
    category: 'Szakmák',
    correct: 'Orvos',
    lures: ['Beteg', 'Ügyfél', 'Vendég'],
  ),
  CategoryItem(
    category: 'Testrészek',
    correct: 'Könyök',
    lures: ['Ujj', 'Kesztyű', 'Óra'],
  ),
  CategoryItem(
    category: 'Épületek',
    correct: 'Könyvtár',
    lures: ['Sátor', 'Kalyiba', 'Garázs'],
    hard: true,
  ),
  CategoryItem(
    category: 'Bolygók',
    correct: 'Mars',
    lures: ['Hold', 'Üstökös', 'Csillag'],
    hard: true,
  ),
  CategoryItem(
    category: 'Hüllők',
    correct: 'Gyík',
    lures: ['Szalamandra', 'Varangy', 'Angolna'],
    hard: true,
  ),
  CategoryItem(
    category: 'Konyhai eszközök',
    correct: 'Vízforraló',
    lures: ['Váza', 'Vödör', 'Hamutartó'],
    hard: true,
  ),
  CategoryItem(
    category: 'Lábbelik',
    correct: 'Csizma',
    lures: ['Zokni', 'Kengyel', 'Korcsolya'],
    hard: true,
  ),
  CategoryItem(
    category: 'Tejtermékek',
    correct: 'Joghurt',
    lures: ['Tofu', 'Zsír', 'Sodó'],
    hard: true,
  ),
  CategoryItem(
    category: 'Fűszernövények',
    correct: 'Bazsalikom',
    lures: ['Fű', 'Páfrány', 'Moha'],
    hard: true,
  ),
];

const faceNameBankHu = <FaceNameItem>[
  FaceNameItem(
    feature: 'bozontos szemöldök',
    name: 'Pék',
    hook: 'fehér sapka',
    lures: ['Molnár', 'Szabó', 'Halász'],
  ),
  FaceNameItem(
    feature: 'seb az állon',
    name: 'Íjász',
    hook: 'íj és nyíl',
    lures: ['Vadász', 'Nyílkészítő', 'Íjkészítő'],
  ),
  FaceNameItem(
    feature: 'kerek szemüveg',
    name: 'Kerekes',
    hook: 'szekérkerék',
    lures: ['Fuvaros', 'Sofőr', 'Hordár'],
  ),
  FaceNameItem(
    feature: 'mély hang',
    name: 'Harang',
    hook: 'rézharang',
    lures: ['Csengő', 'Kürt', 'Dobos'],
  ),
  FaceNameItem(
    feature: 'ezüst fülbevaló',
    name: 'Ezüst',
    hook: 'fényes érme',
    lures: ['Acél', 'Réz', 'Arany'],
  ),
  FaceNameItem(
    feature: 'szeplők',
    name: 'Kertész',
    hook: 'virágágyás',
    lures: ['Földműves', 'Ültető', 'Erdész'],
  ),
  FaceNameItem(
    feature: 'magas homlok',
    name: 'Torony',
    hook: 'kőtorony',
    lures: ['Vár', 'Hídépítő', 'Csarnok'],
  ),
  FaceNameItem(
    feature: 'gyors mosoly',
    name: 'Fürge',
    hook: 'futócipő',
    lures: ['Sietős', 'Táncos', 'Ugró'],
  ),
  FaceNameItem(
    feature: 'görbe orr',
    name: 'Kampó',
    hook: 'kalózkampó',
    lures: ['Görbe', 'Hajlító', 'Halász'],
  ),
  FaceNameItem(
    feature: 'vörös szakáll',
    name: 'Róka',
    hook: 'vörös rókafarok',
    lures: ['Farkas', 'Nyúl', 'Hiúz'],
  ),
  FaceNameItem(
    feature: 'aranyfog',
    name: 'Bányász',
    hook: 'aranyrög',
    lures: ['Ásó', 'Aranymosó', 'Kovács'],
  ),
  FaceNameItem(
    feature: 'tetovált kar',
    name: 'Tengerész',
    hook: 'horgonyos tetoválás',
    lures: ['Evezős', 'Búvár', 'Halász'],
  ),
  FaceNameItem(
    feature: 'hosszú copf',
    name: 'Takács',
    hook: 'szövőszálak',
    lures: ['Fonó', 'Kötő', 'Szabó'],
  ),
  FaceNameItem(
    feature: 'nehéz bakancs',
    name: 'Gyalogos',
    hook: 'sáros lábnyomok',
    lures: ['Túrázó', 'Masírozó', 'Futó'],
  ),
  FaceNameItem(
    feature: 'vékony bajusz',
    name: 'Borbély',
    hook: 'fényes borotva',
    lures: ['Borotváló', 'Fodrász', 'Nyíró'],
  ),
  FaceNameItem(
    feature: 'élénk sál',
    name: 'Festő',
    hook: 'festékesdobozok',
    lures: ['Mázoló', 'Pácoló', 'Színező'],
  ),
];

const foreignWordBankHu = <ForeignWordItem>[
  ForeignWordItem(
    foreign: 'carta',
    keyword: 'karta',
    meaning: 'levél',
    lures: ['csomag', 'jegy', 'füzet'],
  ),
  ForeignWordItem(
    foreign: 'gato',
    keyword: 'gát',
    meaning: 'macska',
    lures: ['kutya', 'nyúl', 'egér'],
  ),
  ForeignWordItem(
    foreign: 'libro',
    keyword: 'liba',
    meaning: 'könyv',
    lures: ['polc', 'lap', 'ceruza'],
  ),
  ForeignWordItem(
    foreign: 'fiore',
    keyword: 'fiók',
    meaning: 'virág',
    lures: ['fű', 'levél', 'ág'],
  ),
  ForeignWordItem(
    foreign: 'pane',
    keyword: 'pán',
    meaning: 'kenyér',
    lures: ['torta', 'sajt', 'vaj'],
  ),
  ForeignWordItem(
    foreign: 'sole',
    keyword: 'só',
    meaning: 'nap',
    lures: ['hold', 'csillag', 'felhő'],
  ),
  ForeignWordItem(
    foreign: 'barca',
    keyword: 'bárka',
    meaning: 'csónak',
    lures: ['hajó', 'híd', 'kikötő'],
  ),
  ForeignWordItem(
    foreign: 'chiave',
    keyword: 'kávé',
    meaning: 'kulcs',
    lures: ['zár', 'ajtó', 'lánc'],
  ),
  ForeignWordItem(
    foreign: 'casa',
    keyword: 'kása',
    meaning: 'ház',
    lures: ['kunyhó', 'sátor', 'torony'],
  ),
  ForeignWordItem(
    foreign: 'acqua',
    keyword: 'akna',
    meaning: 'víz',
    lures: ['gyümölcslé', 'tej', 'eső'],
  ),
  ForeignWordItem(
    foreign: 'latte',
    keyword: 'latyak',
    meaning: 'tej',
    lures: ['tejszín', 'joghurt', 'gyümölcslé'],
  ),
  ForeignWordItem(
    foreign: 'mela',
    keyword: 'mell',
    meaning: 'alma',
    lures: ['körte', 'szilva', 'barack'],
  ),
  ForeignWordItem(
    foreign: 'cane',
    keyword: 'kanna',
    meaning: 'kutya',
    lures: ['farkas', 'róka', 'kiskutya'],
  ),
  ForeignWordItem(
    foreign: 'cavallo',
    keyword: 'kavallér',
    meaning: 'ló',
    lures: ['szamár', 'öszvér', 'póniló'],
  ),
  ForeignWordItem(
    foreign: 'uccello',
    keyword: 'cselló',
    meaning: 'madár',
    lures: ['fészek', 'toll', 'csőr'],
  ),
  ForeignWordItem(
    foreign: 'pesce',
    keyword: 'pesztonka',
    meaning: 'hal',
    lures: ['cápa', 'bálna', 'angolna'],
  ),
  ForeignWordItem(
    foreign: 'albero',
    keyword: 'albérlet',
    meaning: 'fa',
    lures: ['bokor', 'cserje', 'törzs'],
  ),
  ForeignWordItem(
    foreign: 'fiume',
    keyword: 'füge',
    meaning: 'folyó',
    lures: ['patak', 'ér', 'csatorna'],
  ),
  ForeignWordItem(
    foreign: 'montagna',
    keyword: 'montázs',
    meaning: 'hegy',
    lures: ['domb', 'szikla', 'csúcs'],
  ),
  ForeignWordItem(
    foreign: 'strada',
    keyword: 'strázsa',
    meaning: 'út',
    lures: ['ösvény', 'sáv', 'sikátor'],
  ),
  ForeignWordItem(
    foreign: 'porta',
    keyword: 'porta',
    meaning: 'ajtó',
    lures: ['kapu', 'csapóajtó', 'portál'],
  ),
  ForeignWordItem(
    foreign: 'finestra',
    keyword: 'finesz',
    meaning: 'ablak',
    lures: ['zsalugáter', 'függöny', 'párkány'],
  ),
  ForeignWordItem(
    foreign: 'sedia',
    keyword: 'szédia',
    meaning: 'szék',
    lures: ['zsámoly', 'pad', 'kanapé'],
  ),
  ForeignWordItem(
    foreign: 'tavolo',
    keyword: 'távol',
    meaning: 'asztal',
    lures: ['íróasztal', 'pult', 'polc'],
  ),
  ForeignWordItem(
    foreign: 'letto',
    keyword: 'letesz',
    meaning: 'ágy',
    lures: ['tábori ágy', 'matrac', 'függőágy'],
  ),
  ForeignWordItem(
    foreign: 'specchio',
    keyword: 'spekulál',
    meaning: 'tükör',
    lures: ['üveg', 'keret', 'arckép'],
  ),
  ForeignWordItem(
    foreign: 'luna',
    keyword: 'lúg',
    meaning: 'hold',
    lures: ['bolygó', 'üstökös', 'napfogyatkozás'],
  ),
  ForeignWordItem(
    foreign: 'notte',
    keyword: 'nóta',
    meaning: 'éjszaka',
    lures: ['alkony', 'hajnal', 'éjfél'],
  ),
  ForeignWordItem(
    foreign: 'mano',
    keyword: 'manó',
    meaning: 'kéz',
    lures: ['ujj', 'tenyér', 'csukló'],
  ),
  ForeignWordItem(
    foreign: 'piede',
    keyword: 'pince',
    meaning: 'láb',
    lures: ['boka', 'lábujj', 'sarok'],
  ),
  ForeignWordItem(
    foreign: 'occhio',
    keyword: 'okos',
    meaning: 'szem',
    lures: ['szemöldök', 'szempilla', 'pupilla'],
  ),
  ForeignWordItem(
    foreign: 'formaggio',
    keyword: 'forma',
    meaning: 'sajt',
    lures: ['vaj', 'túró', 'joghurt'],
  ),
];

const prospectiveBankHu = <ProspectiveItem>[
  ProspectiveItem(
    when: 'bezárom a bejárati ajtót',
    then: 'vidd ki a szemeteszsákot',
    lures: ['locsold meg a növényeket', 'etesd meg a macskát', 'csukd be az ablakokat'],
  ),
  ProspectiveItem(
    when: 'befejeztem az ebédet',
    then: 'vedd be a vitamint',
    lures: ['hívd fel a bankot', 'fizesd be a számlát', 'jelentkezz be a fogorvoshoz'],
  ),
  ProspectiveItem(
    when: 'leülök az íróasztalhoz',
    then: 'nyisd ki a tanmenetet',
    lures: ['nézd meg a híreket', 'válaszolj egy levélre', 'hegyezd ki a ceruzákat'],
  ),
  ProspectiveItem(
    when: 'megszólal a 6 órás ébresztő',
    then: 'indítsd el a rizsfőzőt',
    lures: ['sétáltasd meg a kutyát', 'vasalj ki egy inget', 'ürítsd ki a kukát'],
  ),
  ProspectiveItem(
    when: 'elmegyek a gyógyszertár előtt',
    then: 'vedd meg a receptet',
    lures: ['vegyél bélyeget', 'másoltasd le a kulcsot', 'add fel a levelet'],
  ),
  ProspectiveItem(
    when: 'a tanár befejezi az órát',
    then: 'írd le a házi feladatot',
    lures: ['pakold be a tornazsákot', 'töltsd a telefont', 'töröld le az asztalt'],
  ),
  ProspectiveItem(
    when: 'bedugom a telefont tölteni',
    then: 'állítsd be a reggeli ébresztőt',
    lures: ['töröld le a kijelzőt', 'frissítsd az appokat', 'mentsd a fotókat'],
  ),
  ProspectiveItem(
    when: 'meglátom a sporttáskát',
    then: 'pakold be a kulacsot',
    lures: ['hajtsd össze a törölközőt', 'kösd be a cipődet', 'fogd a kulcsokat'],
  ),
  ProspectiveItem(
    when: 'vége az értekezletnek',
    then: 'küldd el az összefoglalót',
    lures: ['fűzd le a jegyzeteket', 'foglald le a termet', 'nyomtasd ki a napirendet'],
  ),
  ProspectiveItem(
    when: 'megkapom a fizetési papírt',
    then: 'tedd félre a megtakarítást',
    lures: ['rendelj ebédet', 'töltsd fel a kártyát', 'nézd meg az egyenleget'],
  ),
  ProspectiveItem(
    when: 'kilépek a boltból',
    then: 'nézd meg a blokkot',
    lures: ['számold meg a visszajárót', 'pakold be a gyümölcsöt', 'zárd le a biciklit'],
  ),
  ProspectiveItem(
    when: 'lemegy a nap',
    then: 'csukd be a zsalukat',
    lures: ['gyújtsd meg a lámpát', 'takard le a grillt', 'hozd be a székeket'],
  ),
  ProspectiveItem(
    when: 'felszállok a buszra',
    then: 'ismételj át három kártyát',
    lures: ['írj egy barátodnak', 'számold a megállókat', 'olvasd a hirdetéseket'],
  ),
  ProspectiveItem(
    when: 'kinyitom a hűtőt',
    then: 'jegyezd fel a hiányzó tejet',
    lures: ['dobd ki a maradékot', 'töröld le a polcot', 'hűtsd be a gyümölcslevet'],
  ),
  ProspectiveItem(
    when: 'eljön péntek öt óra',
    then: 'tervezd meg a jövő hetet',
    lures: ['takarítsd ki a postaládát', 'locsold meg az irodai növényt', 'írd be az órákat'],
  ),
  ProspectiveItem(
    when: 'meghallom a mennydörgést',
    then: 'húzd ki a routert',
    lures: ['csukd be a kaput', 'szedd be a ruhákat', 'állítsd be a biciklit'],
  ),
];

const poemBankHu = <PoemItem>[
  PoemItem(
    line1: 'A kikötői harang halkan kong,',
    line2: 's a festett hajókon fény lobog.',
    lures: [
      's ezüst halak szállnak az égen.',
      'míg álmos sirály siklik tova.',
      's a piaci bódékat hó fedi.',
    ],
  ),
  PoemItem(
    line1: 'Papírlámpa mászik a hegyre fel,',
    line2: 'az esti rét zöld és csendes.',
    lures: [
      'a reggeli utca zajos és éles.',
      'a folyó kanyarog a malomnál.',
      's tücskök hangolják apró zenéjüket.',
    ],
  ),
  PoemItem(
    line1: 'Nagyanyámnak rézkulcsa volt,',
    line2: 'teázószobákra nyitotta.',
    lures: [
      'a tengerparti kaput zárta.',
      'délben csengetett neked s nekem.',
      'Galilea útjait mutatta.',
    ],
  ),
  PoemItem(
    line1: 'A pék a pacsirtával fütyörész,',
    line2: 's a cipók aranyszínben sülnek.',
    lures: [
      's verebek gyűlnek a parkban.',
      'míg árnyak nyúlnak a bárkán.',
      's a kemencék esti dalt dúdolnak.',
    ],
  ),
  PoemItem(
    line1: 'Vörös róka fut a kerti havon,',
    line2: 'nyomot hagy, hol hideg szél süvít.',
    lures: [
      'szilvára vadászik, hol langy szél fúj.',
      'fagyöngy alatt szundikál.',
      'csillagokat számol, mik alant kelnek.',
    ],
  ),
  PoemItem(
    line1: 'Az öreg tölgy őrzi a nyári esőt,',
    line2: 'aztán visszaadja a gyökereknek.',
    lures: [
      'aztán ablaküvegen át énekli.',
      'és elrejti az aratógép elől.',
      'míg makkok verik zöld ritmusukat.',
    ],
  ),
  PoemItem(
    line1: 'A toronyőr teát főz estére,',
    line2: 's a hajnalt sirállyal osztja meg.',
    lures: [
      's a hajókat számolja szüntelen.',
      'míg ködkürtök szólnak partról partra.',
      's toronymagas meséket cserél mézért.',
    ],
  ),
  PoemItem(
    line1: 'A piac körtéss ládákkal ébred,',
    line2: 'édes őszi illat száll a levegőben.',
    lures: [
      'hideg téli eső mindenütt.',
      'hangos gyerekek futnak lépcsőről lépcsőre.',
      'meleg kenyeret szelnek gyöngéd gonddal.',
    ],
  ),
  PoemItem(
    line1: 'Álmos vonat gördül a tanya mellett,',
    line2: 'füttye óvja az éjt a bajtól.',
    lures: [
      'kerekei patákkal tartják az ütemet.',
      'lámpái fényesen égnek a hidegben.',
      'füstje finom fonalból sző gyűrűket.',
    ],
  ),
  PoemItem(
    line1: 'A hegedűs egy húrt hangol,',
    line2: 's az üres termek dalra kelnek.',
    lures: [
      's a festett madarak szárnyra kelnek.',
      'míg őszi levelek szállnak s lengenek.',
      's a gyertyák aranygyűrűt csepegtetnek.',
    ],
  ),
  PoemItem(
    line1: 'Kerti csiga ezüstnyomon jár,',
    line2: 'túléli a szelet, a jeget, a vihart.',
    lures: [
      'lefutja a postást s a postát.',
      's papírvitorlás hajókról álmodik.',
      'míg rózsák bólogatnak a kerítésen túl.',
    ],
  ),
  PoemItem(
    line1: 'Az órás büszkén húzza fel a gépet,',
    line2: 's az éjfél szélesen menetel.',
    lures: [
      's a déli szundikat félredobják.',
      'míg ingák lengenek ritmusra.',
      's a reggeli harangok felerősödnek.',
    ],
  ),
];

const dayEventPoolHu = <String>[
  'ébresztőre ébredt',
  'fogat mosott',
  'reggeli kávét főzött',
  'megetette a macskát',
  'megnézte a buszidőt',
  'busszal ment a belvárosba',
  'vett egy meleg zsemlét',
  'kinyitotta a tanterem ajtaját',
  'felírta a dátumot a táblára',
  'kölcsönkért egy piros tollat',
  'barátokkal ebédelt',
  'visszahívta anyát',
  'feladta a csomagot',
  'kocogott a park körül',
  'meglocsolta a balkonnövényeket',
  'tésztát főzött vacsorára',
  'olvasott húsz oldalt',
  'újra beállította az ébresztőt',
];

const extraConcreteNounsHu = <String>[
  'makk',
  'hátizsák',
  'vödör',
  'gomb',
  'kanyon',
  'cseresznye',
  'tőr',
  'dob',
  'furulya',
  'szőlő',
  'hárfa',
  'sisak',
  'dzseki',
  'vízforraló',
  'létra',
  'mágnes',
  'fészek',
  'tutaj',
  'kard',
  'sátor',
  'trombita',
  'váza',
  'pénztárca',
  'zebra',
];

const extraPictureScenesHu = <String, List<String>>{
  'napos pékség': [
    'lisztfelhő',
    'perecállvány',
    'alvó macska',
    'rézcsengő',
    'meggyes pite',
    'fapenge',
  ],
  'kikötői móló': [
    'feltekert kötél',
    'siró sirály',
    'piros bója',
    'halasládák',
    'világítótorony fénye',
    'olajos szivárvány',
  ],
  'őszi erdő': [
    'vörös juhar',
    'szarvascsapás',
    'mohás rönk',
    'varjúkárogás',
    'makkhalom',
    'ködpad',
  ],
  'éjszakai csillagvizsgáló': [
    'réztávcső',
    'csillagtérkép',
    'piros lámpa',
    'csigalépcső',
    'kávésbögre',
    'nyitott kupola',
  ],
  'iskolai tornaterem': [
    'mászókötelek',
    'síp',
    'rakott szőnyegek',
    'eredményjelző',
    'kosárlabdaállvány',
    'krétatálca',
  ],
  'borbélyüzlet': [
    'csíkos oszlop',
    'bőrszék',
    'borotvahab',
    'falitükrök',
    'arcszeszes üvegek',
    'várakozópad',
  ],
  'tóparti táborhely': [
    'narancssátor',
    'tábortűzfüst',
    'kenutároló',
    'lámpásoszlop',
    'pillecukros zacskó',
    'búvárkiáltás',
  ],
  'művészeti galéria': [
    'márványmellszobor',
    'bársonykötél',
    'tetőablak',
    'nyikorgó padló',
    'őrzsámoly',
    'bronzplakett',
  ],
};
