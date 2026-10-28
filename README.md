# Engrammo

Saját fejlesztésű, kutatásalapú memóriatréning Flutterrel.
Induló szintmérés memóriatípusonként, személyre szabott
tanulási útvonal, tanítható mnemotechnikák és távközött
ismétlés (FSRS) — rövid napi leckékkel és játékos
motivációval. Futás közben élő Meta Model API hívással,
offline tartalékkal.

> A név az `engram` szóból jön: az emlék fizikai nyoma.
> Nem ígér fotografikus memóriát — az mítosz. Tanítható
> technikákat ad helyette: memóriapalotát, társítást,
> kulcsszó-módszert.

## Mit csinál az app?

1. **Szintmérés induláskor.** Térbeli, vizuális, verbális és
   munkamemória-feladatokkal megméri, honnan indulsz.
2. **Személyre szabott útvonal.** Az induló szintedtől épít
   rövid leckéket, nem egy sablont tol mindenkire.
3. **Mnemotechnikák.** Loci / memóriapalota, láncolás, képi
   társítás, kulcsszó-módszer, számrendszerek.
4. **Visszakérdezés napokkal később.** FSRS-lite ütemező hozza
   vissza a tanult anyagot, alvási konszolidációra építve.
5. **Játékosítás.** Szint, rang, streak, rövid leckék,
   párbaj-mód (Battle Zone) és liga.

## Meta AI a futás közben

A versenyfeltétel miatt az app futás közben legalább egy
élő Meta-hívást indít:

- **Muse Spark** adja a feladatot (`muse-spark`),
- **Muse Image** adja a mintaképet (`muse-image`),
- **SAM** szegmentál valós környezetre, pl. íróasztalra
  (csak a térbeli Palace-útvonalon).

Ha nincs kulcs vagy nincs háló, az app nem omlik össze:
a helyi generátorok adják a tartalmat, és minden hívás
naplózva van (modellnév, idő, siker/hiba, fallback-e).
A hívásnapló a felületen is megnézhető.

Részletes műszaki terv a repóban: `docs/META_TERV.md`.
Kutatási háttér a gépemen: `~/Downloads/meta` mappa
(2 versenykiírás-PDF, 1 memóriakutatás-PDF a loci +
FSRS + napi szokáskialakítás pillérekről, 1 jelentkezés-
másolat). Ezekből csak a tudományos állítások és a
bírálati súlyok jöttek: minden kód, szöveg és képernyő
saját munka, másolt kódrészlet, adat és védjegyes
megjelenés nélkül.

## Tudományos alap (röviden)

- A mechanikus agyjátékok önmagukban nem fejlesztenek
  általánosan (Simons et al. 2016; Owen et al., Nature) —
  ezért az app kódolási technikákat tanít, nem reflexet edz.
- A loci-módszer hetek alatt átszervezi a memóriahálózatokat
  (Maguire et al. 2003; Dresler et al. 2017; Wagner et al. 2021).
- Nevekhez és szavakhoz név-arc képi technika (Morris et al.
  1978) és kulcsszó-módszer (Atkinson és Raugh 1975).
- Az ismétlést FSRS-ütemező időzíti (DSR-modell: nehézség,
  stabilitás, előhívhatóság).

## Képernyők

- Belépés: Google, email/jelszó, vendég mód.
- Tanulási útvonal, szintmérő, memóriajátékok
  (szekvencia, szám, szó, vizuális minta, sorrendi
  felidézés), memóriaprofil.
- Battle Zone párbaj, Brain League, avatar, beállítások
  (sötét mód, haptika, fiókműveletek).

## Tech

- Flutter, Dart `^3.13.4`, `1.0.0+1`, `publish_to: none`.
- Ikonok: semleges, nem Material-androidos készlet.
- Betű: Lexend (változó vastagság 100–900), helyi assetből,
  offline is működik, magyar ékezetekkel (latin-ext).
- Firebase: Auth + Firestore-szinkron (`users/{uid}`
  merge-írás, belépéskor lehúzás, offline best-effort).
- Háló: `http`, timeoutos, best-effort Meta-hívások.
- Állapot: egyszerű `Listenable` + `MemoryStore`,
  nincs Riverpod / Bloc / router.

## Projektstruktúra

- `lib/main.dart` — indítás, Firebase + beállítás-betöltés.
- `lib/screens/` — képernyők (útvonal, szintmérő,
  memóriajátékok, battle, profil, beállítások).
- `lib/models/` — tanterv, FSRS-kártya, Meta-feladat /
  kép / szegment modellek.
- `lib/services/` — auth, felhő-szinkron, memória-tár,
  Meta AI-szerviz, beállítások.
- `lib/theme/`, `lib/widgets/`, `lib/utils/` — téma,
  közös gombok, navigáció, streak-segédek.
- `test/` — 30 tesztfájl: modellek, FSRS, Meta-szerviz
  fallback, auth, szinkron, széria/engram-gazdaság,
  UI-apróságok (`flutter test`).
- `tool/run.sh` — indító szkript `.env`-kulccsal.

## Futtatás

```bash
flutter pub get
flutter analyze
flutter test
```

Élő Meta-hívással: a kulcs egyszer kerül a gitignore-olt
`.env` fájlba (minta: `.env.example`), onnantól elég:

```bash
sh tool/run.sh
```

Egy alkalomra kézzel is mehet:

```bash
flutter run --dart-define=MODEL_API_KEY=IttAKulcsod
```

Konfig nélkül is elindul: ilyenkor offline módban megy,
a belépő helyett egyből az app nyílik, minden adat a
készüléken marad. Firebase-bekötéshez lásd:
`FIREBASE_SETUP.md` (EU-régió ajánlott, `flutterfire
configure --project=engrammo-app`).

## Jegyzet a régi leírásról

A git-előzményeket visszanéztem: a korábbi commitekben
csak a Flutter-sablon leírás volt (`A new Flutter project`),
normális projektbemutató sehol. Ez a fájl az első rendes
leírás, a `~/Downloads/meta` anyagok és a mai kód alapján.
