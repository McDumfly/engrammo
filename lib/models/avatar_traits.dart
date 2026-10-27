library;

class TraitOption {
  final String label;
  final String labelEn;
  final String value;
  const TraitOption(this.label, this.value, [this.labelEn = '']);
}

abstract final class AvatarTraits {
  static const Map<String, List<TraitOption>> traits = {
    'skinColor': [
      TraitOption('614335', '614335'),
      TraitOption('d08b5b', 'd08b5b'),
      TraitOption('ae5d29', 'ae5d29'),
      TraitOption('edb98a', 'edb98a'),
      TraitOption('ffdbb4', 'ffdbb4'),
      TraitOption('fd9841', 'fd9841'),
      TraitOption('f8d25c', 'f8d25c'),
    ],
    'eyes': [
      TraitOption('Default', 'default', 'Default'),
      TraitOption('Closed', 'closed', 'Closed'),
      TraitOption('Crying', 'cry', 'Crying'),
      TraitOption('Eye roll', 'eyeRoll', 'Eye roll'),
      TraitOption('Happy', 'happy', 'Happy'),
      TraitOption('Heart eyes', 'hearts', 'Heart eyes'),
      TraitOption('Side glance', 'side', 'Side glance'),
      TraitOption('Squint', 'squint', 'Squint'),
      TraitOption('Surprised', 'surprised', 'Surprised'),
      TraitOption('Wink', 'wink', 'Wink'),
      TraitOption('Wink 2', 'winkWacky', 'Wink 2'),
      TraitOption('Dizzy', 'xDizzy', 'Dizzy'),
    ],
    'mouth': [
      TraitOption('Default', 'default', 'Default'),
      TraitOption('Concerned', 'concerned', 'Concerned'),
      TraitOption('Disbelief', 'disbelief', 'Disbelief'),
      TraitOption('Eating', 'eating', 'Eating'),
      TraitOption('Grimace', 'grimace', 'Grimace'),
      TraitOption('Sad', 'sad', 'Sad'),
      TraitOption('Screaming', 'screamOpen', 'Screaming'),
      TraitOption('Serious', 'serious', 'Serious'),
      TraitOption('Smile', 'smile', 'Smile'),
      TraitOption('Tongue out', 'tongue', 'Tongue out'),
      TraitOption('Twinkle', 'twinkle', 'Twinkle'),
      TraitOption('Vomiting', 'vomit', 'Vomiting'),
    ],
    'eyebrows': [
      TraitOption('Default', 'default', 'Default'),
      TraitOption('Angry', 'angry', 'Angry'),
      TraitOption('Angry (natural)', 'angryNatural', 'Angry (natural)'),
      TraitOption('Default (natural)', 'defaultNatural', 'Default (natural)'),
      TraitOption('Flat (natural)', 'flatNatural', 'Flat (natural)'),
      TraitOption('Frown (natural)', 'frownNatural', 'Frown (natural)'),
      TraitOption('Excited', 'raisedExcited', 'Excited'),
      TraitOption('Excited (natural)', 'raisedExcitedNatural', 'Excited (natural)'),
      TraitOption('Sad concerned', 'sadConcerned', 'Sad concerned'),
      TraitOption('Sad concerned (natural)', 'sadConcernedNatural', 'Sad concerned (natural)'),
      TraitOption('Unibrow (natural)', 'unibrowNatural', 'Unibrow (natural)'),
      TraitOption('Up-down', 'upDown', 'Up-down'),
      TraitOption('Up-down (natural)', 'upDownNatural', 'Up-down (natural)'),
    ],
    'top': [
      TraitOption('Short flat', 'shortFlat', 'Short flat'),
      TraitOption('Big hair', 'bigHair', 'Big hair'),
      TraitOption('Bob', 'bob', 'Bob'),
      TraitOption('Bun', 'bun', 'Bun'),
      TraitOption('Curly', 'curly', 'Curly'),
      TraitOption('Wavy', 'curvy', 'Wavy'),
      TraitOption('Dreadlocks', 'dreads', 'Dreadlocks'),
      TraitOption('Dreadlocks 1', 'dreads01', 'Dreadlocks 1'),
      TraitOption('Dreadlocks 2', 'dreads02', 'Dreadlocks 2'),
      TraitOption('Frida', 'frida', 'Frida'),
      TraitOption('Frizzle', 'frizzle', 'Frizzle'),
      TraitOption('Fro', 'fro', 'Fro'),
      TraitOption('Fro with headband', 'froBand', 'Fro with headband'),
      TraitOption('Hat', 'hat', 'Hat'),
      TraitOption('Hijab', 'hijab', 'Hijab'),
      TraitOption('Long', 'longButNotTooLong', 'Long'),
      TraitOption('Mia Wallace', 'miaWallace', 'Mia Wallace'),
      TraitOption('Shaggy', 'shaggy', 'Shaggy'),
      TraitOption('Shaggy mullet', 'shaggyMullet', 'Shaggy mullet'),
      TraitOption('Shaved sides', 'shavedSides', 'Shaved sides'),
      TraitOption('Short curly', 'shortCurly', 'Short curly'),
      TraitOption('Short round', 'shortRound', 'Short round'),
      TraitOption('Short wavy', 'shortWaved', 'Short wavy'),
      TraitOption('Side part', 'sides', 'Side part'),
      TraitOption('Straight 1', 'straight01', 'Straight 1'),
      TraitOption('Straight 2', 'straight02', 'Straight 2'),
      TraitOption('Straight with strand', 'straightAndStrand', 'Straight with strand'),
      TraitOption('Caesar', 'theCaesar', 'Caesar'),
      TraitOption('Caesar with side part', 'theCaesarAndSidePart', 'Caesar with side part'),
      TraitOption('Turban', 'turban', 'Turban'),
      TraitOption('Winter hat 2', 'winterHat02', 'Winter hat 2'),
      TraitOption('Winter hat 3', 'winterHat03', 'Winter hat 3'),
      TraitOption('Winter hat 4', 'winterHat04', 'Winter hat 4'),
      TraitOption('Winter hat 1', 'winterHat1', 'Winter hat 1'),
    ],
    'facialHair': [
      TraitOption('None', 'none', 'None'),
      TraitOption('Light beard', 'beardLight', 'Light beard'),
      TraitOption('Majestic beard', 'beardMajestic', 'Majestic beard'),
      TraitOption('Medium beard', 'beardMedium', 'Medium beard'),
      TraitOption('Fancy moustache', 'moustacheFancy', 'Fancy moustache'),
      TraitOption('Magnum moustache', 'moustacheMagnum', 'Magnum moustache'),
    ],
    'clothes': [
      TraitOption('Blazer and shirt', 'blazerAndShirt', 'Blazer and shirt'),
      TraitOption('Blazer and sweater', 'blazerAndSweater', 'Blazer and sweater'),
      TraitOption('Collar and sweater', 'collarAndSweater', 'Collar and sweater'),
      TraitOption('Graphic shirt', 'graphicShirt', 'Graphic shirt'),
      TraitOption('Hoodie', 'hoodie', 'Hoodie'),
      TraitOption('Overalls', 'overall', 'Overalls'),
      TraitOption('Crew neck', 'shirtCrewNeck', 'Crew neck'),
      TraitOption('Scoop neck', 'shirtScoopNeck', 'Scoop neck'),
      TraitOption('V-neck', 'shirtVNeck', 'V-neck'),
    ],
    'clothesGraphic': [
      TraitOption('Bat', 'bat', 'Bat'),
      TraitOption('Bear', 'bear', 'Bear'),
      TraitOption('Cumbia', 'cumbia', 'Cumbia'),
      TraitOption('Deer', 'deer', 'Deer'),
      TraitOption('Diamond', 'diamond', 'Diamond'),
      TraitOption('Hola', 'hola', 'Hola'),
      TraitOption('Pizza', 'pizza', 'Pizza'),
      TraitOption('Resist', 'resist', 'Resist'),
      TraitOption('Skull', 'skull', 'Skull'),
      TraitOption('Skull outline', 'skullOutline', 'Skull outline'),
    ],
    'accessories': [
      TraitOption('None', 'none', 'None'),
      TraitOption('Eyepatch', 'eyepatch', 'Eyepatch'),
      TraitOption('Kurt', 'kurt', 'Kurt'),
      TraitOption('Glasses 1', 'prescription01', 'Glasses 1'),
      TraitOption('Glasses 2', 'prescription02', 'Glasses 2'),
      TraitOption('Round', 'round', 'Round'),
      TraitOption('Sunglasses', 'sunglasses', 'Sunglasses'),
      TraitOption('Wayfarers', 'wayfarers', 'Wayfarers'),
    ],
    'hairColor': [
      TraitOption('a55728', 'a55728'),
      TraitOption('2c1b18', '2c1b18'),
      TraitOption('b58143', 'b58143'),
      TraitOption('d6b370', 'd6b370'),
      TraitOption('724133', '724133'),
      TraitOption('4a312c', '4a312c'),
      TraitOption('f59797', 'f59797'),
      TraitOption('ecdcbf', 'ecdcbf'),
      TraitOption('c93305', 'c93305'),
      TraitOption('e8e1e1', 'e8e1e1'),
    ],
    'facialHairColor': [
      TraitOption('a55728', 'a55728'),
      TraitOption('2c1b18', '2c1b18'),
      TraitOption('b58143', 'b58143'),
      TraitOption('d6b370', 'd6b370'),
      TraitOption('724133', '724133'),
      TraitOption('4a312c', '4a312c'),
      TraitOption('f59797', 'f59797'),
      TraitOption('ecdcbf', 'ecdcbf'),
      TraitOption('c93305', 'c93305'),
      TraitOption('e8e1e1', 'e8e1e1'),
    ],
    'clothesColor': [
      TraitOption('262e33', '262e33'),
      TraitOption('65c9ff', '65c9ff'),
      TraitOption('5199e4', '5199e4'),
      TraitOption('25557c', '25557c'),
      TraitOption('e6e6e6', 'e6e6e6'),
      TraitOption('929598', '929598'),
      TraitOption('3c4f5c', '3c4f5c'),
      TraitOption('b1e2ff', 'b1e2ff'),
      TraitOption('a7ffc4', 'a7ffc4'),
      TraitOption('ffafb9', 'ffafb9'),
      TraitOption('ffffb1', 'ffffb1'),
      TraitOption('ff488e', 'ff488e'),
      TraitOption('ff5c5c', 'ff5c5c'),
      TraitOption('ffffff', 'ffffff'),
    ],
    'hatColor': [
      TraitOption('262e33', '262e33'),
      TraitOption('65c9ff', '65c9ff'),
      TraitOption('5199e4', '5199e4'),
      TraitOption('25557c', '25557c'),
      TraitOption('e6e6e6', 'e6e6e6'),
      TraitOption('929598', '929598'),
      TraitOption('3c4f5c', '3c4f5c'),
      TraitOption('b1e2ff', 'b1e2ff'),
      TraitOption('a7ffc4', 'a7ffc4'),
      TraitOption('ffdeb5', 'ffdeb5'),
      TraitOption('ffafb9', 'ffafb9'),
      TraitOption('ffffb1', 'ffffb1'),
      TraitOption('ff488e', 'ff488e'),
      TraitOption('ff5c5c', 'ff5c5c'),
      TraitOption('ffffff', 'ffffff'),
    ],
    'accessoriesColor': [
      TraitOption('262e33', '262e33'),
      TraitOption('65c9ff', '65c9ff'),
      TraitOption('5199e4', '5199e4'),
      TraitOption('25557c', '25557c'),
      TraitOption('e6e6e6', 'e6e6e6'),
      TraitOption('929598', '929598'),
      TraitOption('3c4f5c', '3c4f5c'),
      TraitOption('b1e2ff', 'b1e2ff'),
      TraitOption('a7ffc4', 'a7ffc4'),
      TraitOption('ffdeb5', 'ffdeb5'),
      TraitOption('ffafb9', 'ffafb9'),
      TraitOption('ffffb1', 'ffffb1'),
      TraitOption('ff488e', 'ff488e'),
      TraitOption('ff5c5c', 'ff5c5c'),
      TraitOption('ffffff', 'ffffff'),
    ],
  };

