library;

class LessonHu {
  final String title;
  final String detail;
  const LessonHu(this.title, this.detail);
}

class SectionHu {
  final String name;
  final String technique;
  final List<LessonHu> lessons;
  const SectionHu({
    required this.name,
    required this.technique,
    required this.lessons,
  });
}

class ChapterHu {
  final String realm;
  final String tagline;
  final List<SectionHu> sections;
  const ChapterHu({
    required this.realm,
    required this.tagline,
    required this.sections,
  });
}

const chaptersHu = <ChapterHu>[
  ChapterHu(
    realm: 'Visszhangösvény',
    tagline: 'Kapd el a pillanatot: figyelj, mondd vissza.',
    sections: [
      SectionHu(
        name: 'Figyelemkapu',
        technique: 'a következő-tétel hatás blokkolása',
        lessons: [
          LessonHu('1 név, csendben', 'tudatos szünet'),
          LessonHu('2 név egymás után', 'azonnali felidézés'),
          LessonHu('Bemutatkozások közben', 'tedd félre a saját szereped'),
          LessonHu('3 név, 5 másodperc', 'kérdezd a helyesírást'),
        ],
      ),
      SectionHu(
        name: 'Hangvillanás',
        technique: 'akusztikus átkódolás',
        lessons: [
          LessonHu('3 tétel, 3 mp', 'villanó számjegyek'),
          LessonHu('5 tétel, 2 mp', 'felezett idő'),
          LessonHu('Hallott név vissza', 'hangból mozgáskód'),
          LessonHu('7 tétel, 1 mp', 'engramvillanás'),
        ],
      ),
      SectionHu(
        name: 'Zajos mező',
        technique: 'szelektív figyelem',
        lessons: [
          LessonHu('3 tétel zajban', 'háttércsevegéssel'),
          LessonHu('5 tétel zajban', 'zenével'),
          LessonHu('Vegyesen, sorrendben', 'a sorrend tartása'),
          LessonHu('Záróvizsga', '7 tétel, zaj, időre'),
        ],
      ),
    ],
  ),
  ChapterHu(
    realm: 'Tömbkovács',
    tagline: 'Csomagolj nagyban: alakíts számokat képekké.',
    sections: [
      SectionHu(
        name: 'Számtömbök',
        technique: 'tömbösítés • 3 jegyű kódok',
        lessons: [
          LessonHu('4 számjegy', 'két tömbbe'),
          LessonHu('6 számjegy', 'fonetikus képekkel'),
          LessonHu('9 számjegy', 'három tömb'),
          LessonHu('12 számjegy', 'kódrendszerrel'),
        ],
      ),
      SectionHu(
        name: 'Kártyapakli',
        technique: 'kártyarendszerek',
        lessons: [
          LessonHu('4 lap sorrendben', 'vizuális tömbök'),
          LessonHu('8 lap', 'két állomáson át'),
          LessonHu('13 lap, egy szín', 'teljes színsor'),
          LessonHu('Fél pakli', '26 lap egymás után'),
        ],
      ),
      SectionHu(
        name: 'LTWM-csúcs',
        technique: 'előhívási struktúrák',
        lessons: [
          LessonHu('20 számjegy', 'palotába ültetve'),
          LessonHu('32 számjegy', 'azonnali hozzáférés'),
          LessonHu('Teljes pakli', '52 lap egy sétán'),
          LessonHu('Hosszúlista-ismétlés', '100 számjegy'),
        ],
      ),
    ],
  ),
  ChapterHu(
    realm: 'Palotaépítő',
    tagline: 'Építs palotát a fejedben, aztán sétálj végig rajta.',
    sections: [
      SectionHu(
        name: 'Első szoba',
        technique: 'loci-módszer • 5 állomás',
        lessons: [
          LessonHu('3 tétel, 1 szoba', 'kész 3D szoba'),
          LessonHu('5 tétel', 'rögzített nézőpontok'),
          LessonHu('5 tétel visszafelé', 'fordított séta'),
          LessonHu('7 tétel', 'két szoba'),
        ],
      ),
      SectionHu(
        name: 'Szigetútvonal',
        technique: 'WIM kettős nézet',
        lessons: [
          LessonHu('10 állomás', 'miniatűr térképpel'),
          LessonHu('15 állomás', 'virtuális sziget'),
          LessonHu('20 állomás', 'egyes szám első személyben'),
          LessonHu('27 tétel', 'hosszú lista'),
        ],
      ),
      SectionHu(
        name: 'Saját palotám',
        technique: 'valódi útvonal • fejben',
        lessons: [
          LessonHu('A szobám, 5 tétel', 'ismerős tér'),
          LessonHu('Lakásséta, 10 tétel', 'szobáról szobára'),
          LessonHu('Utcai séta, 20 tétel', 'napi sétaútvonal'),
          LessonHu('Fejben, térkép nélkül', 'tiszta fejpalota'),
        ],
      ),
    ],
  ),
  ChapterHu(
    realm: 'Képlabor',
    tagline: 'Fess bizarr képeket szavakból.',
    sections: [
      SectionHu(
        name: 'Kettős kódolás',
        technique: 'szó + kép együtt',
        lessons: [
          LessonHu('5 tétel képekben', 'konkrét szavak'),
          LessonHu('8 tétel', 'mozgással'),
          LessonHu('12 elvont szó', 'képfölény'),
          LessonHu('15 elvont szó', 'mindenre egy szimbólum'),
        ],
      ),
      SectionHu(
        name: 'A kilógó',
        technique: 'Von Restorff-izoláció',
        lessons: [
          LessonHu('Kilógó az 5-ből', 'egyetlen feltűnő tétel'),
          LessonHu('Kilógó a 8-ból', 'hasonló hívószavak közt'),
          LessonHu('12 közül, vegyesen', 'méret- és színizoláció'),
          LessonHu('15 közül, időre', 'engramizoláció'),
        ],
      ),
      SectionHu(
        name: 'Bizarr mozi',
        technique: 'humorhatás',
        lessons: [
          LessonHu('3 bizarr kép', 'abszurd párosítások'),
          LessonHu('5 mozgó jelenet', 'túlzás + mozgás'),
          LessonHu('8 eltúlzott kép', 'óriási és apró'),
          LessonHu('10 láncolt jelenet', 'egybefüggő film'),
        ],
      ),
    ],
  ),
  ChapterHu(
    realm: 'Napló- és lociséta',
    tagline: 'Sétálj végig újra a napodon, este is.',
    sections: [
      SectionHu(
        name: 'Napi napló',
        technique: 'sorrendi visszajátszás',
        lessons: [
          LessonHu('3 mai esemény', 'sorrendben'),
          LessonHu('5 esemény egymás után', 'kihagyás nélkül'),
          LessonHu('Reggeltől estig, 7', 'a teljes ív'),
          LessonHu('Tegnap + ma', 'két nap láncolva'),
        ],
      ),
      SectionHu(
        name: 'Idő- és helyhorgonyok',
        technique: 'kontextuális horgonyzás',
        lessons: [
          LessonHu('Hol-mikor, 3 pár', 'helyekhez kötve'),
          LessonHu('5 pár', 'iránytűvel'),
          LessonHu('7 pár', 'idősávokkal'),
          LessonHu('10 pár vegyesen', 'véletlen sorrendben'),
        ],
      ),
      SectionHu(
        name: 'Esti séta',
        technique: 'loci-visszajátszás • alvás',
        lessons: [
          LessonHu('Palota, 5 állomás', 'lefekvés előtt'),
          LessonHu('10 állomás éjjel', 'mikroismétlés'),
          LessonHu('20 állomás', 'teljes végigsétálás'),
          LessonHu('Éjszakai konszolidáció', 'reggeli felidézés'),
        ],
      ),
    ],
  ),
  ChapterHu(
    realm: 'Név–arc szintetizátor',
    tagline: 'Hálózatok nevekből, arcokból, szavakból.',
    sections: [
      SectionHu(
        name: 'Baker-törő',
        technique: 'Morris 3 lépés • d ≈ 2,4',
        lessons: [
          LessonHu('2 név + archívószó', 'domináns vonás'),
          LessonHu('4 név', 'név-kép + kölcsönhatás'),
          LessonHu('6 név, 30 mp után', 'késleltetett felidézés'),
          LessonHu('8 név percekkel később', 'tartós tárolás'),
        ],
      ),
      SectionHu(
        name: 'Kulcsszólánc',
        technique: 'Atkinson–Raugh-módszer',
        lessons: [
          LessonHu('3 idegen szó', 'anyanyelvi kulcsszó'),
          LessonHu('5 szó', 'vizuális jelenettel'),
          LessonHu('8 szó', 'szakkifejezések'),
          LessonHu('12 szó segítség nélkül', 'önálló lánc'),
        ],
      ),
      SectionHu(
        name: 'Jelentésháló',
        technique: 'feldolgozási mélység',
        lessons: [
          LessonHu('3 szócsalád', 'etimológiával'),
          LessonHu('5 háló', 'fogalmi csomópontok'),
          LessonHu('8 lánc', 'mély kidolgozás'),
          LessonHu('12 perces villám', 'vegyes ismétlés'),
        ],
      ),
    ],
  ),
  ChapterHu(
    realm: 'Profi labor',
    tagline: 'Professzionális technikák lépésről lépésre: palota, kódok, nevek.',
    sections: [
      SectionHu(
        name: 'Palotaműhely',
        technique: 'loci-módszer • Maguire 2003',
        lessons: [
          LessonHu('Első 5 állomásod', 'egy útvonal, rögzített sorrend'),
          LessonHu('10 állomás, egy útvonal', 'csak elkülönülő locik'),
          LessonHu('Helyezz el 10 szót', 'állomásonként egy jelenet'),
          LessonHu('15 szavas séta', 'időzített bevésés'),
          LessonHu('20 állomás vakon', 'lesés nélkül'),
          LessonHu('Teljes palotafelidézés', 'tiszta sétavizsga'),
        ],
      ),
      SectionHu(
        name: 'Számrendszerek',
        technique: 'Major + PAO • Ericsson és Kintsch',
        lessons: [
          LessonHu('Major 0–9', 'tíz rögzített kép'),
          LessonHu('Első PAO-hármas', 'személy-cselekvés-tárgy'),
          LessonHu('00–19 képek', 'húsz pár rögzítve'),
          LessonHu('6 jegyű jelenetek', 'mindegyik egy állomás'),
          LessonHu('12 jegyű láncok', 'két állomás összekötve'),
          LessonHu('30 számjegy, egy menet', 'rendszervizsga'),
        ],
      ),
      SectionHu(
        name: 'Név- és szólabor',
        technique: 'kulcsszó + arc-név • Atkinson 1975',
        lessons: [
          LessonHu('Kulcsszóalapok', 'hasonló hangzás + kép'),
          LessonHu('5 idegen szó', 'mindkét irányban'),
          LessonHu('Arc-név 3 lépés', 'vonás-kép-kölcsönhatás'),
          LessonHu('6 arc, késleltetve', 'felidézés 5 perc után'),
          LessonHu('10 szó, egy történet', 'futó lánc'),
          LessonHu('Vegyes felidézés', 'vegyes nevek + szavak'),
        ],
      ),
    ],
  ),
  ChapterHu(
    realm: 'Nagy erőpróba',
    tagline: 'Időzített döntők sprintformátumban — gyakorlás, nem rekordok.',
    sections: [
      SectionHu(
        name: 'Sebességszámok',
        technique: '80 jegyes sprint • döntőformátum',
        lessons: [
          LessonHu('20 számjegy, 60 mp', 'egyenletes tempó'),
          LessonHu('40 számjegy, 60 mp', 'dupla terhelés'),
          LessonHu('60 számjegy, 45 mp', 'nyomás alatt'),
          LessonHu('80 számjegy, 60 mp', 'döntőtáv'),
          LessonHu('80 számjegy, 30 mp', 'sprinttempó'),
          LessonHu('80 számjegy, 20 mp', 'cúcstempó'),
        ],
      ),
      SectionHu(
        name: 'Kártyacápa',
        technique: 'PAO kártyarendszer • időzített forma',
        lessons: [
          LessonHu('10 lap sorrendben', 'három jelenet'),
          LessonHu('Fél pakli, 5 perc', 'kilenc jelenet'),
          LessonHu('Teljes pakli, 10 perc', 'tizenhét jelenet'),
          LessonHu('Teljes pakli, 5 perc', 'felezett idő'),
          LessonHu('Teljes pakli, 2 perc', 'élénk tempó'),
          LessonHu('Sebességkártya, 60 mp', 'döntő kör'),
        ],
      ),
      SectionHu(
        name: 'Palotamaraton',
        technique: '27 tételes séta • Dresler 2017',
        lessons: [
          LessonHu('15 tételes séta', 'egy palota'),
          LessonHu('20 tételes séta', 'kibővített útvonal'),
          LessonHu('27 tételes séta', 'labormérföldkő'),
          LessonHu('50 tételes palota', 'nagy útvonal'),
          LessonHu('100 szavas palota', 'többpalotás lánc'),
          LessonHu('Nagydöntő', 'vegyes alapozó ismétlés'),
        ],
      ),
    ],
  ),
  ChapterHu(
    realm: 'Visszhangkamra',
    tagline: 'Hosszabb visszhangok: ritmus, késleltetés, visszajátszás.',
    sections: [
      SectionHu(
        name: 'Ritmuskódok',
        technique: 'ütem szerinti csoportosítás',
        lessons: [
          LessonHu('4 ütem, egy csoport', 'tapsold a mintát'),
          LessonHu('6 ütem, két csoport', 'két csoportosított ütem'),
          LessonHu('8 ütem, páratlan metrum', 'tört ritmus'),
          LessonHu('10 ütem, visszahívás', 'hosszú minta'),
        ],
      ),
      SectionHu(
        name: 'Késleltetett visszhang',
        technique: 'a nyom megtartása',
        lessons: [
          LessonHu('3 tétel, 10 mp', 'várj, aztán idézd fel'),
          LessonHu('5 tétel, 20 mp', 'néma tartás'),
          LessonHu('5 tétel, 60 mp', 'zavaró tényezővel'),
          LessonHu('7 tétel, 30 mp', 'késleltetett döntő'),
        ],
      ),
      SectionHu(
        name: 'Egymást fedő hangok',
        technique: 'koktélparti-fókusz',
        lessons: [
          LessonHu('Két hang, egy cél', 'kövesd az egyik szálat'),
          LessonHu('Három hang', 'zsúfolt szoba'),
          LessonHu('Hang plusz zene', 'dallam a tetején'),
          LessonHu('Bulivizsga', 'zajos felidézés'),
        ],
      ),
    ],
  ),
  ChapterHu(
    realm: 'Hangpalota',
    tagline: 'Szegezd a hangokat helyekre és képekre.',
    sections: [
      SectionHu(
        name: 'Hangképek',
        technique: 'auditív kettős kódolás',
        lessons: [
          LessonHu('3 hang képekben', 'mindegyik egy kép'),
          LessonHu('5 hang képekben', 'mozgó képek'),
          LessonHu('7 hang képekben', 'abszurd párosítások'),
          LessonHu('10 hang képekben', 'teljes galéria'),
        ],
      ),
      SectionHu(
        name: 'Dallamútvonalak',
        technique: 'locik sorozatokhoz',
        lessons: [
          LessonHu('4 hang, 4 állomás', 'ismert útvonal'),
          LessonHu('6 hang útvonalon', 'szobáról szobára'),
          LessonHu('8 hang útvonalon', 'kibővített séta'),
          LessonHu('10 hang útvonalon', 'tiszta sétavizsga'),
        ],
      ),
      SectionHu(
        name: 'Hangszíncímkék',
        technique: 'megkülönböztető bevésés',
        lessons: [
          LessonHu('Magas vs mély', 'hangmagasság-címkék'),
          LessonHu('Hangos vs halk', 'hangerő-címkék'),
          LessonHu('Gyors vs lassú', 'tempócímkék'),
          LessonHu('Vegyes címkevizsga', 'minden hívószó egyszerre'),
        ],
      ),
    ],
  ),
  ChapterHu(
    realm: 'Koncertterem',
    tagline: 'Gyors, hangos, hosszú: nyomás alatti edzés.',
    sections: [
      SectionHu(
        name: 'Sebességvisszhang',
        technique: 'gyors bevésés',
        lessons: [
          LessonHu('5 tétel, 5 mp', 'másodpercenként egy'),
          LessonHu('7 tétel, 5 mp', 'gyorsabb folyam'),
          LessonHu('10 tétel, 10 mp', 'koncerttempó'),
          LessonHu('12 tétel, 10 mp', 'sprintdöntő'),
        ],
      ),
      SectionHu(
        name: 'Tömegszűrő',
        technique: 'figyelem terhelés alatt',
        lessons: [
          LessonHu('5 tétel, tömegzaj', 'stabil szűrő'),
          LessonHu('7 tétel, hangos tömeg', 'nyomás alatt'),
          LessonHu('7 tétel, vegyes zaj', 'zene plusz csevegés'),
          LessonHu('10 tétel, telt ház', 'tömegvizsga'),
        ],
      ),
      SectionHu(
        name: 'Hosszú visszajátszások',
        technique: 'kibővített echoikus terjedelem',
        lessons: [
          LessonHu('12 tétel, lassan', 'gondos befogadás'),
          LessonHu('15 tétel, lassan', 'hosszú sorozat'),
          LessonHu('15 tétel, normál', 'teremtempó'),
          LessonHu('20 tétel, egy menet', 'maratonvisszhang'),
        ],
      ),
    ],
  ),
  ChapterHu(
    realm: 'Aranyfül',
    tagline: 'A hallás döntője: nevek, sorozatok, késleltetések.',
    sections: [
      SectionHu(
        name: 'Számsprint',
        technique: 'telefonszámok hallásból',
        lessons: [
          LessonHu('7 számjegy hallásból', 'egy hallásra'),
          LessonHu('10 számjegy hallásból', 'élőben tömbösítve'),
          LessonHu('12 számjegy zajban', 'utcai teszt'),
          LessonHu('15 számjegy, egy menet', 'sprintvizsga'),
        ],
      ),
      SectionHu(
        name: 'Beszédárnyékolás',
        technique: 'ismétlés hallgatás közben',
        lessons: [
          LessonHu('Rövid fordulatok', 'azonnali visszhang'),
          LessonHu('Hosszú mondatok', 'félütemes késés'),
          LessonHu('Gyors beszéd', 'hírolvasó-tempó'),
          LessonHu('Történetárnyékolás', 'két perc egyben'),
        ],
      ),
      SectionHu(
        name: 'Aranyfül-ismétlés',
        technique: 'edzett hallás ismétlése',
        lessons: [
          LessonHu('Nevek zajban', 'bulidöntő'),
          LessonHu('20 tételes sorozat', 'koncertdöntő'),
          LessonHu('Minden késleltetve', 'felidézés késés után'),
          LessonHu('Aranyfül', 'hallásismétlés'),
        ],
      ),
    ],
  ),
  ChapterHu(
    realm: 'Számműhely',
    tagline: 'Minden számhoz egy rögzített kép.',
    sections: [
      SectionHu(
        name: 'Major 00–19',
        technique: 'mássalhangzókódok',
        lessons: [
          LessonHu('Major 0–4', 'öt rögzített kép'),
          LessonHu('Major 5–9', 'tíz rögzített kép'),
          LessonHu('10–14 párok', 'első párok'),
          LessonHu('15–19 párok', 'húsz kód'),
        ],
      ),
      SectionHu(
        name: 'Képpárok',
        technique: 'azonnali párfelidézés',
        lessons: [
          LessonHu('10 pár, lassan', 'cél: habozás nélkül'),
          LessonHu('20 pár, lassan', 'teljes készletséta'),
          LessonHu('20 pár, gyorsan', 'páronként két mp'),
          LessonHu('Párvizsga', 'azonnali felidézés'),
        ],
      ),
      SectionHu(
        name: 'Első PAO-jelenetek',
        technique: 'személy-cselekvés-tárgy',
        lessons: [
          LessonHu('Egy PAO-jelenet', 'hat számjegy, egy kép'),
          LessonHu('Három jelenet', 'tizennyolc számjegy'),
          LessonHu('Öt jelenet', 'harminc számjegy'),
          LessonHu('PAO-bemutatkozó ismétlés', 'stabil felidézés'),
        ],
      ),
    ],
  ),
  ChapterHu(
    realm: 'Kártyastúdió',
    tagline: 'Minden lapból egy személy lesz.',
    sections: [
      SectionHu(
        name: 'Színszemélyek',
        technique: 'rögzített kártyaképek',
        lessons: [
          LessonHu('Egy szín, 13 arc', 'előbb a kőr'),
          LessonHu('Két szín', 'huszonhat arc'),
          LessonHu('Négy szín', 'teljes szereplőgárda'),
          LessonHu('Szereplővizsga', 'bármely lap, azonnal'),
        ],
      ),
      SectionHu(
        name: 'Akciókapcsok',
        technique: 'kétlapos jelenetek',
        lessons: [
          LessonHu('4 lap, 2 jelenet', 'személy találkozik személlyel'),
          LessonHu('6 lap, 2 jelenet', 'PAO-párok'),
          LessonHu('9 lap, 3 jelenet', 'folyamatos sor'),
          LessonHu('12 lap sorrendben', 'négy jelenet tisztán'),
        ],
      ),
      SectionHu(
        name: 'Félpaklis folyamok',
        technique: 'palotás kártyasorok',
        lessons: [
          LessonHu('13 lap, 10 perc', 'lassan és tisztán'),
          LessonHu('20 lap, 10 perc', 'hosszabb sor'),
          LessonHu('26 lap, 10 perc', 'fél pakli'),
          LessonHu('Félpaklis vizsga', 'kihagyott jelenet nélkül'),
        ],
      ),
    ],
  ),
  ChapterHu(
    realm: 'Fejszámoló',
    tagline: 'Tarts meg többet, fordíts gyorsabban, frissíts tisztán.',
    sections: [
      SectionHu(
        name: 'Futó összegek',
        technique: 'frissítő gyakorlat',
        lessons: [
          LessonHu('Adj össze 5 számot', 'tartsd az összeget'),
          LessonHu('Összeadás és eldobás', 'frissítsd az összeget'),
          LessonHu('Adj össze 10 számot', 'hosszú futó összeg'),
          LessonHu('Összegismétlés', 'stabil pontosság'),
        ],
      ),
      SectionHu(
        name: 'Fordított láncok',
        technique: 'fordított terjedelem',
        lessons: [
          LessonHu('4 vissza', 'rövid megfordítás'),
          LessonHu('6 vissza', 'teljes fordítás'),
          LessonHu('8 vissza', 'hosszú megfordítás'),
          LessonHu('Fordított vizsga', 'lesés nélkül'),
        ],
      ),
      SectionHu(
        name: 'Kettős feladatok',
        technique: 'végrehajtó terhelés',
        lessons: [
          LessonHu('Tartás plusz számolás', 'két munka egyszerre'),
          LessonHu('Tartás plusz rendezés', 'átrendezés tartás közben'),
          LessonHu('Dupla sorozat', 'két szál'),
          LessonHu('Kettős vizsga', 'mindkét szál tisztán'),
        ],
      ),
    ],
  ),
  ChapterHu(
    realm: 'Palotanegyed',
    tagline: 'Több palota, több állomás, élesen elkülönítve.',
    sections: [
      SectionHu(
        name: 'Második palota',
        technique: 'friss útvonal • 15 állomás',
        lessons: [
          LessonHu('Új útvonal, 5 állomás', 'egy második otthon'),
          LessonHu('10 állomás', 'csak elkülönülő locik'),
          LessonHu('15 állomás', 'teljes második palota'),
          LessonHu('Kétpalotás kvíz', 'áthallás nélkül'),
        ],
      ),
      SectionHu(
        name: 'Palotaösszekötés',
        technique: 'láncolt útvonalak',
        lessons: [
          LessonHu('Köss össze két palotát', 'egy nagy séta'),
          LessonHu('30 állomás összekötve', 'negyedséta'),
          LessonHu('40 állomás összekötve', 'hosszú negyed'),
          LessonHu('Negyedvizsga', 'tiszta teljes séta'),
        ],
      ),
      SectionHu(
        name: 'Palotakarbantartás',
        technique: 'kísértetirtás • újrafelhasználás',
        lessons: [
          LessonHu('Kísértetvadászat', 'avas képek kiszúrása'),
          LessonHu('Törlés és újrafelhasználás', 'palota kitakarítása'),
          LessonHu('Pihentess egy palotát', 'három útvonal forgatása'),
          LessonHu('Karbantartásvizsga', 'csak friss képek'),
        ],
      ),
    ],
  ),
  ChapterHu(
    realm: 'Sebességbevésés',
    tagline: 'Állomásonként egy pillantás, teljes sebességgel.',
    sections: [
      SectionHu(
        name: '5 másodperces jelenetek',
        technique: 'időzített elhelyezés',
        lessons: [
          LessonHu('5 jelenet, lassan', 'jelenetenként tíz mp'),
          LessonHu('10 jelenet, időre', 'jelenetenként öt mp'),
          LessonHu('15 jelenet, időre', 'második pillantás nélkül'),
          LessonHu('Sebességjelenet-vizsga', 'gyorsan és ragadósan'),
        ],
      ),
      SectionHu(
        name: 'Egymenetes séták',
        technique: 'visszatérés nélküli bevésés',
        lessons: [
          LessonHu('10 tétel, egy menet', 'sétálj egyszer'),
          LessonHu('15 tétel, egy menet', 'dönts és menj'),
          LessonHu('20 tétel, egy menet', 'bízz a sétában'),
          LessonHu('Egymenetes vizsga', 'egysétás felidézés'),
        ],
      ),
      SectionHu(
        name: 'Hibajavítás',
        technique: 'állomás-triázs',
        lessons: [
          LessonHu('Keresd meg a rést', 'gyenge állomások felkutatása'),
          LessonHu('Építs újra 3 állomást', 'erősebb képek'),
          LessonHu('Teljes újraséta', 'a javítás ellenőrzése'),
          LessonHu('Javítóvizsga', 'résmentes séta'),
        ],
      ),
    ],
  ),
  ChapterHu(
    realm: 'Nagypalota',
    tagline: 'A hosszú séta: 100 állomás, egy útvonal.',
    sections: [
      SectionHu(
        name: 'Nagy útvonal',
        technique: '50 állomásos palota',
        lessons: [
          LessonHu('30 állomás', 'nagy megnyitó'),
          LessonHu('40 állomás', 'kibővített szárnyak'),
          LessonHu('50 állomás', 'teljes nagy útvonal'),
          LessonHu('Nagyútvonal-vizsga', 'egy tiszta séta'),
        ],
      ),
      SectionHu(
        name: 'Többpalotás lánc',
        technique: '100 állomásos lánc',
        lessons: [
          LessonHu('60 állomás', 'két palota láncolva'),
          LessonHu('80 állomás', 'három palota'),
          LessonHu('100 állomás', 'hosszú táv'),
          LessonHu('Láncismétlés', 'stabil kapcsok'),
        ],
      ),
      SectionHu(
        name: 'Nagy séta',
        technique: 'hosszúútvonal-ismétlés',
        lessons: [
          LessonHu('50 szó, egy séta', 'nagydöntő 1. szakasz'),
          LessonHu('100 szó, egy séta', 'nagydöntő 2. szakasz'),
          LessonHu('Vak újraséta', 'felidézés másnap reggel'),
          LessonHu('Nagypalota', 'hosszúútvonal-ismétlés'),
        ],
      ),
    ],
  ),
  ChapterHu(
    realm: 'Részletstúdió',
    tagline: 'Ikrek, minták, színek: vegyél észre mindent.',
    sections: [
      SectionHu(
        name: 'Ikervadász',
        technique: 'finom megkülönböztetés',
        lessons: [
          LessonHu('Szúrj ki 1 különbséget', 'két közel-iker'),
          LessonHu('Szúrj ki 3 különbséget', 'zsúfolt ikrek'),
          LessonHu('Szúrj ki 5 különbséget', 'időzített ikrek'),
          LessonHu('Ikerismétlés', 'éles szemek'),
        ],
      ),
      SectionHu(
        name: 'Mintatrezor',
        technique: 'elvont bevésés',
        lessons: [
          LessonHu('3x3-as minták', 'nevezz meg minden motívumot'),
          LessonHu('5x5-ös minták', 'tömbösítsd a rácsot'),
          LessonHu('Forgatások', 'ugyanaz, de elforgatva'),
          LessonHu('Trezorvizsga', 'rajzold le emlékezetből'),
        ],
      ),
      SectionHu(
        name: 'Színkódok',
        technique: 'színcímkézés',
        lessons: [
          LessonHu('4 színcímke', 'mindegyik egy jelentés'),
          LessonHu('8 színcímke', 'teljes paletta'),
          LessonHu('Színek sorrendben', 'sorozatfelidézés'),
          LessonHu('Színvizsga', 'felcserélt címkék nélkül'),
        ],
      ),
    ],
  ),
  ChapterHu(
    realm: 'Filmrendező',
    tagline: 'Fűzz jeleneteket összefüggő filmekké.',
    sections: [
      SectionHu(
        name: 'Jelenetláncok',
        technique: 'kapcsolt képek',
        lessons: [
          LessonHu('3 jelenetes lánc', 'egy folyamatos snitt'),
          LessonHu('5 jelenetes lánc', 'akciókapcsok'),
          LessonHu('8 jelenetes lánc', 'rövidfilm'),
          LessonHu('Láncvizsga', 'töretlen film'),
        ],
      ),
      SectionHu(
        name: 'Forgatókönyv-táblák',
        technique: 'rendezett képkockák',
        lessons: [
          LessonHu('4 képkocka', 'elejétől végig'),
          LessonHu('6 képkocka', 'csavarral'),
          LessonHu('10 képkocka', 'teljes forgatókönyv'),
          LessonHu('Forgatókönyv-vizsga', 'minden kocka a helyén'),
        ],
      ),
      SectionHu(
        name: 'Sebességvázlatok',
        technique: 'gyors vizuális rögzítés',
        lessons: [
          LessonHu('Vázlat 10 mp alatt', 'csak a lényeg'),
          LessonHu('Vázlat 5 mp alatt', 'egy kulcsvonás'),
          LessonHu('10 gyors vázlat', 'galériasprint'),
          LessonHu('Vázlatvizsga', 'felismerhetően, gyorsan'),
        ],
      ),
    ],
  ),
  ChapterHu(
    realm: 'Fotóarchívum',
    tagline: 'Ötven kép, iktatva és megtalálhatóan.',
    sections: [
      SectionHu(
        name: 'Galériaséták',
        technique: 'vizuális locik',
        lessons: [
          LessonHu('10 kép iktatva', 'egy galériafal'),
          LessonHu('20 kép iktatva', 'két fal'),
          LessonHu('30 kép iktatva', 'teljes galéria'),
          LessonHu('Galériavizsga', 'vezetett séta'),
        ],
      ),
      SectionHu(
        name: 'Készletismétlés',
        technique: 'elosztott vizuális ismétlés',
        lessons: [
          LessonHu('Ismétlés 1 nap után', 'friss ellenőrzés'),
          LessonHu('Ismétlés 3 nap után', 'elosztott ellenőrzés'),
          LessonHu('Ismétlés egy hét után', 'tartós ellenőrzés'),
          LessonHu('Ismétlésvizsga', 'semmi sem vész el'),
        ],
      ),
      SectionHu(
        name: 'Homályjavítás',
        technique: 'fakuló nyomok mentése',
        lessons: [
          LessonHu('Keresd meg a fakultakat', 'őszinte leltár'),
          LessonHu('Kódolj újra 5-öt', 'élesebb képek'),
          LessonHu('Kódolj újra 10-et', 'teljes helyreállítás'),
          LessonHu('Archívumvizsga', 'éles felidézés'),
        ],
      ),
    ],
  ),
  ChapterHu(
    realm: 'Nagy galéria',
    tagline: 'A galéria döntője: gyorsan és fókuszáltan.',
    sections: [
      SectionHu(
        name: '30 képes sprint',
        technique: 'mennyiségi bevésés',
        lessons: [
          LessonHu('15 kép, 5 perc', 'egyenletes tempó'),
          LessonHu('20 kép, 5 perc', 'nyomd a tempót'),
          LessonHu('30 kép, 5 perc', 'döntőtáv'),
          LessonHu('Sprintismétlés', 'stabil felidézés'),
        ],
      ),
      SectionHu(
        name: 'Elvont döntők',
        technique: 'nehézminta-gyakorlás',
        lessons: [
          LessonHu('10 elvont', 'kikényszerített képek'),
          LessonHu('15 elvont', 'időzített készlet'),
          LessonHu('20 elvont', 'nehéz készlet'),
          LessonHu('Elvont ismétlés', 'mintakészlet'),
        ],
      ),
      SectionHu(
        name: 'Galéria-ismétlés',
        technique: 'teljes archívum ismétlése',
        lessons: [
          LessonHu('50 kép', 'teljes archívumséta'),
          LessonHu('Ikrek plusz zaj', 'ellenséges galéria'),
          LessonHu('Másnapi felidézés', 'alvástesztelt'),
          LessonHu('Nagy galéria', 'teljesarchívum-ismétlés'),
        ],
      ),
    ],
  ),
  ChapterHu(
    realm: 'Időgép',
    tagline: 'Játszd vissza a hetedet, mint egy filmet.',
    sections: [
      SectionHu(
        name: 'Hét-visszajátszás',
        technique: 'visszafelé ismétlés',
        lessons: [
          LessonHu('3 nap vissza', 'fordított sorrendben'),
          LessonHu('5 nap vissza', 'teljes munkahét'),
          LessonHu('7 nap vissza', 'egész hét'),
          LessonHu('Hétvizsga', 'üres napok nélkül'),
        ],
      ),
      SectionHu(
        name: 'Idővonal-szegek',
        technique: 'dátumozott horgonyok',
        lessons: [
          LessonHu('5 dátumozott szeg', 'hónaphorgonyok'),
          LessonHu('10 dátumozott szeg', 'évhorgonyok'),
          LessonHu('Akassz eseményeket szegekre', 'dátumozott felidézés'),
          LessonHu('Idővonalvizsga', 'minden dátum a helyén'),
        ],
      ),
      SectionHu(
        name: 'Jövőpróba',
        technique: 'prospektív memória',
        lessons: [
          LessonHu('1 szándék', 'hívószó plusz cselekvés'),
          LessonHu('3 szándék', 'napi trió'),
          LessonHu('5 szándék', 'egy nap ígéretekkel'),
          LessonHu('Ígéretvizsga', 'semmi sem esik ki'),
        ],
      ),
    ],
  ),
  ChapterHu(
    realm: 'Eseménydetektív',
    tagline: 'Ki mit mondott, milyen sorrendben.',
    sections: [
      SectionHu(
        name: 'Részletgyakorlat',
        technique: 'finom epizodikus rögzítés',
        lessons: [
          LessonHu('Szobapásztázás', 'tíz részlet'),
          LessonHu('Jelenetpásztázás', 'tizenöt részlet'),
          LessonHu('Utcapásztázás', 'húsz részlet'),
          LessonHu('Részletvizsga', 'gondos felidézés'),
        ],
      ),
      SectionHu(
        name: 'Beszélgetés-visszajátszás',
        technique: 'párbeszédfelidézés',
        lessons: [
          LessonHu('Ki mondta', 'három beszélő'),
          LessonHu('Pontos szavak', 'kulcsidézetek'),
          LessonHu('Hosszú beszélgetés visszajátszása', 'tíz váltás'),
          LessonHu('Párbeszédvizsga', 'idézett pillanatok'),
        ],
      ),
      SectionHu(
        name: 'Sorrendőr',
        technique: 'sorozathűség',
        lessons: [
          LessonHu('5 lépés sorrendben', 'csere nélkül'),
          LessonHu('8 lépés sorrendben', 'hosszú eljárás'),
          LessonHu('12 lépés sorrendben', 'teljes protokoll'),
          LessonHu('Sorrendvizsga', 'stabil sorozat'),
        ],
      ),
    ],
  ),
  ChapterHu(
    realm: 'Álomkonszolidáló',
    tagline: 'Aludj rá — szándékosan.',
    sections: [
      SectionHu(
        name: 'Lefekvésprotokoll',
        technique: 'elalvás előtti ismétlés',
        lessons: [
          LessonHu('Egy palota esténként', 'tízperces séta'),
          LessonHu('Nap-visszajátszás esténként', 'visszafelé film'),
          LessonHu('Nehéz tételek utoljára', 'célzott ismétlés'),
          LessonHu('Protokollvizsga', 'hét éjszaka egyben'),
        ],
      ),
      SectionHu(
        name: 'Reggeli teszt',
        technique: 'alváskapus felidézés',
        lessons: [
          LessonHu('Felidézés ébredéskor', 'telefon előtt'),
          LessonHu('Pontozd az éjszakát', 'megmaradt vs elveszett'),
          LessonHu('Tanuld újra a veszteségeket', 'reggeli javítás'),
          LessonHu('Reggeli vizsga', 'alvásbiztos felidézés'),
        ],
      ),
      SectionHu(
        name: 'Heti ismétlés',
        technique: 'bővülő ütemezés',
        lessons: [
          LessonHu('1. hét ismétlése', 'első térköz'),
          LessonHu('Hónap ismétlése', 'hosszú térköz'),
          LessonHu('Évszak ismétlése', 'tartós archívum'),
          LessonHu('Ütemezésvizsga', 'semmi sem jár le'),
        ],
      ),
    ],
  ),
  ChapterHu(
    realm: 'Életarchívum',
    tagline: 'Egy hónap az életedből, hívásra.',
    sections: [
      SectionHu(
        name: 'Hónap-visszajátszás',
        technique: 'hosszú távú önéletrajz',
        lessons: [
          LessonHu('2 hét vissza', 'napról napra'),
          LessonHu('3 hét vissza', 'heti csúcspontok'),
          LessonHu('Teljes hónap', 'harminc nap'),
          LessonHu('Hónapismétlés', 'teljes hónap'),
        ],
      ),
      SectionHu(
        name: 'Mérföldkővizsga',
        technique: 'dátumozott életesemények',
        lessons: [
          LessonHu('5 mérföldkő', 'idén'),
          LessonHu('10 mérföldkő', 'dátumozva és rendezve'),
          LessonHu('20 mérföldkő', 'életfejezetek'),
          LessonHu('Mérföldkődöntő', 'dátumozott sorrend'),
        ],
      ),
      SectionHu(
        name: 'Életnapló-ismétlés',
        technique: 'naplóismétlés',
        lessons: [
          LessonHu('Bármely nap, bármely részlet', 'véletlen dátum gyakorlat'),
          LessonHu('Beszélgetésidézetek', 'egyhetes idézetek'),
          LessonHu('Évszak sorrendben', 'kilencven nap'),
          LessonHu('Életarchívum', 'naplóismétlés'),
        ],
      ),
    ],
  ),
  ChapterHu(
    realm: 'Arcgaléria',
    tagline: 'Arctömegek, egyenként gyakorolva.',
    sections: [
      SectionHu(
        name: 'Tömegarcok',
        technique: 'sokarc-bevésés',
        lessons: [
          LessonHu('6 arc, azonnal', 'előbb a vonás'),
          LessonHu('10 arc', 'galériakör'),
          LessonHu('15 arc', 'tömegkör'),
          LessonHu('Tömegismétlés', 'nevek a helyükön'),
        ],
      ),
      SectionHu(
        name: 'Hasonmások',
        technique: 'finom arcmegkülönböztetés',
        lessons: [
          LessonHu('Különböztess meg 2-t', 'egy kulcsvonás'),
          LessonHu('Különböztess meg 4-et', 'vonásmátrix'),
          LessonHu('Különböztess meg 6-ot', 'családi találkozó'),
          LessonHu('Hasonmásvizsga', 'felcserélt nevek nélkül'),
        ],
      ),
      SectionHu(
        name: 'Késleltetett nevek',
        technique: 'tartós arc-név kapcsok',
        lessons: [
          LessonHu('6 név, 5 perc múlva', 'kávészünet-teszt'),
          LessonHu('10 név, 1 óra múlva', 'késleltetett kör'),
          LessonHu('10 név, másnap', 'alvástesztelt'),
          LessonHu('Késleltetett vizsga', 'maradandó nevek'),
        ],
      ),
    ],
  ),
  ChapterHu(
    realm: 'Szókincs',
    tagline: 'Száz idegen szó, amely megragad.',
    sections: [
      SectionHu(
        name: 'Gyökkódok',
        technique: 'etimológiai szegek',
        lessons: [
          LessonHu('10 latin gyök', 'mindegyik egy kép'),
          LessonHu('20 gyök', 'szócsaládok'),
          LessonHu('Fejts meg 15 szót', 'gyökerek a vadonban'),
          LessonHu('Gyökvizsga', 'etimológia azonnal'),
        ],
      ),
      SectionHu(
        name: '50 szavas sprint',
        technique: 'kulcsszó sebességgel',
        lessons: [
          LessonHu('15 szó, 10 perc', 'stabil kulcsszavak'),
          LessonHu('30 szó, 10 perc', 'nyomd a tempót'),
          LessonHu('50 szó, 15 perc', 'teljes sprint'),
          LessonHu('Sprintvizsga', 'mindkét irányban'),
        ],
      ),
      SectionHu(
        name: 'Kétirányú láncok',
        technique: 'kétirányú felidézés',
        lessons: [
          LessonHu('10 szó mindkét irányban', 'oda és vissza'),
          LessonHu('20 szó mindkét irányban', 'mindkét irányban'),
          LessonHu('30 szó keverve', 'véletlen sorrendben'),
          LessonHu('Láncvizsga', 'stabilan mindkét irányban'),
        ],
      ),
    ],
  ),
  ChapterHu(
    realm: 'Tudásháló',
    tagline: 'Tények, beszédek, számok — strukturáltan.',
    sections: [
      SectionHu(
        name: 'Ténypaloták',
        technique: 'strukturált locik',
        lessons: [
          LessonHu('10 tény iktatva', 'egy szoba tény'),
          LessonHu('20 tény iktatva', 'két szoba'),
          LessonHu('30 tény iktatva', 'teljes palota'),
          LessonHu('Tényvizsga', 'bármely tény, azonnal'),
        ],
      ),
      SectionHu(
        name: 'Beszédvázak',
        technique: 'beszédlocik',
        lessons: [
          LessonHu('5 pontos beszéd', 'jegyzet nélkül'),
          LessonHu('10 pontos beszéd', 'rendezett váz'),
          LessonHu('15 perces beszéd', 'teljes vitaindító'),
          LessonHu('Vitaindító-vizsga', 'színpadkész'),
        ],
      ),
      SectionHu(
        name: 'Számtények',
        technique: 'szegezett mennyiségek',
        lessons: [
          LessonHu('5 dátum', 'történelmi szegek'),
          LessonHu('10 állandó', 'tudományos szegek'),
          LessonHu('15 számadat', 'vegyes mennyiségek'),
          LessonHu('Számadat-ismétlés', 'stabil pontosság'),
        ],
      ),
    ],
  ),
  ChapterHu(
    realm: 'Névcsarnok',
    tagline: 'Időzített nevek és szavak, a legjobb tempódban.',
    sections: [
      SectionHu(
        name: 'Névsprint',
        technique: 'időzített arc-név körök',
        lessons: [
          LessonHu('10 név, 5 perc', 'stabil 3 lépés'),
          LessonHu('15 név, 5 perc', 'élénk tempó'),
          LessonHu('20 név, 5 perc', 'döntőtáv'),
          LessonHu('Névsprint-ismétlés', 'tiszta lap'),
        ],
      ),
      SectionHu(
        name: 'Szóvillám',
        technique: 'időzített szókörök',
        lessons: [
          LessonHu('20 szó, 5 perc', 'kulcsszóvillám'),
          LessonHu('30 szó, 5 perc', 'gyorsan láncolva'),
          LessonHu('50 szó, 15 perc', 'hosszú kör'),
          LessonHu('Villámismétlés', 'gondos felidézés'),
        ],
      ),
      SectionHu(
        name: 'Záróismétlés',
        technique: 'vegyes név + szó ismétlés',
        lessons: [
          LessonHu('Nevek plusz szavak', 'vegyes döntő'),
          LessonHu('Késleltetett döntő', 'felidézés másnap'),
          LessonHu('Zajos döntő', 'zavaró tényezőkkel'),
          LessonHu('Névcsarnok', 'vegyes név + szó ismétlés'),
        ],
      ),
    ],
  ),
  ChapterHu(
    realm: 'Utcai fülek',
    tagline: 'Valódi hangok, valódi szobák, saját listáid.',
    sections: [
      SectionHu(
        name: 'Élő hangok',
        technique: 'valódi bemutatkozások gyakorlása',
        lessons: [
          LessonHu('3 élő név', 'valódi találkozókon'),
          LessonHu('5 élő név', 'helyesírás kérdezve'),
          LessonHu('Zajos köszönések', 'csevegéssel'),
          LessonHu('Hangismétlés', 'másnapi ellenőrzés'),
        ],
      ),
      SectionHu(
        name: 'Saját ügyek',
        technique: 'hallott listák hangosan',
        lessons: [
          LessonHu('4 ügy hallásból', 'egyszer visszamondva'),
          LessonHu('6 ügy hallásból', 'ritmusba csoportosítva'),
          LessonHu('Ügyek zajban', 'utcai felidézés'),
          LessonHu('Ügyismétlés', 'lezártlistás ellenőrzés'),
        ],
      ),
      SectionHu(
        name: 'Esti hangok',
        technique: 'nap-visszajátszási szokás',
        lessons: [
          LessonHu('Mai esti visszajátszás', '3 nehéz hang'),
          LessonHu('3 estés sorozat', 'jegyzetek vezetve'),
          LessonHu('Hét-visszajátszás', '1. nap újra'),
          LessonHu('Hangismétlés', 'stabil felidézés'),
        ],
      ),
    ],
  ),
  ChapterHu(
    realm: 'Számmező',
    tagline: 'Valódi számok, amelyekre tényleg szükséged van.',
    sections: [
      SectionHu(
        name: 'Valódi számok',
        technique: 'tömbösített telefonkódok',
        lessons: [
          LessonHu('1 szám a tiéd', 'emlékezetből tárcsázva'),
          LessonHu('2 szám a tiéd', 'reggeli felidézés'),
          LessonHu('Hosszú szám', 'háromtömbös jelenet'),
          LessonHu('Számismétlés', 'egy héttel későbbi ellenőrzés'),
        ],
      ),
      SectionHu(
        name: 'Bevásárlókörök',
        technique: 'lezártlistás vásárlások',
        lessons: [
          LessonHu('4 tétel lezárva', 'zsebellenőrzés'),
          LessonHu('8 tétel lezárva', 'pénztári felidézés'),
          LessonHu('Vegyes ügyek', 'fordított ellenőrzés'),
          LessonHu('Bevásárlásismétlés', 'friss lista'),
        ],
      ),
      SectionHu(
        name: 'Dátumok megőrizve',
        technique: 'archoz kötött dátumok',
        lessons: [
          LessonHu('2 dátum rögzítve', 'fotóhívószavak'),
          LessonHu('5 dátum rögzítve', 'esti felidézés'),
          LessonHu('Véletlen kvíz', 'barát kérdez'),
          LessonHu('Dátumismétlés', 'egy hónappal későbbi ellenőrzés'),
        ],
      ),
    ],
  ),
  ChapterHu(
    realm: 'Két palota',
    tagline: 'A szobáid, az útvonalaid, a listáid.',
    sections: [
      SectionHu(
        name: 'Otthoni útvonal',
        technique: 'saját 10 állomás',
        lessons: [
          LessonHu('10 állomás kijelölve', 'ajtótól a hálószobáig'),
          LessonHu('10 szó elhelyezve', 'mindegyik egy jelenet'),
          LessonHu('Vak séta', 'másnap reggel'),
          LessonHu('Otthoni ismétlés', 'mellék újrasétálva'),
        ],
      ),
      SectionHu(
        name: 'Utcai útvonal',
        technique: 'saját 15 állomás',
        lessons: [
          LessonHu('15 pont kiválasztva', 'élesen és elkülönülten'),
          LessonHu('15 tétel elhelyezve', 'tanulás vagy munka'),
          LessonHu('Előre felidézés', 'ugrálás nélkül'),
          LessonHu('Utcai ismétlés', 'friss 15'),
        ],
      ),
      SectionHu(
        name: 'Két útvonal',
        technique: 'saját 20 tételes listák',
        lessons: [
          LessonHu('20 elosztva elhelyezve', '10 plusz 10'),
          LessonHu('Esti séta', 'mindkét útvonal'),
          LessonHu('Reggeli felidézés', 'emlékezetből leírva'),
          LessonHu('Útvonal-ismétlés', 'egyszer megtanítva'),
        ],
      ),
    ],
  ),
  ChapterHu(
    realm: 'Napi képek',
    tagline: 'Munka és tanulás, képekben.',
    sections: [
      SectionHu(
        name: 'Munkaképek',
        technique: 'elvontból kép',
        lessons: [
          LessonHu('4 feladat képekben', 'nagyon és mozgóan'),
          LessonHu('6 feladat képekben', 'sarkokhoz kötve'),
          LessonHu('Déli felidézés', 'lista ellenőrizve'),
          LessonHu('Feladatismétlés', 'friss 6'),
        ],
      ),
      SectionHu(
        name: 'Fotótartások',
        technique: 'másnapi részletek',
        lessons: [
          LessonHu('6 részlet megnevezve', 'egy fotó'),
          LessonHu('Eltúlzott címkék', 'ikrek szétválasztva'),
          LessonHu('Másnapi újjáépítés', 'lesés nélkül'),
          LessonHu('Fotóismétlés', 'friss fotó'),
        ],
      ),
      SectionHu(
        name: 'Megbeszéléscsíkok',
        technique: 'kapcsolt pontképek',
        lessons: [
          LessonHu('3 pont összekötve', 'apró cselekvések'),
          LessonHu('5 pont összekötve', 'teljes csík'),
          LessonHu('Reggeli visszajátszás', 'jegyzőkönyv ellenőrizve'),
          LessonHu('Csíkismétlés', 'friss megbeszélés'),
        ],
      ),
    ],
  ),
  ChapterHu(
    realm: 'Hét-visszajátszás',
    tagline: 'Történetek és esték, megőrizve.',
    sections: [
      SectionHu(
        name: 'Napláncok',
        technique: 'egyláncú történetek',
        lessons: [
          LessonHu('6 fogalom láncolva', 'egyetlen kaland'),
          LessonHu('10 fogalom láncolva', 'hangosan újramesélve'),
          LessonHu('Másnapi újramesélés', 'mellék feljegyezve'),
          LessonHu('Láncismétlés', 'friss 10'),
        ],
      ),
      SectionHu(
        name: 'Esti napló',
        technique: '7 éjszakás visszajátszás',
        lessons: [
          LessonHu('Ma este visszafelé', 'jelenetről jelenetre'),
          LessonHu('3 éjszaka naplózva', 'nehéz felidézések'),
          LessonHu('7 éjszaka naplózva', 'hét megtartva'),
          LessonHu('Naplóismétlés', '1. nap hívószavakból'),
        ],
      ),
      SectionHu(
        name: 'Hangosan újramesélve',
        technique: 'egyszeri olvasás utáni mesélések',
        lessons: [
          LessonHu('Egy cikk egyszer', 'filmszerű olvasás'),
          LessonHu('Esti mesélés', 'egy hallgatónak'),
          LessonHu('Másnapi mesélés', 'kihagyások összehasonlítva'),
          LessonHu('Mesélésismétlés', 'friss cikk'),
        ],
      ),
    ],
  ),
  ChapterHu(
    realm: 'Nevek élesben',
    tagline: 'Valódi nevek, valódi szavak, valódi beszédek.',
    sections: [
      SectionHu(
        name: 'Élő nevek',
        technique: '3 lépés eseményeken',
        lessons: [
          LessonHu('3 eseménybeli név', 'előbb a vonás'),
          LessonHu('5 eseménybeli név', 'horgok ragadva'),
          LessonHu('Név szerint köszöntve', 'két helló'),
          LessonHu('Névismétlés', 'másnapi lista'),
        ],
      ),
      SectionHu(
        name: 'Szóhetek',
        technique: 'napi kulcsszópárok',
        lessons: [
          LessonHu('Napi 2 szó', 'mindkét irányban'),
          LessonHu('10 szó megtartva', 'heti kvíz'),
          LessonHu('20 szó megtartva', 'kevert teszt'),
          LessonHu('Szóismétlés', 'mellék újratesztelve'),
        ],
      ),
      SectionHu(
        name: 'Beszédek plusz tények',
        technique: 'váz plusz szobák',
        lessons: [
          LessonHu('3 pontos beszámoló', 'jegyzet nélkül'),
          LessonHu('5 pontos beszéd', 'hallgatói ellenőrzés'),
          LessonHu('10 tény iktatva', 'saját tanulás'),
          LessonHu('Beszédismétlés', 'állomások hívva'),
        ],
      ),
    ],
  ),
];
