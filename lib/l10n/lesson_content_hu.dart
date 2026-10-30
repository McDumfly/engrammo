library;

import '../models/lesson_content.dart';

const coachContentHu = <String, CoachContent>{
  '0-0': CoachContent(
    title: 'A figyelemkapu',
    intro:
        'Azért felejted el a neveket, mert valójában sosem hallottad őket. '
        'Az agyad a saját bemutatkozásod ismételgetésével volt elfoglalva. '
        'Javítsd a befogadást, és az emlék magától megjavul.',
    steps: [
      'Hagyd abba a belső ismételgetést abban a pillanatban, hogy valaki megszólal.',
      'Mondd vissza a nevet azonnal: „Örülök, Anna.”',
      'Kérdezd meg a helyesírást, ha tudod — ezzel második találkozást nyersz.',
    ],
    why:
        'A megosztott figyelem bevéséskor sokkal jobban tönkreteszi az '
        'emléket, mint a zavaró tényező felidézéskor. Teljes figyelem be, '
        'emlék ki.',
    source: 'Craik, Govoni, Naveh-Benjamin & Anderson (1996)',
  ),
  '0-1': CoachContent(
    title: 'Hangvillanás',
    intro:
        'Az echoikus memóriád pár másodpercig őrzi a nyers hangot. Mondd '
        'vissza gyorsan, és megragad. Habozol, és elpárolog.',
    steps: [
      'Hallgasd meg egyszer, aztán mondd vissza hangosan a sorozatot rögtön.',
      'Csoportosítsd a hangokat ritmusba: „hét-három — kilenc”.',
      'Idézd fel, mielőtt ránéznél: húzd ki, ne olvasd újra.',
    ],
    why:
        'A hangos kimondás veri a néma olvasást (produkciós hatás), a ritmus '
        'pedig tömbösíti a tételeket, így a rövid távú memória többet tart meg.',
    source: 'MacLeod et al. (2010); Purnell-Webb & Speelman (2008)',
  ),
  '0-2': CoachContent(
    title: 'Fókusz zajban',
    intro:
        'A való élet zajos. A bajnokoknak nem kell csend — arra edzenek, '
        'hogy egyetlen jelre zárkózzanak, miközben a világ cseveg.',
    steps: [
      'Válassz egy hangot vagy szálat, és csak azt kövesd.',
      'Szűrd a többit háttérzümmögéssé.',
      'Játszd vissza a célt emlékezetből abban a pillanatban, hogy véget ér.',
    ],
    why:
        'A szelektív figyelem edzhető: a gyakorlott szűrés védi a bevésést. '
        'Hogy a zajos szobás gyakorlás mennyit segít a hétköznapokban, '
        'emberenként változik — ígéret egyik irányban sincs.',
    source: 'Naveh-Benjamin et al. (2005); Robison & Unsworth (2015)',
  ),
  '1-0': CoachContent(
    title: 'Számtömbök',
    intro:
        'Kevesen tartanak meg 12 különálló számjegyet. Az edzett '
        'tömbösítők 4 képet tartanak meg helyette. A tömbösítés a nehéz '
        'számsort rövid történetté alakítja.',
    steps: [
      'Bontsd a számjegyeket 3-as csoportokra: 491-625-830.',
      'Alakíts minden csoportot egyetlen élénk képpé vagy szóvá.',
      'Fűzd össze a képeket sorrendben, és sétálj végig rajtuk.',
    ],
    why:
        'A munkamemória körülbelül 4 tömböt tart, de egy tömb hatalmas lehet, '
        'ha átkódolod. Egy edzett diák 80 számjegyig jutott.',
    source: 'Cowan (2001); Ericsson, Chase & Faloon (1980)',
  ),
  '1-1': CoachContent(
    title: 'Kártyarendszerek',
    intro:
        'A lapok véletlennek tűnnek, amíg minden lapból nem lesz egy személy, '
        'akit ismersz. Aztán a pakli bulivá válik, a sorrend pedig pletykává.',
    steps: [
      'Adj minden lapnak egy rögzített képet (kőr hetes = Hal barátod).',
      'Helyezz állomásonként 2-3 lapot egyetlen kölcsönható jelenetként.',
      'Sétálj végig az útvonaladon sorrendben — soha ne ugorj át állomást.',
    ],
    why:
        'Az előre megtanult képkódok plusz a rendezett helyek a véletlen '
        'sorozatokat elmesélhető jelenetekké alakítják. A kártyarekorderek '
        'elmondása szerint palotát plusz PAO-rendszert használnak.',
    source: 'PAO system survey; memory-sport discipline formats',
  ),
  '1-2': CoachContent(
    title: 'Munkamemória-edzőterem',
    intro:
        'Tételeket tartani, miközben forgatod őket — ez a munkamemória '
        'alapgyakorlata. Rövid sorozatok, teljes erőbedobás, aztán pihenés.',
    steps: [
      'Tartsd fejben az egész készletet, mielőtt megfordítanád.',
      'Haladj visszafelé tételenként, hangosan.',
      'Ha elejtesz egyet, kezdd újra a készletet — lesés nélkül.',
    ],
    why:
        'A fordított terjedelem a központi végrehajtót terheli, nem csak a '
        'tárat. Őszinte megjegyzés: a gyakorlatok először a gyakorlatokban '
        'javítanak; az átvitel a velük tanult stratégiákból jön.',
    source: 'Baddeley & Hitch (1974); Melby-Lervåg et al. (2016)',
  ),
  '2-0': CoachContent(
    title: 'Az első palotád',
    intro:
        'Ez a nagy dobás. A memória-versenyzők ugyanezzel a módszerrel '
        'jegyeznek meg hosszú listákat: tedd minden tételt egy ismerős '
        'helyre, aztán sétálj végig, és szedd össze őket.',
    steps: [
      'Válassz egy útvonalat, amelyet kívülről ismersz: az otthonod, bejárati ajtótól a hálószobáig.',
      'Jelölj ki 5 állomást rögzített sorrendben (ajtó, kanapé, lámpa...).',
      'Helyezz állomásonként EGY bizarr, mozgó képet, és sétáld végig kétszer.',
    ],
    why:
        'A loci-módszer a listákat a navigációs agyadon vezeti át — egy '
        'hatalmas, ősi rendszeren. Dresler et al. (2017) vizsgálatában hat '
        'hét loci-edzés a kezdőket a sportolói minta felé mozdította.',
    source: 'Maguire et al. (2003); Dresler et al. (2017, Neuron)',
  ),
  '2-1': CoachContent(
    title: 'Nagyobb paloták',
    intro:
        'Öt állomás egy sufni. Most palotát építesz. Több állomás, ugyanaz '
        'a szabály: jelenetenként egy élénk kép, mindig sorrendben.',
    steps: [
      'Bővítsd az útvonaladat 10, aztán 15 állomásra.',
      'Tartsd az állomásokat elkülönülten: nincs két szék, nincsenek homályos sarkok.',
      'Csak előre sétálva ismételd — a visszafelé séta elmossa a sorrendet.',
    ],
    why:
        'Az elkülönülő locik megakadályozzák a tételek közötti '
        'interferenciát. Krokos et al. vizsgálatában a virtuális paloták '
        'kezdőknél ~30%-kal emelték a megőrzést a lapos listákhoz képest.',
    source: 'Krokos et al. VR palace study; Wagner et al. (2021)',
  ),
  '2-2': CoachContent(
    title: 'Palotavizsga',
    intro:
        'Itt az ideje a tesztnek. Hosszú útvonal, teljes lista, egy tiszta '
        'séta — lesés, ugrás nélkül. Az ismétlőnap megmutatja, mire képes '
        'a rendszered.',
    steps: [
      'Véss be lassan: állomásonként 10 másodperc veri a kapkodást.',
      'Csukd be a szemed, és válaszadás előtt sétálj végig a teljes útvonalon.',
      'Kimaradt egy? Erősítsd meg azt az állomásképet, és sétálj újra.',
    ],
    why:
        'A vizsgálatokban a felidézéses gyakorlás nagy fölénnyel veri az '
        'újraolvasást, és az előny a késleltetéssel nő. Teszteld magad, '
        'ne olvasd újra.',
    source: 'Roediger & Karpicke (2006); Rowland (2014) meta-analysis',
  ),
  '3-0': CoachContent(
    title: 'Lásd nagynak',
    intro:
        'A vizuális memóriád hatalmas — több ezer kép megragad egyetlen '
        'pillantás után. A trükk az, hogy az unalmas tételeket képpé '
        'tehetővé teszed.',
    steps: [
      'Alakíts minden tételt képpé, még az elvont szavakat is.',
      'Legyen nagy, élénk és mozgó a fejedben.',
      'Kösd valamihez, ami már ott van a jelenetben.',
    ],
    why:
        'A képek két memóriakódot kapnak (vizuális + verbális) egy helyett. '
        'Ez a kettős kód a képfölény-hatás.',
    source: 'Paivio dual-coding theory; Shepard (1967); Standing (1973)',
  ),
  '3-1': CoachContent(
    title: 'A furcsa nyer',
    intro:
        'A normális felejthető. Az agyad kiszúrja a furcsát, a vicceset és '
        'a szemtelent — ezért kódolj szándékosan így.',
    steps: [
      'Vedd a sima képedet, és törd meg valahogy.',
      'Adj hozzá mozgást, méretet vagy valami társadalmilag abszurdat.',
      'Hozd kölcsönhatásba egymással a tételeket — soha ne hagyd őket magányosan.',
    ],
    why:
        'A megkülönböztető tételek kiugranak az emlékezetből (Von Restorff-'
        'hatás). A kölcsönható képek általában verik a magányosakat.',
    source: 'Von Restorff (1933); Wollen et al. bizarre-imagery work',
  ),
  '3-2': CoachContent(
    title: 'Képlabor döntő',
    intro:
        'Elvont formák, gyors villanások, kegyelem nélkül. Itt tanulod meg, '
        'hogy még a „leképezhetetlen” minták is engednek a kikényszerített '
        'képeknek.',
    steps: [
      'Nevezd meg azonnal, amit látsz — a szavak rögzítik a képeket.',
      'Túlozz el tételenként egy vonást, hogy szétválaszd az ikreket.',
      'Rekonstruáld emlékezetből, mielőtt megnéznéd a választ.',
    ],
    why:
        'A verbális címkék plusz a képek két előhívási utat adnak. Az '
        'erőfeszítéses rekonstrukció erősíti a nyomot (kívánatos nehézség).',
    source: 'Paivio & Desrochers (1979); Bjork (1994)',
  ),
  '4-0': CoachContent(
    title: 'Történetláncok',
    intro:
        'Az epizódok akkor ragadnak meg, ha történetté válnak. Egy véletlen '
        'lista nehéz; ugyanezek a tételek egyetlen bolondos kalandként '
        'könnyűek.',
    steps: [
      'Kösd az 1. tételt a 2.-hoz egy cselekvéssel, aztán a 2.-at a 3.-hoz, és így tovább.',
      'Tarts EGY láncot — az elágazó láncok elpattannak.',
      'Meséld el a történetet elejétől végéig, hangosan, ha tudod.',
    ],
    why:
        'A narratív láncolás sorrendet plusz jelentést ad. A vizsgálatokban '
        'a kidolgozó bevésés (gazdag mondatok) egyértelműen veri a sekélyes '
        'ismételgetést.',
    source: 'Craik & Tulving (1975); elaborative-encoding literature',
  ),
  '4-1': CoachContent(
    title: 'Naplófelidézés',
    intro:
        'A bajnokok minden este átnézik a napjukat. Tíz perc visszajátszás '
        'lefekvés előtt ingyen adja az éjszakai konszolidáció műszakját.',
    steps: [
      'Minden este játszd vissza a napodat visszafelé, jelenetről jelenetre.',
      'Állj meg a részleteknél: arcok, számok, pontos szavak.',
      'Írd le a három legnehezebb felidézést.',
    ],
    why:
        'Az alvás azt konszolidálja, amit lefekvéshez közel tanultál, és a '
        'teszt várása kapuzza, hogy az alvás mit tart meg. Ismételj, aztán '
        'aludj.',
    source: 'Gais, Lucas & Born (2006); Wilhelm et al. (2011)',
  ),
  '4-2': CoachContent(
    title: 'Éjszakai konszolidáció',
    intro:
        'Nemcsak ébren tanulsz. Az agyad éjjel újrajátssza a napot — adj '
        'neki tiszta anyagot a visszajátszáshoz.',
    steps: [
      'Sétálj végig egy teljes palotán rögtön lefekvés előtt.',
      'A séta után ne tömj be új tételeket — hagyd leülepedni.',
      'Idézd fel ugyanazt a sétát reggel elsőként.',
    ],
    why:
        'A laborvizsgálatokban az este tanult szókincs sokkal kevésbé fakult '
        'meg, mint a reggeli tanulás, és a két alkalom közötti éjszaka '
        'nagyjából megfelezte az újratanulást. Az egyéni eredmények '
        'változnak.',
    source: 'Gais et al. (2006); Mazza et al. (2016)',
  ),
  '5-0': CoachContent(
    title: 'Baker-törő',
    intro:
        'Miért könnyű a „pék”, de miért olyan nehéz „Mr. Baker”? Ugyanaz a '
        'hangzás — de az egyiknek jelentése és képe van. Adj minden névnek '
        'mindkettőt.',
    steps: [
      'Először keress egy kiugró arcvonást.',
      'Alakítsd a nevet képpé (Baker = fehér sapka).',
      'Ragaszd a képet RÁ a vonásra, és hozd kölcsönhatásba.',
    ],
    why:
        'A laborvizsgálatban a 3 lépéses arc-név technika 42%-ról 79%-ra '
        'emelte a felidézést — nagyon nagy hatás (d ≈ 2,4). Az eredményeid '
        'a gyakorlástól függenek.',
    source: 'Morris et al. face-name mnemonic (d ≈ 2.4)',
  ),
  '5-1': CoachContent(
    title: 'Kulcsszólánc',
    intro:
        'Az idegen szavak csúszósnak érződnek, amíg hozzá nem szegezed őket '
        'egy szóhoz, amelyet ismersz. Hasonló hangzású kulcsszó plusz őrült '
        'kép: rögzítve.',
    steps: [
      'Keress egy anyanyelvi szót, amely hasonlít az idegenre.',
      'Képezeld el, ahogy a kulcsszó kölcsönhatásba lép a jelentéssel.',
      'Teszteld magad mindkét irányban, minden alkalommal visszajelzéssel.',
    ],
    why:
        'A laborvizsgálatokban a kulcsszó-módszer átlag 72%-ot hozott 46% '
        'ellenében a magolással szemben, a megőrzés pedig rövid ismétlésekkel '
        'évekig tartott. Az eredményeid a gyakorlástól függenek.',
    source: 'Atkinson & Raugh (1975); Beaton et al. (1995)',
  ),
  '5-2': CoachContent(
    title: 'Jelentésháló',
    intro:
        'A mély veri a sekélyest. Kérdezd meg, mit jelent egy szó, honnan '
        'jön, és mihez kapcsolódik — és megszűnik önkényesnek lenni.',
    steps: [
      'Kérdezz rá minden ténynél a miértre, ne csak a mire.',
      'Kösd minden tételt két dologhoz, amelyet már ismersz.',
      'Magyarázd el a saját szavaiddal, mielőtt továbbmennél.',
    ],
    why:
        'A vizsgálatokban a szemantikus, önmagának elmagyarázott bevésés '
        'egyértelműen veri a sekélyes ismételgetést. Nem a feladaton töltött '
        'idő magyarázza — a mélység igen.',
    source: 'Craik & Tulving (1975); Chi et al. (1994)',
  ),
  '6-0': CoachContent(
    title: 'Palotaműhely',
    intro:
        'Ismered az alapokat. Most a versenyzői formátumot gyakorlod: '
        'rögzített útvonalak, időzített bevésés, minden állomás '
        'végigsétálva.',
    steps: [
      'Használj gyakorlásonként egy dedikált verseny-palotát.',
      'Véss be időre — a nyomás a készség része.',
      'Pontozz minden kört: helyes tételek, tiszta állomások.',
    ],
    why:
        'A sportolóknak nincs strukturális agyi előnyük — csak jobb '
        'stratégiahasználatuk és loci-hálózati bevonásuk. Minden edzett.',
    source: 'Maguire et al. (2003); Dresler et al. (2017)',
  ),
  '6-1': CoachContent(
    title: 'Számrendszer-labor',
    intro:
        'Kétjegyű képek, hármasával láncolva Személy-Cselekvés-Tárgy '
        'jelenetekké. Állomásonként hat számjegy. Így válnak lehetségessé a '
        '80 jegyes sprintek.',
    steps: [
      'Rögzíts minden 00–99 párhoz egy képet — menet közben nincs improvizálás.',
      'Láncolj állomásonként 3 párt: személy végez cselekvést a tárggyal.',
      'Gyakorold magukban a képeket, amíg a felidézés azonnali nem lesz.',
    ],
    why:
        'Hosszú távú munkamemória: a szakértők tanult struktúrákon át hívnak '
        'elő hatalmas tömböket. Az automatikus kódok felszabadítják a '
        'figyelmet a sorrendre.',
    source: 'Ericsson & Kintsch (1995) LTWM; PAO system survey',
  ),
  '6-2': CoachContent(
    title: 'Név- és szólabor',
    intro:
        'Az időzített nevek és szavak gyorsan jönnek, és ritkán ismétlődnek. '
        'Sebesség plusz a 3 lépéses módszer plusz kulcsszóláncok — egyszerre.',
    steps: [
      'Előbb a vonás, aztán a kép, aztán a kölcsönhatás — másodpercek alatt.',
      'Fűzd a szavakat egyetlen futó történetbe, ahogy megjelennek.',
      'Ismételd bővülő térközökkel: 1 perc, 5 perc, 30 perc.',
    ],
    why:
        'A bővülő előhívási ütemezéseket először neveken és arcokon mutatták '
        'ki. Az áttekintések az elosztott felidézést a leghasznosabb '
        'stratégiák közé sorolják.',
    source: 'Landauer & Bjork (1978); Dunlosky et al. (2013)',
  ),
  '7-0': CoachContent(
    title: 'Sebességszám-döntő',
    intro:
        'Nyolcvan számjegy. Ketyeg az óra. Ez a nemzetközi sprintdöntő '
        'formátuma — a rendszereid itt kapják meg az időzített tesztet.',
    steps: [
      'Véss be rögzített 6 jegyes PAO-jelenetekben, habozás nélkül.',
      'Bízz a palotádban: sétáld végig egyszer, dönts, menj tovább.',
      'A hibákat állomásonként elemezd — a kódot javítsd, ne a bátorságodat.',
    ],
    why:
        'A sebességversenyek választják szét az automatikus rendszereket az '
        'improvizáltaktól. Tájékoztatásul: a listázott 2025-ös csúcs 80 '
        'számjegy körülbelül 13,5 másodperc alatt — éveknyi edzésre innen.',
    source: 'International sprint record tables (2025)',
  ),
  '7-1': CoachContent(
    title: 'Sebességkártya-döntő',
    intro:
        'Egy teljes kevert pakli, az óra ellen. Jelenetenként három lap, '
        'tizenhét jelenet, egy palota. Rajta.',
    steps: [
      'Oszd ki indulás előtt minden lap PAO-szerepét.',
      'Jelenetenként egy pillantás — az újraolvasás megöli az idődet.',
      'Idézd fel sorrendben, állomásról állomásra, ugrálás nélkül.',
    ],
    why:
        'A listázott paklirekord körülbelül 12,7 másodperc (2025-ös táblák). '
        'A felmért rekorderek elmondása szerint palota plusz PAO-rendszert '
        'használnak — gyakorlandó forma, nem e havi cél.',
    source: 'Record tables (2025); card-memorization survey',
  ),
  '7-2': CoachContent(
    title: 'Palotamaraton',
    intro:
        'Huszonhét tétel egy sétában — ez volt a labormérföldkő. Te '
        'túlgyakorlod: ötven, aztán száz. Az egymenet a fundamentum — a '
        'tartós készséghez több hónapos elosztott ismétlés plusz saját '
        'listás séták kellenek.',
    steps: [
      'Láncolj több palotát egyetlen nagy útvonallá.',
      'Tegyél ismétlősétákat még estére és másnap reggelre.',
      'Tartsd frissen minden állomás képét — látogasd újra, ne építsd újra.',
    ],
    why:
        'Dresler et al. (2017) vizsgálatában az így gyakorló labordozók 4 '
        'hónapnál is őrizték a nyereséget. Az eredményeid a folytatott '
        'ismétléstől függenek.',
    source: 'Dresler et al. (2017); Wagner et al. (2021)',
  ),
  '8-0': CoachContent(
    title: 'Ritmuskódok',
    intro:
        'A ritmus a fülek tömbösítése. Az ütem kóbor hangokat csoportosít '
        'ütemcsoportokba, és az emlékezet valójában a csoportokat tartja meg.',
    steps: [
      'Tapsold vagy kopogd vissza a mintát válaszadás előtt.',
      'Csoportosítsd az ütemeket 3-as vagy 4-es csoportokba, soha lapos számsorrá.',
      'Játszd vissza fejben a csoportot egyszer, mielőtt felidéznéd.',
    ],
    why:
        'Az időbeli csoportosítás ugyanúgy emeli az auditív terjedelmet, '
        'ahogy a vizuális tömbösítés a számjegyet: a struktúra hordozza a '
        'tételeket.',
    source: 'Purnell-Webb & Speelman (2008); Cowan (2001)',
  ),
  '8-1': CoachContent(
    title: 'Késleltetett visszhang',
    intro:
        'Az echoikus memória másodpercek alatt fakul — hacsak nem '
        'ismételgeted. Ez a rész a tartást edzi: tartsd életben a nyomot a '
        'késleltetésen át.',
    steps: [
      'Ismételgesd némán a tételeket a teljes késleltetés alatt.',
      'Ne less idő előtt: a küzdelem maga az edzés.',
      'A várakozás után építsd újra az első tételtől, sorrendben.',
    ],
    why:
        'A fenntartó ismételgetés meghosszabbítja az echoikus nyomot, a '
        'késleltetett felidézés gyakorlása pedig tartós előhívási erőt épít.',
    source: 'Baddeley & Hitch (1974); Rowland (2014) meta-analysis',
  ),
  '8-2': CoachContent(
    title: 'Egymást fedő hangok',
    intro:
        'A koktélparti-probléma a való élet: egy célhang mások mosásában. '
        'Edzd a szűrőt, és a felidézés könnyűvé válik.',
    steps: [
      'Zárkózz a célhangra az első másodpercben.',
      'Hagyd a többi hangot háttértextúrává mosódni.',
      'Játszd vissza a célszálat abban a pillanatban, hogy elhallgat.',
    ],
    why:
        'A szelektív auditív figyelem kapuzza, mi vésődik be. Amit sosem '
        'különítettél el, azt később nem tudod felidézni.',
    source: 'Naveh-Benjamin et al. (2005); Robison & Unsworth (2015)',
  ),
  '9-0': CoachContent(
    title: 'Hangképek',
    intro:
        'A hangok elpárolognak; a képek megragadnak. Alakíts hát minden '
        'hangot képpé abban a pillanatban, hogy meghallod — dupla kód, '
        'dupla memória.',
    steps: [
      'Adj minden hangnak egy konkrét képet azonnal.',
      'Mozgasd meg a képet, vagy ütköztesd a következővel.',
      'Idézd fel először a képeket, aztán fordítsd vissza hangokra.',
    ],
    why:
        'A kettős kódolás hangra is működik: a verbális-plusz-vizuális nyom '
        'sokkal jobban túlél, mint a puszta visszhang.',
    source: 'Paivio dual-coding theory; MacLeod et al. (2010)',
  ),
  '9-1': CoachContent(
    title: 'Dallamútvonalak',
    intro:
        'Most a hangok palotába költöznek. Minden állomás egy hangképet '
        'rejt, a sorrendet pedig ingyen adja az útvonal.',
    steps: [
      'Sétálj végig egy rövid ismert útvonalon, állomásonként egy hanggal.',
      'Hozd kölcsönhatásba minden hangot az állomásával.',
      'Idézd fel előre sétálva — soha ne ugrálj.',
    ],
    why:
        'A locik sorrendet plusz elkülönülő kontextusokat adnak, kiiktatva '
        'az interferenciát, amely általában tönkreteszi a hosszú '
        'hanglistákat.',
    source: 'Maguire et al. (2003); Wagner et al. (2021)',
  ),
  '9-2': CoachContent(
    title: 'Hangszíncímkék',
    intro:
        'A hasonló hangok péppé olvadnak össze. Címkézz minden hangot '
        'magasság, hangerő vagy tempó szerint, és elkülönülten maradnak meg.',
    steps: [
      'Címkézd minden hangot, ahogy hallod: magas, hangos, gyors.',
      'Túlozd el szándékosan a címkét a fejedben.',
      'Idézd fel először a címkét, aztán a hozzá tartozó hangot.',
    ],
    why:
        'A megkülönböztető vonások csökkentik a hasonló tételek közötti '
        'interferenciát — az izolációs hatás auditív változata.',
    source: 'Von Restorff (1933); Baddeley & Hitch (1974)',
  ),
  '10-0': CoachContent(
    title: 'Sebességvisszhang',
    intro:
        'A valódi beszéd nem vár. Ez a rész addig zsugorítja a bevésési '
        'idődet, amíg a tételenkénti egy másodperc kényelmessé nem válik.',
    steps: [
      'Tömbösíts menet közben: csoportosíts, ahogy a hangok érkeznek.',
      'Soha ne állítsd meg a folyamot — bízz a részleges kódokban.',
      'Idézd fel azonnal, sorrendben, hangosan.',
    ],
    why:
        'A gyors bevésés gyakorlása automatizálja a tömbösítést, '
        'felszabadítva a figyelmet a formával való bénázás helyett a '
        'tárolásra.',
    source: 'Ericsson, Chase & Faloon (1980); Cowan (2001)',
  ),
  '10-1': CoachContent(
    title: 'Tömegszűrő',
    intro:
        'A telt háznyi zaj a figyelem záróvizsgája. Ugyanaz a készség, mint '
        'eddig, feltekerve, amíg nyomásnak nem érződik.',
    steps: [
      'Válaszd ki a célszáladat, mielőtt a zaj elindul.',
      'Lélegezz egyenletesen: a feszültség túl szűkre zárja a figyelmet.',
      'Játszd vissza emlékezetből azonnal — a zaj gyorsan törli a nyomokat.',
    ],
    why:
        'A terhelés alatti edzés átvisz: a zajban épített szűrők a zajos '
        'való életben is kitartanak, nem csak csendben.',
    source: 'Naveh-Benjamin et al. (2005)',
  ),
  '10-2': CoachContent(
    title: 'Hosszú visszajátszások',
    intro:
        'Húsz tétel egy hallásra. Nyersen lehetetlen — ritmussal, képekkel, '
        'útvonallal és címkékkel egymásra pakolva rutin.',
    steps: [
      'Pakold egymásra az összes eszközt: először ritmus, aztán képek, aztán útvonal.',
      'Az első menetben véss be lassan és gondosan.',
      'Sétálj végig egyszer az egész készleten, mielőtt bármire válaszolnál.',
    ],
    why:
        'A kombinált stratégiák sokszorozódnak: minden kód ad egy előhívási '
        'utat, a hosszú listáknak pedig minden útra szükségük van.',
    source: 'Dresler et al. (2017); Ericsson & Kintsch (1995)',
  ),
  '11-0': CoachContent(
    title: 'Számsprint hallásból',
    intro:
        'Egyszer felolvasott telefonszámok, zajban, megjegyezve. Ez a '
        'bulitrükk — és ez csak tömbösítés plusz figyelem.',
    steps: [
      'Tömbösítsd élőben 3-asával a számjegyeket, ahogy hallod.',
      'Képezd le azonnal minden tömböt, csoportonként egy képpel.',
      'Mondd vissza a teljes számot másodperceken belül.',
    ],
    why:
        'Az élő tömbösítés a visszhangproblémát képproblémává alakítja, a '
        'képek pedig túlélik, ahol a visszhangok meghalnak.',
    source: 'Ericsson, Chase & Faloon (1980); Paivio (1979)',
  ),
  '11-1': CoachContent(
    title: 'Beszédárnyékolás',
    intro:
        'Ismételd a beszédet fél ütemmel a beszélő mögött. A tolmácsok '
        'pontosan ezt edzik — ez olvasztja össze a hallgatást és a memóriát.',
    steps: [
      'Kezdj visszhangozni az első két-három szó után.',
      'Maradj fél ütemmel lemaradva, soha ne érj utol teljesen.',
      'Botláskor se állj le: csatlakozz vissza, ne indítsd újra.',
    ],
    why:
        'Az árnyékolás folyamatos bevésésre plusz azonnali produkcióra '
        'kényszerít — egy igényes hurok, amelyet a tolmácsok naponta edzenek.',
    source: 'MacLeod et al. (2010); interpreter-training literature',
  ),
  '11-2': CoachContent(
    title: 'Aranyfül-ismétlés',
    intro:
        'Minden egyszerre: nevek zajban, hosszú sorozatok, késleltetett '
        'felidézés. Ha ezt teljesíted, a teljes hallásstacket gyakoroltad '
        'edzett anyagon — tartsd meg heti ismétléssel és valódi '
        'beszélgetésekkel.',
    steps: [
      'Rendezd a figyelmedet, mielőtt minden próba elindul.',
      'Véss be a teljes stackkel: ritmus, kép, útvonal, címke.',
      'Idézd fel sorrendben, dönts, és menj a következő próbára.',
    ],
    why:
        'Az ismétlés alatti nyomás az automaticitást teszteli: a gyakorlott '
        'rendszerek kitartanak, az improvizáltak meginognak. Aztán jövő '
        'héten teszteld újra friss tételeken.',
    source: 'Timed sprint formats; Dresler et al. (2017)',
  ),
  '12-0': CoachContent(
    title: 'Major 00–19',
    intro:
        'A Major-rendszer számjegyekből mássalhangzókat, mássalhangzókból '
        'szavakat, szavakból képeket csinál. Húsz kód kezdésnek.',
    steps: [
      'Tanuld minden kódot egy rögzített, élénk képként.',
      'Gyakorlás közben soha ne improvizálj: csak rögzített kódok.',
      'Gyakorold a kép-szám irányt, amíg a felidézés azonnali nem lesz.',
    ],
    why:
        'Az előre megtanult kódok leveszik a bevésés terhét: felismersz '
        'ahelyett, hogy kitalálnál — ezért lehetségesek a 80 jegyes sprintek.',
    source: 'Major system tradition; Ericsson & Kintsch (1995)',
  ),
  '12-1': CoachContent(
    title: 'Képpárok',
    intro:
        'A kódok haszontalanok, ha lassúak. Ez a rész addig gyakoroltatja a '
        '00–19 képeidet, amíg minden pár két másodperc alatt be nem ugrik.',
    steps: [
      'Pörgesd át naponta a párokat, magadat időzítve.',
      'Erősítsd a lassú párokat vadabb képekkel.',
      'Teszteld a szám-kép és a kép-szám irányt is.',
    ],
    why:
        'Az automatikus előhívás felszabadítja a munkamemóriát a sorrendre '
        'és a struktúrára — a hosszú számok valódi nehézségére.',
    source: 'Ericsson & Kintsch (1995) LTWM',
  ),
  '12-2': CoachContent(
    title: 'Első PAO-jelenetek',
    intro:
        'Személy-Cselekvés-Tárgy: három párból egy jelenet lesz, hat '
        'számjegyből egy kép. Ez a számererekordok motorja.',
    steps: [
      'Oszd ki minden párnak a személyét, cselekvését és tárgyát.',
      'Olvaszd össze három pár képét egyetlen kölcsönható jelenetbe.',
      'Helyezz palotaállomásonként egy jelenetet.',
    ],
    why:
        'A PAO megháromszorozza a tömbsűrűséget: állomásonként 6 számjegy 2 '
        'helyett — pontosan így dőlnek meg a paklik és a sprintek.',
    source: 'Competition PAO system survey',
  ),
  '13-0': CoachContent(
    title: 'Színszemélyek',
    intro:
        'Ötvenkét lap, ötvenkét ember, akit kívülről ismersz. Tanuld '
        'színenként, és a pakli megszűnik véletlen lenni.',
    steps: [
      'Adj minden lapnak egy rögzített személyt — csere nélkül.',
      'Használj olyan embereket, akiket azonnal el tudsz képzelni.',
      'Gyakorold a kevert lapokat, amíg a megnevezés azonnali nem lesz.',
    ],
    why:
        'A rögzített kártyaképek a véletlen sorozatokat társasági '
        'jelenetekké alakítják, amelyeket a memória sokkal jobban kezel, '
        'mint a színeket.',
    source: 'Card-memorization survey; PAO system',
  ),
  '13-1': CoachContent(
    title: 'Akciókapcsok',
    intro:
        'Két lap találkozik, és történik valami. Kösd össze a személyeket '
        'vad cselekvésekkel, és a sorrend magától rögzül.',
    steps: [
      'Párosítsd a lapokat, és találj ki páronként egy kölcsönhatást.',
      'Legyenek a cselekvések fizikaiak és eltúlzottak.',
      'Játszd vissza a jeleneteket sorrendben, állomásról állomásra.',
    ],
    why:
        'A kölcsönható képek verik a magányosakat: a cselekvés köti össze a '
        'párt, és őrzi a sorrendjét.',
    source: 'Wollen et al. bizarre-imagery work',
  ),
  '13-2': CoachContent(
    title: 'Félpaklis folyamok',
    intro:
        'Huszonhat lap egy palotasétán. Előbb lassan, aztán gyorsabban — a '
        'folyam a tiszta rendszerekből jön, nem a kapkodásból.',
    steps: [
      'Oszd ki előre minden jelenetet, mielőtt az óra elindul.',
      'Jelenetenként egy pillantás: az újraolvasás megöli a folyamot.',
      'Idézd fel állomásról állomásra, soha ne ugrálj.',
    ],
    why:
        'A palota plusz PAO a szabvány kártyamódszer: a felmért rekorderek '
        'elmondása szerint ezt használják.',
    source: 'Record tables (2025); card-memorization survey',
  ),
  '14-0': CoachContent(
    title: 'Futó összegek',
    intro:
        'Tarts egy számot, miközben új számok érkeznek. A frissítés — nem '
        'csak a tárolás — a munkamemória magja.',
    steps: [
      'Tartsd az összeget fejben egyetlen tömbként.',
      'Frissítsd minden új számmal, eldobva a régit.',
      'Mondd ki hangosan az összeget az ellenőrzőpontokon.',
    ],
    why:
        'A frissítő feladatok közvetlenül a központi végrehajtót terhelik, a '
        'munkamemória azon részét, amelyet a gyakorlatok tényleg edzenek.',
    source: 'Baddeley & Hitch (1974); Melby-Lervåg et al. (2016)',
  ),
  '14-1': CoachContent(
    title: 'Fordított láncok',
    intro:
        'Az előre tárolás; a visszafelé kontroll. Egy sorozat megfordítása '
        'arra kényszeríti a végrehajtódat, hogy manipuláljon, ne csak tartson.',
    steps: [
      'Tartsd fejben az egész készletet, mielőtt megfordítanád.',
      'Haladj visszafelé tételenként, hangosan.',
      'Ha elejtesz egyet, kezdd újra — lesés nélkül.',
    ],
    why:
        'A fordított terjedelem jobban jósolja az érvelést, mint az előre: '
        'a manipulációt méri, azt a készséget, amelyet ez a rész épít.',
    source: 'Baddeley & Hitch (1974)',
  ),
  '14-2': CoachContent(
    title: 'Kettős feladatok',
    intro:
        'Két szál egyszerre: az egyiket tartod, a másikon dolgozol. Ez az '
        'edzőterem nehézsúlya — rövid sorozatok, teljes erőbedobás.',
    steps: [
      'Oszd meg szándékosan a figyelmed: nevezd meg mindegyik szálat.',
      'Fejezd be a mikrolépéseket az egyiken, mielőtt váltanál.',
      'Számíts korai kudarcokra: a kapacitás az őszinte ismétlésekkel nő.',
    ],
    why:
        'A kettős feladat gyakorlása magát a végrehajtói koordinációt edzi. '
        'Őszinte megjegyzés: a gyakorlatok először a gyakorlatokban javítanak '
        '— a hétköznapi haszon emberenként változik, ígéret egyik irányban '
        'sincs.',
    source: 'Baddeley & Hitch (1974); Melby-Lervåg et al. (2016)',
  ),
  '15-0': CoachContent(
    title: 'Második palota',
    intro:
        'Egy palota gyorsan megtelik. A bajnokok tucatjával tartanak: a '
        'második útvonal megduplázza a kapacitásodat, és pihenteti az elsőt.',
    steps: [
      'Válassz új útvonalat, amelyet kívülről ismersz, és nem hasonlít az elsőre.',
      'Rögzíts 15 állomást szigorú sorrendben, mielőtt tételeket helyeznél el.',
      'Kérdezd ki külön-külön mindkét palotát — áthallás nélkül.',
    ],
    why:
        'Az elkülönülő útvonalak megakadályozzák a listák közötti '
        'interferenciát. Az elkülönülő kontextusok teszik egyáltalán '
        'lehetségessé az újrafelhasználást.',
    source: 'Maguire et al. (2003); Wagner et al. (2021)',
  ),
  '15-1': CoachContent(
    title: 'Palotaösszekötés',
    intro:
        'Két palotából híddal egy negyed lesz. Az összekapcsolt útvonalak '
        'negyven állomást hordoznak egyetlen sétában.',
    steps: [
      'Építs élénk hidat a két útvonal közé.',
      'Sétáld végig lassan kétszer a teljes negyedet tesztelés előtt.',
      'Mindig ugyanabban a sorrendben lépj be — a sorrend az emlék.',
    ],
    why:
        'A láncolt útvonalak a palotahatárokon át is őrzik a sorrendet, '
        'messze kitolva a locikat az egyútvonalas határokon túlra.',
    source: 'Wagner et al. (2021); Dresler et al. (2017)',
  ),
  '15-2': CoachContent(
    title: 'Palotakarbantartás',
    intro:
        'A régi képek kísértetként járják az állomásokat. Tanuld meg '
        'törölni, pihentetni és forgatni a palotákat, hogy minden bevésés '
        'tisztán induljon.',
    steps: [
      'Sétálj végig először üresen, és jegyezd fel az avas képeket.',
      'Töröld a kísérteteket úgy, hogy élénken kiradírozod mindegyik állomást.',
      'Pihentesd a használt palotákat egy napig, miközben a többi dolgozik.',
    ],
    why:
        'A régi képek proaktív interferenciája a palotahibák első számú oka. '
        'A karbantartás veri az újjáépítést.',
    source: 'Competition practice survey; Wagner et al. (2021)',
  ),
  '16-0': CoachContent(
    title: 'Ötmásodperces jelenetek',
    intro:
        'A versenyek tételeként másodperceket adnak. Edzd az órát, amíg öt '
        'másodperc alatt kialakul egy ragadós jelenet.',
    steps: [
      'Állíts időzítőt: állomásonként öt másodperc, nem több.',
      'Az első kép nyer — menet közben soha ne kódolj újra.',
      'Minden kör után pontozd a ragadós vs üres állomásokat.',
    ],
    why:
        'Az időzített bevésés gyakorlása építi az automaticitást, amelyet a '
        'sebességversenyek követelnek. Az egyetlen ellenség a habozás.',
    source: 'International sprint formats; Dresler et al. (2017)',
  ),
  '16-1': CoachContent(
    title: 'Egymenetes séták',
    intro:
        'Sétálj egyszer, véss be egyszer, soha ne lépj vissza. Az egymenetes '
        'fegyelem a sétából versenyfutamot csinál.',
    steps: [
      'Dönts minden állomás mellett, ahogy elmész mellette.',
      'Soha ne sétálj vissza egy gyenge kép javítására.',
      'Idézd fel egyetlen tiszta előresétával.',
    ],
    why:
        'A bevésés közbeni visszalépés elmossa a sorrendet és duplázza az '
        'időt. Az egymenetes bizalom az, amit a döntők jutalmaznak.',
    source: 'Competition loci practice; Maguire et al. (2003)',
  ),
  '16-2': CoachContent(
    title: 'Hibajavítás',
    intro:
        'A kör után jön a triázs: keresd meg a gyenge állomásokat, építsd '
        'újra őket erősebben, ellenőrizd újrasétával. A bajnokok javítanak.',
    steps: [
      'Idézd fel először, és jelölj meg őszintén minden rést.',
      'Építsd újra a réseket nagyobb, furcsább, mozgó képekkel.',
      'Sétáld újra a teljes útvonalat a javítás ellenőrzésére.',
    ],
    why:
        'A célzott javítás plusz a felidézéses gyakorlás veri a teljes '
        'újratanulást: az erőfeszítés pontosan oda megy, ahol az emlék '
        'meghibásodott.',
    source: 'Roediger & Karpicke (2006); Rowland (2014)',
  ),
  '17-0': CoachContent(
    title: 'Nagy útvonal',
    intro:
        'Ötven állomás, egy palota, egy séta. Ez a legnagyobb egyetlen '
        'útvonal, amelyet valaha építettél — tervezd meg, mint egy építész.',
    steps: [
      'Térképezz fel papíron minden állomást bevésés előtt.',
      'Tarts minden állomást elkülönülten: ikrek nem megengedettek.',
      'Sétáld végig üresen kétszer, aztán véss be egyszer.',
    ],
    why:
        'Az előre megtervezett elkülönülő locik jelentik az egész játékot '
        'nagyban. Ötven tiszta állomás ver száz homályosat.',
    source: 'Maguire et al. (2003); Krokos et al. VR study',
  ),
  '17-1': CoachContent(
    title: 'Többpalotás lánc',
    intro:
        'Száz állomás láncolt palotákon át. Ez a hosszú táv — ugyanaz a '
        'nagyságrend, mint a nemzetközi hosszú versenyek.',
    steps: [
      'Láncolj össze három pihent palotát erős hidakkal.',
      'Véss be sorrendben, palotánként egyet.',
      'Ismételd még aznap este és másnap reggel.',
    ],
    why:
        'A láncolt palotás hosszú listák elosztott ismétléssel tartós '
        'nyereséget mutatnak négy hónapnál és azon túl is.',
    source: 'Dresler et al. (2017); Wagner et al. (2021)',
  ),
  '17-2': CoachContent(
    title: 'Nagy séta',
    intro:
        'Száz szó, egy séta, másnap reggel felidézve. Ha ezt teljesíted, '
        'tudsz 100 állomásos sétát futtatni gyakorlott útvonalakon — az új '
        'útvonalakhoz és a tartós készséghez több séta kell több héten át.',
    steps: [
      'Véss be előző este, lassan és tisztán.',
      'Aludj rá — a konszolidáció végzi a munka felét.',
      'Idézd fel vakon másnap reggel, állomásról állomásra.',
    ],
    why:
        'Az alvás erőteljesen konszolidálja a téri tanulást. Az esti bevésés '
        'plusz a reggeli felidézés ennek kereső tesztje.',
    source: 'Gais, Lucas & Born (2006); Dresler et al. (2017)',
  ),
  '18-0': CoachContent(
    title: 'Ikervadász',
    intro:
        'A közel azonos képek emlékezeti méreg — hacsak nem edzed a '
        'megkülönböztetést. Szúrd ki a különbséget, aztán jegyezd meg.',
    steps: [
      'Pásztázd az ikreket egymás mellett, fentről lefelé.',
      'Nevezd meg hangosan mindegyik különbséget, ahogy megtalálod.',
      'Túlozz el páronként egy különbséget a rögzítéshez.',
    ],
    why:
        'A verbális címkék plusz a megkülönböztető vonások külön nyomokat '
        'adnak az ikreknek egyetlen összeolvadt pép helyett.',
    source: 'Paivio & Desrochers (1979); Von Restorff (1933)',
  ),
  '18-1': CoachContent(
    title: 'Mintatrezor',
    intro:
        'Az elvont rácsok nem hordoznak jelentést — ezért te adsz nekik. '
        'Nevezz meg motívumokat, tömbösíts cellákat, és a megjegyezhetetlen '
        'eliktatódik.',
    steps: [
      'Nevezd meg azonnal, hogy mire hasonlít mindegyik motívum.',
      'Tömbösítsd a rácsot 2-3 régióba, soha 25 cellába.',
      'Rajzold újra emlékezetből az ellenőrzés előtt.',
    ],
    why:
        'A jelentésteli átkódolás plusz a rekonstrukciós gyakorlás tartós '
        'nyomokká alakítja az elvont mintákat.',
    source: 'Bjork (1994); Paivio dual-coding theory',
  ),
  '18-2': CoachContent(
    title: 'Színkódok',
    intro:
        'Adj minden színnek egy jelentést, és a palettákból üzenetek lesznek. '
        'A színcímkék gyorsak, élénkek és szinte ingyen vannak.',
    steps: [
      'Rögzíts színenként egy jelentést — soha ne improvizálj.',
      'Képezeld el, ahogy a jelentés kölcsönhatásba lép a színnel.',
      'Idézd fel a jelentéseket sorban, ne magukban a színeket.',
    ],
    why:
        'A következetes szín-jelentés párok automatikus kódokat alkotnak, '
        'mint egy apró személyes Major-rendszer a szemnek.',
    source: 'Paivio (1979); Ericsson & Kintsch (1995)',
  ),
  '19-0': CoachContent(
    title: 'Jelenetláncok',
    intro:
        'A magányos képek fakulnak; a láncolt képek tartanak. Kösd minden '
        'jelenetet a következőhöz egy cselekvéssel, és a filmek maguktól '
        'kialakulnak.',
    steps: [
      'Kösd össze a jeleneteket egyetlen fizikai cselekvéssel.',
      'Tarts egyetlen láncot — az ágak elpattannak.',
      'Játszd vissza a filmet elejétől végéig, hangosan.',
    ],
    why:
        'A narratív láncolás sorrendet plusz jelentést ad a képeknek. A '
        'cselekvés a ragasztó, amely őrzi a sorozatot.',
    source: 'Craik & Tulving (1975); elaborative-encoding literature',
  ),
  '19-1': CoachContent(
    title: 'Forgatókönyv-táblák',
    intro:
        'A rendezők kockáról kockára tervezik a filmeket — és megjegyzik '
        'őket. Tíz rendezett képkocka mindig veri a tíz laza képet.',
    steps: [
      'Vázold fel a kockák sorrendjét a részletek kitöltése előtt.',
      'Adj minden kockának egy kulcscselekvést plusz egy kelléket.',
      'Sétálj végig a kockákon sorrendben minden felidézéskor.',
    ],
    why:
        'A rendezett képkockák locik a képeknek: a struktúra hordozza a '
        'sorrendet, így a figyelem hordozhatja a tartalmat.',
    source: 'Wagner et al. (2021); Paivio (1979)',
  ),
  '19-2': CoachContent(
    title: 'Sebességvázlatok',
    intro:
        'Rögzítsd egy kép lényegét öt másodperc alatt. A gyors vizuális '
        'bevésés edzhető készség — edzd.',
    steps: [
      'Kapj el képenként egy kulcsvonást, gyorsan.',
      'Túlozd el azonnal azt a vonást.',
      'Bízz az első rögzítésekben: nincs második pillantás.',
    ],
    why:
        'A sebesség lényeg-plusz-vonás bevésre kényszerít, pontosan ez az, '
        'ami túlél, amikor beüt az időnyomás.',
    source: 'Shepard (1967); Standing (1973)',
  ),
  '20-0': CoachContent(
    title: 'Galériaséták',
    intro:
        'Harminc képhez épület kell, nem halom. Iktasd őket galériafalakra, '
        'és vigyél el magad egy vezetett sétára.',
    steps: [
      'Ossz minden képnek egy rögzített falhelyet.',
      'Járd be a galériát mindig ugyanabban a sorrendben.',
      'Narráld a sétát hangosan, mint egy igazi idegenvezető.',
    ],
    why:
        'A téri iktatás plusz a rendezett séták a loci képekre alkalmazva — '
        'a szabvány nagy mennyiségű vizuális módszer.',
    source: 'Maguire et al. (2003); Krokos et al. VR study',
  ),
  '20-1': CoachContent(
    title: 'Készletismétlés',
    intro:
        'A képek ismétlés nélkül fakulnak. Oszd el a galériasétáidat — egy '
        'nap, három nap, egy hét — és a készlet tart.',
    steps: [
      'Járd be a teljes készletet ütemezetten, nem unalmadban.',
      'Teszteld magad; ne csak nézegesd újra.',
      'Naplózd, mely képek fakultak meg, és kódold újra őket.',
    ],
    why:
        'Az áttekintések az elosztott felidézést a leghasznosabb tanulási '
        'stratégiák közé sorolják. A képek ugyanúgy engedelmeskednek neki, '
        'mint minden más.',
    source: 'Dunlosky et al. (2013); Landauer & Bjork (1978)',
  ),
  '20-2': CoachContent(
    title: 'Homályjavítás',
    intro:
        'Egyes képek mindig előbb fakulnak. Leltározz őszintén, kódold újra '
        'a fakultakat élesebben, és az archívum éles marad.',
    steps: [
      'Járd be, és jelölj meg minden homályos képet.',
      'Kódold újra mindegyiket egy nagyobb, furcsább változattal.',
      'Teszteld újra a javítottakat még aznap.',
    ],
    why:
        'A felidézés plusz a visszajelzés nagyjából megduplázza a tesztelési '
        'hatást. A javítás céllal ellátott visszajelzés.',
    source: 'Rowland (2014) meta-analysis',
  ),
  '21-0': CoachContent(
    title: 'Harmincképes sprint',
    intro:
        'Harminc kép az óra ellen. Tempó, rendszer, bizalom — ugyanaz a '
        'három dolog, amelyet minden sebességdöntő követel.',
    steps: [
      'Véss be rögzített tempóban: képenként tíz másodperc.',
      'Iktasd minden képet a galériába menet közben.',
      'Idézd fel sorrendben egyszer, dönts, menj tovább.',
    ],
    why:
        'A rögzített tempójú bevésés megakadályozza a kapkodást és a '
        'ténfergést is. Az időzített képes versenyeket általában tempózással '
        'nyerik.',
    source: 'Timed image-event formats',
  ),
  '21-1': CoachContent(
    title: 'Elvont döntők',
    intro:
        'Húsz elvont minta, kegyelem nélkül. A kikényszerített képek plusz '
        'a címkék még a legértelmetlenebb készletet is feltörik.',
    steps: [
      'Nevezz meg azonnal minden mintát — a címkék rögzítenek.',
      'Kényszeríts minden mintára egy képet, bármilyen abszurd.',
      'Rekonstruáld emlékezetből az ellenőrzés előtt.',
    ],
    why:
        'A nehézség alatti erőfeszítéses rekonstrukció erős nyomokat épít. '
        'Kívánatos nehézség, teljes töltettel.',
    source: 'Bjork (1994); Paivio & Desrochers (1979)',
  ),
  '21-2': CoachContent(
    title: 'Galéria-ismétlés',
    intro:
        'Ötven kép, ellenséges ikrek, másnapi felidézés. Ha ezt teljesíted, '
        'befejezted a vizuális alapozást gyakorlott képeken — őszintén '
        'megszerezve, és csak ismétléssel őszintén megtartva.',
    steps: [
      'Véss be a teljes archívumot előző este.',
      'Aludj, aztán idézd fel vakon másnap reggel.',
      'Sétálj sorrendben; jelölj meg és javíts minden homályt.',
    ],
    why:
        'A mennyiség plusz a késleltetés plusz az interferencia a teljes '
        'ismétlés. Ebben a készletben már semmi sem improvizált.',
    source: 'Standing (1973); Dresler et al. (2017)',
  ),
  '22-0': CoachContent(
    title: 'Hét-visszajátszás',
    intro:
        'Egy teljes hét, napról napra, visszafelé. Az esti visszajátszás a '
        'legegyszerűbb tartós memória-szokás a szakirodalomban.',
    steps: [
      'Minden este először a napodat játszd vissza visszafelé.',
      'Estéről estére terjeszd ki egy nappal korábbra.',
      'Írd le a három legnehezebb felidézést.',
    ],
    why:
        'A visszafelé visszajátszás erőfeszítéses rekonstrukcióra '
        'kényszerít, a napi ismétlés pedig heteken belül automatikussá teszi.',
    source: 'Gais, Lucas & Born (2006); Wilhelm et al. (2011)',
  ),
  '22-1': CoachContent(
    title: 'Idővonal-szegek',
    intro:
        'A dátumok csúszósak, amíg helyekké nem válnak. Akassz eseményeket '
        'dátumozott szegekre, és egész évek rendezettek maradnak.',
    steps: [
      'Rögzíts havonta egy szeget, élénket és elkülönülőt.',
      'Akassz minden eseményt a szegére egy képpel.',
      'Sétálj végig az idővonalon előre és vissza.',
    ],
    why:
        'A dátumozott szegek a loci-sorrendet naptárstruktúrával kombinálják '
        '— két előhívási út minden eseményhez.',
    source: 'Wagner et al. (2021); Craik & Tulving (1975)',
  ),
  '22-2': CoachContent(
    title: 'Jövőpróba',
    intro:
        'Emlékezni az emlékezésre: köss minden szándékot egy hívószóhoz, '
        'amellyel biztosan találkozol. Prospektív memória, edzetten.',
    steps: [
      'Párosíts minden szándékot egy konkrét hívószóval.',
      'Képezeld el, ahogy észreveszed a hívószót, és cselekszel.',
      'Ismételd a szándékokat minden reggel, pontozd minden este.',
    ],
    why:
        'A vizsgálatokban a megvalósítási szándékok („amikor X, megteszem '
        'Y-t”) élesen emelték a betartást — jól replikált hatás. Az '
        'eredményeid a gyakorlástól függenek.',
    source: 'Gollwitzer (1999) implementation intentions',
  ),
  '23-0': CoachContent(
    title: 'Részletgyakorlat',
    intro:
        'A detektívek azért vesznek észre mindent, mert gyakorolják az '
        'észrevételt. Pásztázz, csukd be a szemed, sorolj — aztán ellenőrizz.',
    steps: [
      'Pásztázd lassan a jelenetet, részenként.',
      'Csukd be a szemed, és sorolj fel tíz részletet.',
      'Nyisd ki újra, és pontozd: mit hagytál ki?',
    ],
    why:
        'A kódolási specifitás: az ellenőrzött részletek gazdagabban '
        'vésődnek újra be, a mellélista pedig megtanítja a figyelemnek, hova '
        'menjen.',
    source: 'Tulving & Thomson (1973); Craik et al. (1996)',
  ),
  '23-1': CoachContent(
    title: 'Beszélgetés-visszajátszás',
    intro:
        'Ki mit mondott, milyen szavakkal. A párbeszédfelidézés az '
        'epizodikus kötést edzi: beszélő plusz tartalom plusz sorrend.',
    steps: [
      'Címkézz minden sort a beszélőjével hallgatás közben.',
      'Játszd vissza a kulcsidézeteket szóról szóra rögtön utána.',
      'Rekonstruáld a teljes váltást még aznap este.',
    ],
    why:
        'A beszélő, a tartalom és a sorrend kötése teljes mélységben '
        'dolgoztatja az epizodikus memóriát — a sekélyes hallgatás ezt nem '
        'tudja meghamisítani.',
    source: 'Tulving (1972) episodic memory; Craik & Tulving (1975)',
  ),
  '23-2': CoachContent(
    title: 'Sorrendőr',
    intro:
        'Tizenkét lépés sorrendben, stabilra gyakorolva. Az eljárások tiszta '
        'sorozatok — a láncolás plusz a locik rendezetten tartják őket.',
    steps: [
      'Láncold a lépéseket cselekvésekkel, kapcsanként egyet.',
      'Horgonyozd a láncot rövid útvonalra hosszú listáknál.',
      'Szavald el előre kétszer minden teszt előtt.',
    ],
    why:
        'A láncolt-plusz-elhelyezett sorozatok ellenállnak a cseréknek, mert '
        'a sorrend egyszerre két rendszerben él.',
    source: 'Craik & Tulving (1975); Wagner et al. (2021)',
  ),
  '24-0': CoachContent(
    title: 'Lefekvésprotokoll',
    intro:
        'Tíz perc lefekvés előtt ver egy órát délben. Ismételj jól, aztán '
        'hagyd, hogy az éjszakai műszak konszolidálja.',
    steps: [
      'Sétálj végig egy palotán vagy játszd vissza a napot lefekvés előtt.',
      'Tedd a nehéz tételeket utoljára — az alvás azt tartja meg, ami friss.',
      'Az ismétlés után nincs új magolás.',
    ],
    why:
        'Az alvás előnyben konszolidálja az elalvás előtti tanulást, és a '
        'teszt várása kapuzza, hogy az éjszaka mit tart meg.',
    source: 'Gais et al. (2006); Wilhelm et al. (2011)',
  ),
  '24-1': CoachContent(
    title: 'Reggeli teszt',
    intro:
        'Idézd fel ébredéskor, a telefon előtt. A reggeli teszt megmutatja, '
        'mit tartott meg valójában az éjszaka — aztán javítod a többit.',
    steps: [
      'Idézd fel az éjszakai anyagot minden bevitel előtt.',
      'Pontozd őszintén a megmaradt vs elveszett arányt.',
      'Tanuld újra azonnal a veszteségeket, aztán menj tovább.',
    ],
    why:
        'A reggeli előhívás egyszerre méri a konszolidációt és erősíti azt — '
        'a tesztelés építi a memóriát, nem csak méri.',
    source: 'Roediger & Karpicke (2006); Mazza et al. (2016)',
  ),
  '24-2': CoachContent(
    title: 'Heti ismétlés',
    intro:
        'Bővülő térközök — egy hét, egy hónap, egy évszak — perceknyi heti '
        'munkával örökké életben tartják az archívumot.',
    steps: [
      'Ütemezd az ismétléseket bővülő időközökkel.',
      'Minden ismétléskor tesztelj, ne olvass újra.',
      'Csak azt nyugdíjazd, amit kétszer hibátlanul felidéztél.',
    ],
    why:
        'A bővülő előhívási ütemezéseket évtizedekkel ezelőtt mutatták ki '
        'először, és máig a tartósság mércéi.',
    source: 'Landauer & Bjork (1978); Dunlosky et al. (2013)',
  ),
  '25-0': CoachContent(
    title: 'Hónap-visszajátszás',
    intro:
        'Harminc nap, napról napra. A naplószokásod plusz az idővonal-szegek '
        'egy teljes hónapot visszajátszhatóvá tesznek.',
    steps: [
      'Játszd vissza hétről hétre, héten belül visszafelé.',
      'Használj szegeket a hónapon belüli horgonydátumokhoz.',
      'Naplózd az üres napokat, és töltsd ki őket hívószavakból.',
    ],
    why:
        'A hierarchikus felidézés (hónapról hétre, hétről napra) veri a '
        'lapos keresést: a struktúra vezeti a rekonstrukciót.',
    source: 'Tulving (1972); Wilhelm et al. (2011)',
  ),
  '25-1': CoachContent(
    title: 'Mérföldkővizsga',
    intro:
        'Húsz életesemény dátumozott sorrendben. Az önéletrajzi felidézés '
        'ezen a szinten időutazásnak érződik.',
    steps: [
      'Sorold fel a mérföldköveket, aztán dátumozd mindegyiket pontosan.',
      'Köss mérföldkövenként egy élénk jelenetet.',
      'Szavald el sorrendben, aztán véletlen dátum szerint.',
    ],
    why:
        'A dátumozott, jelenetgazdag mérföldkövek önhivatkozási állványt '
        'alkotnak — a vizsgáltak közt a legragadósabb bevésések egyike.',
    source: 'Rogers, Kuiper & Kirker (1977) self-reference',
  ),
  '25-2': CoachContent(
    title: 'Életnapló-ismétlés',
    intro:
        'Gyakorlott napok részletesen, hívásra — plusz idézett beszélgetések '
        'és egy teljes évszak sorrendben. Az epizodikus ismétlés.',
    steps: [
      'Vegyél véletlen dátumokat, és építsd újra teljesen azokat a napokat.',
      'Idézz egyhetes beszélgetéseket emlékezetből.',
      'Sétálj végig egy teljes évszakon elejétől végéig.',
    ],
    why:
        'A véletlen dátumos felidézés azt mutatja, hogy az archívum a '
        'gyakorlott dátumokra indexelt, nem csak begyakorolt. Tartsd fenn a '
        'napi visszajátszást, hogy így is maradjon.',
    source: 'Tulving (1972); Gais et al. (2006)',
  ),
  '26-0': CoachContent(
    title: 'Tömegarcok',
    intro:
        'Tizenöt arc, tizenöt név, egy kör. Skálázd fel a 3 lépéses '
        'módszert: vonás, kép, kölcsönhatás — gyorsan.',
    steps: [
      'Keress arconként egy kiugró vonást, gyorsan.',
      'Ragaszd a névképet a vonásra.',
      'Legyen minden kölcsönhatás fizikai és gyors.',
    ],
    why:
        'A 3 lépéses módszer skálázódik: ugyanaz a hatalmas hatás, amely '
        'rögzít 2 nevet, rögzít 15-öt is, ha a vonáskeresés gyors.',
    source: 'Morris et al. face-name mnemonic (d ≈ 2.4)',
  ),
  '26-1': CoachContent(
    title: 'Hasonmások',
    intro:
        'A hasonló arcok könyörtelenül cserélik a neveket. Építs '
        'vonásmátrixot, és minden hasonmás megkapja a saját horgát.',
    steps: [
      'Hasonlítsd össze szándékosan egymás mellett a hasonmásokat.',
      'Ossz mindegyiknek egy egyedi megkülönböztető vonást.',
      'Teszteld a párokat, amíg csere nem marad.',
    ],
    why:
        'A szándékos megkülönböztetés külön nyomokat épít a hasonló arcoknak '
        '— a megkülönböztethetőség győzi le az interferenciát.',
    source: 'Von Restorff (1933); Morris et al.',
  ),
  '26-2': CoachContent(
    title: 'Késleltetett nevek',
    intro:
        'Nevek, amelyek túlélnek egy órát, aztán egy éjszakát. A '
        'késleltetett felidézés az, ahol a bulitrükkökből tartós készség lesz.',
    steps: [
      'Véss be a teljes 3 lépéssel, rövidítés nélkül.',
      'Tesztelj 5 perc, egy óra, aztán másnap után.',
      'Kódold újra a melléket vadabb kölcsönhatásokkal.',
    ],
    why:
        'A neveken végzett bővülő előhívás a klasszikus térköz-előnyt '
        'mutatja: rövid ismétlések hónapoknyi megőrzést vesznek.',
    source: 'Landauer & Bjork (1978); Beaton et al. (1995)',
  ),
  '27-0': CoachContent(
    title: 'Gyökkódok',
    intro:
        'Tanulj meg húsz gyököt, és több száz szó fejti meg magát. Az '
        'etimológia a végső szókincsemelő.',
    steps: [
      'Tanuld minden gyököt egy rögzített képpel.',
      'Bonts új szavakat gyökökre ránézésre.',
      'Építsd újra a jelentést gyökökből az ellenőrzés előtt.',
    ],
    why:
        'A morfológiai tudatosság átvisz a család minden új szavára — egy '
        'kód tucatokat nyit meg.',
    source: 'Craik & Tulving (1975); vocabulary-acquisition literature',
  ),
  '27-1': CoachContent(
    title: 'Ötvenszavas sprint',
    intro:
        'Ötven idegen szó tizenöt perc alatt. Kulcsszóláncok sebességgel — '
        'a szókincs mennyiségi versenye.',
    steps: [
      'Lőj szavanként egy kulcsszóképet, ténfergés nélkül.',
      'Fűzd a képeket futó történetbe.',
      'Teszteld rögtön utána mindkét irányban.',
    ],
    why:
        'A sebesség plusz a kulcsszavak azért működik, mert a képek '
        'gyorsabban kialakulnak, mint a magolási nyomok — a mennyiség a '
        'képezetteket jutalmazza.',
    source: 'Atkinson & Raugh (1975); Beaton et al. (1995)',
  ),
  '27-2': CoachContent(
    title: 'Kétirányú láncok',
    intro:
        'Egy szót egy irányban tudni fél tudás. A kétirányú felidézés '
        'bezárja a hurkot — mindkét irány gyakorolva.',
    steps: [
      'Előbb teszteld idegen-anyanyelvi irányban, aztán fordítva.',
      'A gyenge irányt dupla annyit gyakorold.',
      'Keverd a sorrendet: nincs láncsorrend-mankó.',
    ],
    why:
        'A kétirányú tesztelés visszajelzéssel szimmetrikus kapcsokat épít. '
        'A visszajelzés nagyjából megduplázza a nyereséget.',
    source: 'Rowland (2014) meta-analysis',
  ),
  '28-0': CoachContent(
    title: 'Ténypaloták',
    intro:
        'Harminc tény palotában veri a harminc tényt halomban. A struktúra '
        'oda iktatja a tudást, ahol megtalálod.',
    steps: [
      'Iktass állomásonként egy tényt, képekben gazdagon.',
      'Csoportosítsd a rokon tényeket szomszédos szobákba.',
      'Sétálj a felidézéshez; ugorj a szúrópróbákhoz.',
    ],
    why:
        'A szervezett bevésés plusz a locik jelentést és címet is adnak a '
        'tényeknek — felidézés sétával vagy témával.',
    source: 'Maguire et al. (2003); Chi et al. (1994)',
  ),
  '28-1': CoachContent(
    title: 'Beszédvázak',
    intro:
        'Tizenöt perces beszéd loci-vázról. Az elhelyezett pontok sorrendben '
        'tartják a beszédedet — begyakorlás után.',
    steps: [
      'Helyezz állomásonként egy beszédpontot.',
      'Képezeld el minden pontot jelenetként, nem szavakként.',
      'Próbálj sétálva, soha ne olvasva.',
    ],
    why:
        'A loci-alapú beszédek ellenállnak a leblokkolásnak: a következő '
        'állomás általában hívja a következő pontot. A szónokok ezt tudták.',
    source: 'Classical rhetoric (method of loci); Wagner et al. (2021)',
  ),
  '28-2': CoachContent(
    title: 'Számtények',
    intro:
        'Dátumok, állandók, számadatok — stabilan és pontosan gyakorlott '
        'készleteken. Szegezd a számokat képekhez, és a mennyiségek nem '
        'csúsznak ki.',
    steps: [
      'Alakíts minden számadatot a Major-kódjaiddal.',
      'Ragaszd a képet a tényre, amelyhez tartozik.',
      'Gyakorold a pontos felidézést: a közel nem számít.',
    ],
    why:
        'A kódolt számok plusz a tényképek a mennyiséget a jelentéshez '
        'kötik. A pontosság a kódból jön, nem az erőfeszítésből.',
    source: 'Major system tradition; Ericsson & Kintsch (1995)',
  ),
  '29-0': CoachContent(
    title: 'Névsprint',
    intro:
        'Húsz név öt perc alatt — hosszú táv. Stabil 3 lépéses ritmus, '
        'pánik nélkül, kihagyás nélkül.',
    steps: [
      'Dolgozd fel az arcokat sorrendben, rögzített tempóban.',
      'Vonás, kép, kölcsönhatás — minden egyes arcnál.',
      'Írd le egyszer emlékezetből a lapot, dönts.',
    ],
    why:
        'A rögzített tempójú 3 lépéses körökkel szokták nyerni az időzített '
        'névversenyeket. A rendszerek verik az idegeket.',
    source: 'Timed name-event formats; Morris et al.',
  ),
  '29-1': CoachContent(
    title: 'Szóvillám',
    intro:
        'Ötven szó tizenöt perc alatt, szóról szóra. A hosszú kör — minden, '
        'amit tanultál, sebességgel.',
    steps: [
      'Kulcsszavazz meg minden szót első ránézésre.',
      'Láncolj menet közben; nézd át kétszer a láncot.',
      'Idézd fel sorrendben, gondos szóhasználattal.',
    ],
    why:
        'A hosszú szókörök az automatikus kulcsszavakat plusz a láncolt '
        'sorrendet jutalmazzák. Mindkettő gyakorolva van már.',
    source: 'Timed word-event formats; Atkinson & Raugh (1975)',
  ),
  '29-2': CoachContent(
    title: 'Záróismétlés',
    intro:
        'Nevek plusz szavak, egy nap késleltetve, zaj alatt. Ha ezt '
        'teljesíted, befejezted a szemantikus alapozást edzett lapokon — '
        'koronázd meg egy jövő heti újrateszttel, új lapokon.',
    steps: [
      'Véss be vegyes lapokat előző este.',
      'Idézd fel vakon másnap, zajban.',
      'Javíts minden mellét, aztán teszteld újra egyszer.',
    ],
    why:
        'A vegyes, késleltetett, zajos felidézés a teljes szemantikus '
        'ismétlés. A teljesítése azt jelenti, hogy a módszer működik neked '
        'edzett anyagon — az új nevek mindig friss bevésést igényelnek.',
    source: 'Dresler et al. (2017); Dunlosky et al. (2013)',
  ),
  '30-0': CoachContent(
    title: 'Élő hangok',
    intro:
        'Ugyanaz a figyelemkapu, valódi emberek. Három-öt név valódi '
        'találkozókon, helyesírás kérdezve, köszönések visszamondva.',
    steps: [
      'Teljes fókusz minden bemutatkozáson; nincs belső ismételgetés.',
      'Mondd vissza minden nevet a köszöntésedben.',
      'Másnap írd le a neveket emlékezetből, és ellenőrizd.',
    ],
    why:
        'A valódi bemutatkozások zajt, idegességet és sebességet hoznak — '
        'pontosan azokat a körülményeket, amelyeket a labor-gyakorlatok '
        'leegyszerűsítenek. A gyakorlás itt találkozik velük.',
    source: 'Craik et al. (1996)',
  ),
  '30-1': CoachContent(
    title: 'Saját ügyek hallásból',
    intro:
        'A valódi ügyintézési listád, egyszer hallva és hangosan '
        'visszamondva. A ritmus csoportosítja; a lezárt papír ellenőrzi a '
        'pénztárnál.',
    steps: [
      'Olvastasd fel egyszer az ügyeidet; mondd vissza hangosan.',
      'Csoportosítsd ritmusba, és játszd vissza egyszer indulás előtt.',
      'Idézd fel a pénztárnál, mielőtt kinyitod a lezárt listát.',
    ],
    why:
        'A listák hangos kimondása plusz a ritmikus csoportosítás megtartja '
        'a hallott tételeket. A lezárt lista pontozott felidézéssé alakítja '
        'a vásárlást.',
    source: 'MacLeod et al. (2010); Purnell-Webb & Speelman (2008)',
  ),
  '30-2': CoachContent(
    title: 'Esti hangnapló',
    intro:
        'Három este a napközben hallott nevek és számok visszajátszásával. '
        'Rövid alkalmak, leírt nehéz felidézések, alvás utána.',
    steps: [
      'Játszd vissza sorrendben a nap hangjait lefekvés előtt.',
      'Mondd ki minden nevet és számot egyszer, hangosan, ha tudod.',
      'Naplózd minden éjjel a három legnehezebb felidézést.',
    ],
    why:
        'Az esti ismétlés plusz az alvás többet tart meg, mint a reggeli '
        'tanulás, a napló pedig megmutatja, mely hangoknak kell második menet.',
    source: 'Gais, Lucas & Born (2006)',
  ),
  '31-0': CoachContent(
    title: 'Számok, amelyeket tárcsázol',
    intro:
        'Két telefonszám, amelyet tényleg használsz, képekre tömbösítve és '
        'egy hétig emlékezetből tárcsázva. Valódi számjegyek, valódi haszon.',
    steps: [
      'Tömbösítsd 3-asával minden számot; képezd le mindegyik tömböt.',
      'Fűzd a tömböket számonként egy jelenetbe.',
      'Idézd fel minden reggel a névjegyzék ellenőrzése előtt.',
    ],
    why:
        'A tömbösített képek a hosszú számsorokat rövid jelenetekké '
        'alakítják. A reggeli felidézés ingyen osztja el az ismétléseket.',
    source: 'Miller (1956); Ericsson, Chase & Faloon (1980)',
  ),
  '31-1': CoachContent(
    title: 'Lezártlistás vásárlás',
    intro:
        'Négy, aztán nyolc tétel, lezárva a zsebedben, felidézve a '
        'pénztárnál. A papírlista a válaszkulcs, nem mankó.',
    steps: [
      'Képezd le a listát hármas csoportokban rövid jelenetekként.',
      'Sétáld végig egyszer a jeleneteket a boltba lépés előtt.',
      'Idézz fel mindent a pénztárnál, aztán nyisd ki a papírt.',
    ],
    why:
        'A pénztári felidézés — nem a sorok közti újraolvasás — építi a '
        'felidézési utat, amelyet legközelebb használni fogsz.',
    source: 'Cowan (2001); Roediger & Karpicke (2006)',
  ),
  '31-2': CoachContent(
    title: 'Fontos dátumok',
    intro:
        'Öt születésnap vagy évforduló archoz kötött képekkel rögzítve, '
        'barát által véletlen sorrendben kikérdezve.',
    steps: [
      'Képezd le minden dátumot a személy fotójával vagy archívószavával.',
      'Idézd fel mind az ötöt minden este egy hétig.',
      'Kérj meg valakit, hogy kérdezzen ki keverve; a melléket még aznap este javítsd.',
    ],
    why:
        'Az archoz kötött dátumképek a páros asszociációs utat hasznosítják '
        'újra olyan anyagon, amelyről tényleg kérdezni fognak.',
    source: 'Ericsson & Kintsch (1995)',
  ),
  '32-0': CoachContent(
    title: 'Otthoni útvonalad',
    intro:
        'Tíz állomás a valódi otthonodban, ajtótól a hálószobáig, vakon '
        'végigsétálva. Ez az útvonal lesz az alapértelmezett palotád saját '
        'listákhoz.',
    steps: [
      'Írd le papírra a 10 állomást szigorú sorrendben.',
      'Sétáld végig kétszer az állomásokat megnevezve, még tárgyak nélkül.',
      'Helyezz el 10 szót, jelenetenként egy mozgó képet, és sétáld újra.',
    ],
    why:
        'Az ismert útvonal rögzített sorrendben kiiktatja a sorrendproblémát: '
        'a séta hordozza a sorozatot, a képek a tételeket.',
    source: 'Dresler et al. (2017)',
  ),
  '32-1': CoachContent(
    title: 'Utcai útvonalad',
    intro:
        'Tizenöt elkülönülő szabadtéri pont, amely mellett gyakran elmész. '
        'Csak éles pontok — a hasonló állomások összefolynak.',
    steps: [
      'Sétálj, és válassz 15 éles, elkülönülő pontot sorrendben.',
      'Nevezd meg mindegyiket két szóval; írd le a teljes sorrendet.',
      'Helyezz el 15 tanulós vagy munkás tételt a séta mentén.',
    ],
    why:
        'Az elkülönülő locik csökkentik a tételek közötti interferenciát. A '
        'szabadtéri útvonalak rögzítés után évekig stabilak maradnak.',
    source: 'Maguire et al. (2003)',
  ),
  '32-2': CoachContent(
    title: 'Két útvonal, húsz tétel',
    intro:
        'Egy valódi 20 tételes listád elosztva mindkét útvonalon, este '
        'végigsétálva, másnap reggel írásban felidézve.',
    steps: [
      'Oszd el: 10 otthoni plusz 10 utcai; állomásonként egy jelenet.',
      'Esti séta mindkét útvonalon lefekvés előtt.',
      'Reggeli írásbeli felidézés; csak a melléket sétáld újra.',
    ],
    why:
        'Az esti bevésés plusz a reggeli felidézés alvást tesz az ismétlések '
        'közé. A séta egyszeri megtanítása tovább rögzíti a sorrendet.',
    source: 'Wagner et al. (2021); Mazza et al. (2016)',
  ),
  '33-0': CoachContent(
    title: 'Munkfeladatok képekben',
    intro:
        'Hat elvont feladat nagy, mozgó képekké alakítva szobasarkokon, '
        'délben felidézve, a listával ellenőrizve.',
    steps: [
      'Képezd le minden elvont feladatot egy konkrét jelenetként.',
      'Legyen nagy, élénk és mozgó; kösd egy sarokhoz.',
      'Délben sorold fel mind a hatot a képekből, aztán ellenőrizd.',
    ],
    why:
        'A konkrét képek második kódot adnak az elvont feladatoknak. A déli '
        'felidézés a képeket teszteli, nem a papírt.',
    source: 'Paivio dual-coding; Shepard (1967)',
  ),
  '33-1': CoachContent(
    title: 'Fotók egy éjszakán át',
    intro:
        'Egy zsúfolt fotó egyszer megnézve, hat részlet másnap felidézve. '
        'Az eltúlzott címkék elkülönítik a hasonló részleteket.',
    steps: [
      'Nevezz meg hangosan hat részletet egyetlen megnézéskor.',
      'Túlozz el szándékosan részletenként egy vonást.',
      'Építsd újra a fotót emlékezetből másnap az ellenőrzés előtt.',
    ],
    why:
        'Az egy éjszakán át tartó részletfelidézés tartós képnyomokat edz. '
        'A körönkénti friss fotók őszintén tartják a tesztet.',
    source: 'Standing (1973)',
  ),
  '33-2': CoachContent(
    title: 'Megbeszéléscsíkok',
    intro:
        'Öt megbeszéléspont elhangzáskor képekbe öntve és egyetlen csíkba '
        'fűzve, másnap reggel visszajátszva, a jegyzőkönyv alapján '
        'ellenőrizve.',
    steps: [
      'Képezd le mindegyik pontot abban a pillanatban, ahogy hallod.',
      'Fűzd össze az 1→2→3→4→5 pontokat apró cselekvésekkel.',
      'Játszd vissza a csíkot távozás előtt, újra másnap reggel.',
    ],
    why:
        'A kapcsolt képek a tételeket és a sorrendet is kihordozzák a '
        'megbeszélésekről. A jegyzőkönyv a válaszkulcs.',
    source: 'Von Restorff (1933)',
  ),
  '34-0': CoachContent(
    title: 'Tanulóláncok',
    intro:
        'Tíz tanulási fogalom egyetlen bolondos kalandként, másnap hangosan '
        'újramesélve. Csak egy lánc — az ágak elpattannak.',
    steps: [
      'Láncold az 1→2→3 fogalmakat sorrendben cselekvésekkel, ágak nélkül.',
      'Meséld el hangosan a történetet rögtön a felépítés után.',
      'Meséld el másnap reggel; jegyezd fel, hol szakadt a lánc.',
    ],
    why:
        'A narratív láncolás sorrendet plusz jelentést ad a puszta '
        'fogalmaknak. A szakadáspont mutatja, mely kapocsnak kell erősebb '
        'jelenet.',
    source: 'Craik & Tulving (1975)',
  ),
  '34-1': CoachContent(
    title: 'Hét éjszaka naplózva',
    intro:
        'Hét este visszafelé napi visszajátszással, rövid naplóval. A 8. '
        'napon az 1. nap felidézése csak hívószavakból.',
    steps: [
      'Játszd vissza minden napot visszafelé, jelenetről jelenetre.',
      'Állj meg az arcoknál, számoknál és pontos szavaknál.',
      'Naplózd minden éjjel a három legnehezebb felidézést.',
    ],
    why:
        'Az éjszakai visszajátszás várása megváltoztatja, hogy a nap mit '
        'vés be. A napló elosztott felidézéssé alakítja az estéket.',
    source: 'Wilhelm et al. (2011); Gais et al. (2006)',
  ),
  '34-2': CoachContent(
    title: 'Hangosan újramesélve',
    intro:
        'Egy cikk egyszer elolvasva, mint egy rövid film, még aznap este '
        'hangosan újramesélve, aztán újra másnap. A hallgató jelöli a '
        'kihagyásokat.',
    steps: [
      'Olvasd el egyszer, újbóli olvasás nélkül, a jelenetek lejátszásával menet közben.',
      'Meséld el hangosan, ki mit csinált, számokkal.',
      'Másnapi újramesélés; hasonlítsd össze, mely kihagyások maradtak kihagyva.',
    ],
    why:
        'Az aznapi esti plusz a másnapi újramesélés nagy fölénnyel veri az '
        'újraolvasást, és a rés a késleltetéssel nő.',
    source: 'Roediger & Karpicke (2006); Rowland (2014)',
  ),
  '35-0': CoachContent(
    title: 'Nevek eseményeken',
    intro:
        'Öt valódi név egy összejövetelen a 3 lépéses módszerrel, később két '
        'néven köszönés, másnap teljes lista.',
    steps: [
      'Előbb a vonás, aztán a horogkép, aztán a kölcsönhatás.',
      'Köszönj néven két embernek távozás előtt.',
      'Sorold fel mind az ötöt a vonásokból másnap.',
    ],
    why:
        'A valódi események hozzáadják a nyomást, amelyet az applapok '
        'kihagynak. A néven köszönés a pontozott ismétlés.',
    source: 'Morris et al. face-name mnemonic',
  ),
  '35-1': CoachContent(
    title: 'Két hét szavakkal',
    intro:
        'Húsz szó, amelyre tényleg szükséged van, napi kettő kulcsszavas '
        'jelenetekkel, két héten át naponta tesztelve mindkét irányban.',
    steps: [
      'Naponta két új szó, mindegyik egy kulcsszavas jelenettel.',
      'Teszteld naponta idegen-jelentés és vissza irányban, visszajelzéssel.',
      'Ismételd a melléket még aznap este és másnap reggel.',
    ],
    why:
        'A napi kétirányú tesztelés visszajelzéssel életben tartja a '
        'kulcsszópárokat. A 14. napi kevert teszt megmutatja, mi maradt meg.',
    source: 'Atkinson & Raugh (1975); Beaton et al. (1995)',
  ),
  '35-2': CoachContent(
    title: 'Beszédek és tények élesben',
    intro:
        'Egy valódi 5 pontos beszéd loci-vázról plusz 10 saját tény '
        'szobákban. A hallgató visszamondja a pontokat; az állomásokat hívják.',
    steps: [
      'Helyezd a beszédpontokat állomásokra; sétáld végig kétszer előző este.',
      'Add elő jegyzet nélkül; jegyezd fel, hol akadtál meg.',
      'Iktass 10 saját tényt; válaszolj rájuk véletlen állomásokon.',
    ],
    why:
        'A beszédek és a tények egy készségen osztoznak: rendezett pontok '
        'egy sétán. A hallgatói ellenőrzések őszintén tartják a pontozást.',
    source: 'Dresler et al. (2017); Chi et al. (1994)',
  ),
};