  static const List<String> traitOrder = [
    'skinColor',
    'eyes',
    'mouth',
    'eyebrows',
    'top',
    'hairColor',
    'hatColor',
    'facialHair',
    'facialHairColor',
    'clothes',
    'clothesColor',
    'clothesGraphic',
    'accessories',
    'accessoriesColor',
  ];

  static const List<String> skinColors = [
    '614335',
    'd08b5b',
    'ae5d29',
    'edb98a',
    'ffdbb4',
    'fd9841',
    'f8d25c',
  ];
  static const List<String> eyesVariants = [
    'default',
    'closed',
    'cry',
    'eyeRoll',
    'happy',
    'hearts',
    'side',
    'squint',
    'surprised',
    'wink',
    'winkWacky',
    'xDizzy',
  ];
  static const List<String> mouthVariants = [
    'default',
    'concerned',
    'disbelief',
    'eating',
    'grimace',
    'sad',
    'screamOpen',
    'serious',
    'smile',
    'tongue',
    'twinkle',
    'vomit',
  ];
  static const List<String> eyebrowsVariants = [
    'default',
    'angry',
    'angryNatural',
    'defaultNatural',
    'flatNatural',
    'frownNatural',
    'raisedExcited',
    'raisedExcitedNatural',
    'sadConcerned',
    'sadConcernedNatural',
    'unibrowNatural',
    'upDown',
    'upDownNatural',
  ];
  static const List<String> topVariants = [
    'shortFlat',
    'bigHair',
    'bob',
    'bun',
    'curly',
    'curvy',
    'dreads',
    'dreads01',
    'dreads02',
    'frida',
    'frizzle',
    'fro',
    'froBand',
    'hat',
    'hijab',
    'longButNotTooLong',
    'miaWallace',
    'shaggy',
    'shaggyMullet',
    'shavedSides',
    'shortCurly',
    'shortRound',
    'shortWaved',
    'sides',
    'straight01',
    'straight02',
    'straightAndStrand',
    'theCaesar',
    'theCaesarAndSidePart',
    'turban',
    'winterHat02',
    'winterHat03',
    'winterHat04',
    'winterHat1',
  ];
  static const List<String> facialHairVariants = [
    'none',
    'beardLight',
    'beardMajestic',
    'beardMedium',
    'moustacheFancy',
    'moustacheMagnum',
  ];
  static const List<String> clothesVariants = [
    'blazerAndShirt',
    'blazerAndSweater',
    'collarAndSweater',
    'graphicShirt',
    'hoodie',
    'overall',
    'shirtCrewNeck',
    'shirtScoopNeck',
    'shirtVNeck',
  ];
  static const List<String> clothesGraphicVariants = [
    'bat',
    'bear',
    'cumbia',
    'deer',
    'diamond',
    'hola',
    'pizza',
    'resist',
    'skull',
    'skullOutline',
  ];
  static const List<String> accessoriesVariants = [
    'none',
    'eyepatch',
    'kurt',
    'prescription01',
    'prescription02',
    'round',
    'sunglasses',
    'wayfarers',
  ];

  static const List<String> hairColors = [
    'a55728',
    '2c1b18',
    'b58143',
    'd6b370',
    '724133',
    '4a312c',
    'f59797',
    'ecdcbf',
    'c93305',
    'e8e1e1',
  ];
  static const List<String> facialHairColors = [
    'a55728',
    '2c1b18',
    'b58143',
    'd6b370',
    '724133',
    '4a312c',
    'f59797',
    'ecdcbf',
    'c93305',
    'e8e1e1',
  ];
  static const List<String> clothesColors = [
    '262e33',
    '65c9ff',
    '5199e4',
    '25557c',
    'e6e6e6',
    '929598',
    '3c4f5c',
    'b1e2ff',
    'a7ffc4',
    'ffafb9',
    'ffffb1',
    'ff488e',
    'ff5c5c',
    'ffffff',
  ];
  static const List<String> hatColors = [
    '262e33',
    '65c9ff',
    '5199e4',
    '25557c',
    'e6e6e6',
    '929598',
    '3c4f5c',
    'b1e2ff',
    'a7ffc4',
    'ffdeb5',
    'ffafb9',
    'ffffb1',
    'ff488e',
    'ff5c5c',
    'ffffff',
  ];
  static const List<String> accessoriesColors = [
    '262e33',
    '65c9ff',
    '5199e4',
    '25557c',
    'e6e6e6',
    '929598',
    '3c4f5c',
    'b1e2ff',
    'a7ffc4',
    'ffdeb5',
    'ffafb9',
    'ffffb1',
    'ff488e',
    'ff5c5c',
    'ffffff',
  ];

  static Map<String, String> defaults() => {
    'skinColor': skinColors[0],
    'eyes': eyesVariants[0],
    'mouth': mouthVariants[0],
    'eyebrows': eyebrowsVariants[0],
    'top': topVariants[0],
    'facialHair': facialHairVariants[0],
    'clothes': clothesVariants[0],
    'clothesGraphic': clothesGraphicVariants[0],
    'accessories': accessoriesVariants[0],
    'hairColor': hairColors[0],
    'facialHairColor': facialHairColors[0],
    'clothesColor': clothesColors[0],
    'hatColor': hatColors[0],
    'accessoriesColor': accessoriesColors[0],
    'backgroundColor': 'ffffff',
  };

  static String buildDicebearUrl(Map<String, String> opts) {
    const format = 'svg';
    final queryParams = <String, dynamic>{'backgroundColor': 'transparent'};
    opts.forEach((key, value) {
      if (key == 'facialHair') {
        if (value == 'none') {
          queryParams['facialHairProbability'] = '0';
        } else {
          queryParams['facialHair'] = value;
          queryParams['facialHairProbability'] = '100';
        }
      } else if (key == 'accessories') {
        if (value == 'none') {
          queryParams['accessoriesProbability'] = '0';
        } else {
          queryParams['accessories'] = value;
          queryParams['accessoriesProbability'] = '100';
        }
      } else {
        queryParams[key] = value;
      }
    });

    final uri = Uri.https(
      'api.dicebear.com',
      '/9.x/avataaars/$format',
      queryParams,
    );
    return uri.toString();
  }

  static Map<String, String> fromFirestore(Map<String, dynamic>? raw) {
    final d = defaults();
    if (raw == null) return d;
    for (final key in traitOrder) {
      final v = raw[key];
      if (v is String && v.isNotEmpty) d[key] = v;
    }
    final bg = raw['backgroundColor'];
    if (bg is String && bg.isNotEmpty) d['backgroundColor'] = bg;
    return d;
  }
}

String avatarTraitGroupLabel(String groupKey) {
  switch (groupKey) {
    case 'skinColor': return 'Skin';
    case 'eyes': return 'Eyes';
    case 'mouth': return 'Mouth';
    case 'eyebrows': return 'Brows';
    case 'top': return 'Hair';
    case 'hairColor': return 'Hair color';
    case 'hatColor': return 'Hat color';
    case 'facialHair': return 'Beard';
    case 'facialHairColor': return 'Beard color';
    case 'clothes': return 'Outfit';
    case 'clothesColor': return 'Outfit color';
    case 'clothesGraphic': return 'Print';
    case 'accessories': return 'Extras';
    case 'accessoriesColor': return 'Extras color';
    default: return groupKey;
  }
}
