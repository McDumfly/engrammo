# Engrammo — Meta modellek bevezetési terve (részletes)

> Állapot: befejező átnézés kész (2026-10-28) — a Meta-réteg, az FSRS-lite,
> a felhő-szinkron és a javítócsomag (csillag-merge, engram-gazdaság,
> DST-biztos széria, http-zárás, aréna őszinte-kikapcsolása) be van kötve.
> Ez a dokumentum a teljes tervet és a már beépített réteget írja le.
> Forrás: `downloads/meta`
> mappa (2 hackathon PDF + 1 kutatási PDF + 1 `textClipping`
> jelentkezés-másolat) — ezekből csak a tudományos állítások és a bírálati
> súlyok jönnek, kódot nem másolunk belőlük.

## 1. Cél és sikerkritériumok

Az Engrammo fusson végig versenykompatibilisen:

1. induló szintmérés (`memory_profile.dart`),
2. személyre szabott útvonal (`learning_path.dart`),
3. tanítható mnemotechnikák — loci, képi társítás, kulcsszó
   (`curriculum.dart`),
4. FSRS távközött ismétlés,
5. futás közben **legalább egy élő Meta API hívás** (Muse Spark feladat,
   Muse Image minta vagy SAM 3.1 szegmentálás),
6. offline módban a mai helyi generátorok adják a tartalmat.

Sikerkritériumok:

- `MetaAIService` legalább egy képernyőn élesben meghívódik
  (`MemoryAssessmentPage.initState` már ma is hívja, best-effort).
- Minden hívás naplózott: modellnév, időbélyeg, siker/hiba, fallback-e.
- Új modellek: `lib/models/meta_task.dart`, `meta_image.dart`,
  `meta_segment.dart`, `fsrs_card.dart` — mind `fromJson/toJson/copyWith/==`
  lefedéssel, a meglévő `curriculum.dart` / `battle_rating.dart`
  stílusában.
- A mai statikus pontok kiváltva vagy kiegészítve (fallbackal):
  `memory_profile.dart:103 _buildTasks`, `benchmark.dart` 4 játék
  (szekvencia, szám, szó, vizuális), `curriculum.dart:51 const chapters`
  (tartalék tanterv marad), `battle_zone.dart:72-113 _pastMatches` mellé
  AI-kihívó.
- Térköz-ütemezés perzisztálva (`SharedPreferences` +
  Firestore `users/{uid}` merge), best-effort offline elv megmarad
  (offline fallback a `main.dart`-ban). A per-card FSRS-állapot
  követve és szinkronizálva van; az ismétlési kaput a mélység/nap
  alapú térköz-számítás hajtja.
- `flutter analyze` tiszta, mind a 94 tesztfájl zöld
  (`flutter test`, 834 teszt). Nincs `flutter run` /
  emulátor / screenshot.

## 2. Architektúra: vékony, best-effort réteg

Nincs új állapotkezelő (marad a `ListenableBuilder(appSettings,
authService)` + `MemoryStore.onChanged → CloudSync.pushNow` minta a
`lib/main.dart` és `services/auth_service.dart:71-72` szerint).
Nincs Riverpod / Bloc / router-bevezetés.

```
képernyő → MetaAIService.generateTask/generateImage/segment
              → élő válasz (fallback: false)
              → hiba / nincs kulcs / nincs háló → helyi generátor
                (fallback: true) + naplóbejegyzés
```

- Konfig: egyetlen kulcs, egyszer a gitignore-olt `.env` fájlba beírva
  (`MODEL_API_KEY=...`, sablon: `.env.example`). A `.env` assetként
  becsomagolódik, így a sima `flutter run` is kulcsot talál, begépelés
  nélkül; a `tool/run.sh` ugyanezt `--dart-define` úton adja át. Kézzel
  egy alkalomra `--dart-define=MODEL_API_KEY=...` is jó, régebbi
  `META_API_KEY` név is elfogadott, soha nem `firebase_options.dart`-szerű
  hardcoded kulcs. A felhő-hozzájárulás alapból be van kapcsolva
  (Beállítások → Meta AI alatt kikapcsolható).
  A cím fix: `https://api.meta.ai/v1`, nem kell base URL-t ismerni.
- Függőség: `http ^1.2.0` (a `pubspec.yaml:30-46`-ban eddig nem volt
  `http/dio/ai`). Android `INTERNET` engedély tudatosítva
  (eddig egy sem volt a manifestben).
- Megfigyelhetőség: `MetaCallEntry(model, kind, at, success, fallback,
  note)` — memóriában (`lastCalls`) + perzisztálva
  (`meta_call_log_v1`, cap 50). Megjelenítés:
  `lib/widgets/meta_call_log.dart` (`MetaCallLogView`) és debug-napló.

## 3. Adatmodellek

### 3.1 `MetaTaskRequest` / `MetaTask` (`lib/models/meta_task.dart`)

- `MetaTaskRequest(kind, difficulty 1..5, seed, locale)`.
- `MetaTask(prompt, items, explanation, options, correct, model,
  createdAt, fallback)`.
- `kind` értékei: `sensory, working, spatial, visual, episodic,
  semantic, sequence, number, verbal, order, duel`.
- Minden mező JSON-kerekítéssel, hiányos JSON biztonságos alapokra esik
  (üres lista / `fallback: true` / epoch-dátum).

### 3.2 `MetaImageRequest` / `MetaImage` (`lib/models/meta_image.dart`)

- `MetaImageRequest(prompt, style, size)`; `cacheKey` a
  `dicebear_generator.dart:9-17` rendezett join mintájára
  (beszúrási sorrendtől független), `promptHash` függőség nélküli
  FNV-1a ujjlenyomat a naplózáshoz.
- `MetaImage(url|promptHash|cacheKey, model, createdAt, fallback)`.
  Üres `url` = helyi tartalék (nincs letöltött kép).

### 3.3 `MetaSegmentRequest` / `MetaSegment` (`lib/models/meta_segment.dart`)

- A palota- és képdúsító (`enrichSpatialTask` / `enrichVisualTask`)
  használja: `concept` (egy rövid főnévi fogalom) + `imageRef`;
  válaszban geometria (`boxes` normalizált 0..1 dobozok + `masks`
  nyers `<|mask;…|>` tokenek). Neveket a SAM nem ad — a címkék
  Spark VLM földelt képolvasásból (`spotImageLabels`) jönnek.
  `points` / `boxes` kérésmezők JSON-kompatibilitásból megvannak,
  de a küldés a fogalom-ágat használja (objektum-prompt pixelméret
  nélkül nem építhető). Offline: üres geometria tartalék.

### 3.4 `FsrsCard` + `FsrsScheduler` (`lib/models/fsrs_card.dart`)

- `FsrsCard(cardId, taskId, stability napokban, difficulty 1..10, due,
  reps, lapses)` + `isDue([now])`.
- `FsrsScheduler.next(card, grade 1..4, [now])` tiszta függvény:
  - 1 = újra (stabilitás ×0.3, nehézség +1, lapses+1),
  - 2 = nehéz (×1.15), 3 = jó (×1.6), 4 = könnyű (×2.2,
    nehézség −0.6),
  - intervallum `stability` napokban (0.2..365-re vágva).
- `dueCards(cards, [now])` csak az esedékeseket adja, legkorábbi elöl.

## 4. `MetaAIService` (`lib/services/meta_ai_service.dart`)

- Valós végpontok ([Meta Model API](https://dev.meta.ai/docs), fix cím
  `https://api.meta.ai/v1`, `Bearer MODEL_API_KEY`, OpenAI-kompatibilis):
  feladat `POST /chat/completions` (`muse-spark-1.3`,
  `minimal` efforttal, bő `max_completion_tokens` kerettel — élő mérés:
  a null-alap ~900 gondolati tokent éget, a szerver kicsi alapkeretét
  pedig a gondolkodás feli, `content: null` + `finish_reason: length`
  választ adva; `length`-levágásnál a kérés egyszer, dupla kerettel
  újraindul —, a modell JSON-t ad, a kód ``` keretet is lefejt és
  `correct`-et vág), kép
  `POST /images/generations` (`muse-image-1.0`, `url` vagy `b64_json`,
  25 mp timeouttal, mert ~14 mp a generálás), szegmentálás
  `POST /responses` (`sam-3.1`, csak valódi képpel hívható,
  hívásonként EGY rövid főnévi fogalommal; a válasz a dokumentált
  speciális-token nyelvtan `<0f>…<|box;…|><|mask;…|>` — geometria,
  soha nem JSON-címke),
  képolvasás `POST /responses` (Spark VLM földelt címkézéssel: nevek
  + 0–1000-es dobozok egy JSON-tömbben — ez a címkeforrás, mert a
  SAM nevet nem ad),
  útvonal-előzetes `POST /chat/completions` (`muse-wonder-1.0` — a
  `muse-` előtag nélkül 404).
  (A hangátírás 11-01-én kikerült: a szójáték koppintós lett,
  a `record`/`cross_file`/`http_parser` függőségekkel és a
  mikrofonengedélyekkel együtt.) A Glimmer és a Spark Open nyílt
  súlyú, saját hosztolású — nincs Meta API-végpontjuk, ezért a kód
  nem is hívja őket (beépített sablon + őszinte helyi napló).
- Minden élő metódus (`generateTask`, `generateImage`, `segment`,
  `spotImageLabels`, `wonderRoutePreview`, …) ugyanazt a mintát követi:
  1. ha nincs kulcs → helyi tartalék + `fallback: true` napló,
  2. élő `POST` timeouttal (chat 12 mp, kép 25 mp) + egyszeri
     újrapróbálás ~1 mp múlva átmeneti hibára (timeout,
     kapcsolódás, 429/5xx),
  3. 2xx + parse-olható válasz → élő találat (`fallback: false`),
  4. egyébként `StateError` → tartalék + hibanapló, az app nem omlik.
  A SAM nulla találata érvényes üres válasz (success + fallback),
  nem hiba.
- Helyi tartalékok (`_localTask`): a mai generátorok Meta-alakra hozva
  (számhossz nehézségből, szó a készletből, szekvencia-hossz nehézségből,
  vizuális cellák). A magyarázat mező hordozza a mnemotechnikát
  (chunking / kulcsszó / loci).
- Napló: `_log()` minden ágról ír (nincs kulcs / élő / hiba).

## 5. Képernyő-pluginek (egyenként, fallbackal)

### 5.1 Szintmérő — `screens/memory_profile.dart`

- `_buildTasks` (6 fix elem, `:103`) változatlanul az offline tartalék.
- Új: `metaTaskToAssessmentTask(context, task, kind)` leképezés és
  `loadAssessmentTasks(context)` (6 fajta: sensory…semantic, egy-egy
  `generateTask`, fallbacknél az adott helyi elem).
- Élő hívás már ma: `MemoryAssessmentPage.initState` egy best-effort
  `generateTask(kind: 'sensory')` előtöltést indít — a UI addig is a
  helyi feladatokkal rajzol.

### 5.2 Benchmark — `screens/benchmark.dart`

- `BenchmarkStore.submit/xp/level (:16-46)` változatlan.
- Új `BenchmarkMeta` osztály 4 csatlakozóval:
  `numberStimulus(digits)`, `wordStimulus()`, `sequenceStimulus(length)`,
  `visualPattern(size, count)` — mindegyik Meta-hívás + helyi tartalék.
- Új nyilvános gyári metódusok a tesztelhetőségért:
  `NumberGamePage.make`, `VerbalGamePage.pickFresh`,
  `SequenceGamePage.make`, `VisualGamePage.makePattern`.
  A meglévő játékoldalak logikája változatlan.

### 5.3 Tanterv — `models/curriculum.dart`

- `const chapters (:51)` marad a tartalék tanterv.
- Új: `lessonFromMetaTask(task)` — Spark-lecke ugyanarra a
  `LessonSpec(title, detail, icon)` alakra (tipp az
  `explanation`-mezőből: loci / képi társítás / kulcsszó).

### 5.4 Battle Zone — `screens/battle_zone.dart`

- `_pastMatches (:72-113)` változatlan.
- Új: `aiDuelTask(kind, {difficulty})` — opcionális AI-kihívófeladat
  a párbajhoz (`battle_rating.dart` / `battle_invites.dart` mellé).

### 5.5 Kép — DiceBear + Meta Image

- `dicebear_generator.dart` kétszintű cache (memória + `avatar_svg_v1::*`,
  cap 40) változatlan.
- Meta Image ugyanazt a kulcs- és LRU-elvet követi
  (`MetaImageRequest.cacheKey`, `MemoryStore.metaCacheCap = 40`).
- SAM 3.1 a palota- és képdúsítón (vezető állomás/tárgy geometriája);
  a címkéket Spark VLM képolvasás adja (`spotImageLabels`).

## 6. Perzisztencia + szinkron + ütemezés

- `MemoryStore` új kulcsok (a meglévők mellé:
  `memory_scores_v1`, `streak_*_v1`, `engrams_v1`, historyCap 400):
  - `fsrs_cards_v1` (cap 200, `kártyaId=json` listaként),
  - `meta_cache_v1` (cap 40),
  - mindegyik `load` / `saveWithoutNotify` / `save` hármassal,
    a `save` továbbra is `_notifyChanged()`-et hív.
- `CloudSync` bővítés (mindkét irány, merge-írás `users/{uid}` alá):
  - `pushFromLocal`: `fsrsCards` + `metaCache` mezők,
  - `pullToLocal`: ugyanazok vissza `save*WithoutNotify`-jal,
  - `pushNow` változatlanul a `MemoryStore.onChanged`-ről.
- Ütemező: `FsrsScheduler.dueCards` szerinti lekérdezés a tanulási
  útvonalon. Értesítés (`flutter_local_notifications`) külön lépésben —
  ma a `settings_screen.dart:23` szerint nincs ilyen UI és nincs engedély.

## 7. Validáció

- `flutter analyze` (lints: `analysis_options.yaml` → `flutter_lints`,
  kizárva `build/**`, platformmappák).
- `flutter test` a teljes suite-ra (94 fájl, 834 teszt):
  modellek (JSON-kerekítés, `cacheKey`-sorrendfüggetlenség),
  FSRS `next()` határesetek (bukás / vágott értékelés /
  rendezett esedékesek), térköz-kapu (gyenge menet után
  nincs zár), offline fallback (nincs háló → helyi tartalom,
  nincs összeomlás), FSRS/meta-cache mentés-visszatöltés,
  auth/szinkron merge-szabályok, onboarding és képernyő-flow-k,
  nyelv-paritás (EN↔HU kulcsok + helyőrzők).
- Kézi ellenőrzés kódból (futtatás nélkül, költség-stop miatt):
  Meta-hívás csak `MetaAIService`-ben; minden hívóhelyen fallback;
  Firestore-írás merge és offline-safe.
- Negatív esetek: nincs API-kulcs → offline tartalom; nincs háló →
  `AuthBackendUnavailable`-szerű kegyes leépülés
  (`auth_service_test` minta); Firestore-hiba → helyi mentés továbbmegy.

## 8. Kockázatok és nyitott kérdések

- Versenykapu: futás közbeni Meta-hívás ma már van (előtöltés a
  szintmérőn), de élő kulcs nélkül minden válasz `fallback: true` —
  a demó előtt elég a `.env`-be írt kulcs (sima indítás is élő).
- Határidő (nov. 4. 21:00 ET): FSRS + értesítés együtt nem fér bele;
  sorrend: modellek → service → 1 képernyő → FSRS-lite → beadhatóság.
- Firebase-titkok: `firebase_options.dart` hardcoded kulcsai gitignoredak,
  de leak-veszélyesek — beadáshoz dokumentált, reprodukálható setup kell.
- Nyitott ellenőrzések: Meta API pontos végpont/autentikáció a 3 PDF teljes
  szövegéből és a `textClipping` RTF-törzsből még visszaellenőrizendő;
  `docs/verseny-naplo.md` pótolva; `engrammo_ui_lab` / `muse_remote`
  átfedés nem vizsgált; monolitok (`learning_path`, `battle_zone`,
  `battle_duel_page`, `kreeds_profile` egyenként 1500+ sor)
  nem refaktorálandók a verseny alatt.

## 9. Futtatás (kód, nem képernyőkép)

```bash
cd Projektek/engrammo
flutter pub get
flutter analyze
flutter test
# Élő Meta-hívással (kulccsal; a kulcs a Meta-dashboards-ról jön,
# soha nem kerül gitbe). Egyszeri beállítás: írd be a kulcsod a `.env`
# fájlba (sablon: `.env.example`), onnantól elég:
sh tool/run.sh
# Kézzel, egy alkalomra pedig:
flutter run --dart-define=MODEL_API_KEY=IttAKulcsod
```

PDF-export: ezt a fájlt a szerkesztő "Print → Save as PDF" funkciójával
lehet beadható PDF-fé alakítani (a repóban a markdown a forrás).

## 10. Megvalósult (2026-10-28, éjszakai állapot + 10-30 AI-bővítés)

- 10-30: mindhárom modell minden felületen: Spark minden leckekörben
  és minden gyakorlójátékban ingert ad (háttér-előhívás), plusz
  lecke-/gyakorló-/párbajösszegző (`sessionRecap`) és játéktipp
  (`practiceTip`); Muse Image a térbeli + vizuális körök mellett a
  szöveges leckeköröket is illusztrálja, és a gyakorló vizuális
  játék minden 3. szintje egyedi képes felidézőkör; SAM a palota-
  és a képi jelenetekre is fut (állomások + észlelt részletek),
  leckében és gyakorlásban egyaránt. Új hívóhelyek:
  `benchmark.dart` (BenchmarkMeta.pictureRound/spatialRound,
  előhívott Spark-ingerek, `_AiTip`), `lesson_player.dart`
  (minden kör frissül, `_aiRecapCard`, `_missedCard`),
  `battle_duel_page.dart` (`_DuelRecap`). Tesztek:
  `test/meta_ai_practice_test.dart` (9 teszt, offline tartalék +
  kérés-alak + képkapu).

- Mindhárom Meta-modell éles a leckékben: Spark adja a feladat-ingert
  (`generateTask`), SAM 3.1 a térbeli loci-állomásokat, Muse Image a
  térbeli palotaképet és a vizuális jelenetképet
  (`enrichSpatialTask` / `enrichVisualTask`, hívó:
  `lesson_player.dart`). Best-effort, naplózott, offline teljes
  értékű helyi paradigmával.
- Paradigma-registry: `lib/models/validated_tasks.dart` — 9 validált
  eljárás, determinisztikus magozott helyi generátor, a Spark csak
  inger-réseket tölt (`paradigmPrompt`), a parse szerkezetet ellenőriz.
  Minden feladat viszi a paradigma-idt és a forrást (`MetaTask.paradigm`
  / `source`). Térkép: `docs/RESEARCH.md` 8. fejezet.
- Térbeli/vizuális helyi feladatok: `lib/models/palace_drill.dart`
  (loci-séta ismerős útvonalon, képi felidézés jelenet-bankkal),
  a lejátszó rendezett állomás-sétát és jelenet-részleteket rajzol,
  mindkettő idézett technika-sorral. Tesztek: `palace_drill_test.dart`
  + `validated_tasks_test.dart` (193 teszt zöld).

- 10-31: őszinte modelljelzés + transfer-kártyák. Minden gyakorló-inger
  rekordban tér vissza (inger + live-jelölés); a játéksáv csak az AKTUÁLIS
  körben ténylegesen dolgozó modelleket nevezi meg (AI LIVE vs HELYI).
  A négyzetes játék végre pontos darabszámú Spark-leosztást kap a valódi
  rácsméretre (`generatePatternCells`); a térbeli kör minden szinten
  pontos állomásszámot kap; a képes körök Spark-ingerrel indulnak, mint
  a leckék. Mind a 6 eredményképernyőn statikus transfer-kártya:
  stratégia + forráseljárás + egy valódi életbeli cél + egy saját anyagra
  épülő mai mini-küldetés (claims-tesztelt). Tesztek:
  `test/pattern_cells_test.dart` (13 teszt), claims-bővítés.

- 11-01: Meta drótjavítás a Beállítások hibanaplója alapján (végig
  ellenőrizve a https://dev.meta.ai/docs oldalain): Wonder
  `wonder-1.0` → `muse-wonder-1.0` (a régi 404-et adott); SAM-kérés
  rövid fogalomra + `type: message` cserélve, válaszértelmezés a
  dokumentált `<0f>…<|box;…|><|mask;…|>` nyelvtanra írva (a SAM
  geometriát ad, nevet soha — a címkék Spark VLM földelt
  képolvasásból jönnek: `spotImageLabels`); nulla találat és csend
  érvényes üres válasz, nem hiba; átírás `POST /asr/transcribe`
  multipart WAV-ra írva (`muse-voice-transcribe-1.0`, válaszban
  `transcript`), a felvétel AAC → WAV; Glimmer és Spark Open
  helyi-only (nincs Meta API-végpontjuk, az élő hívásuk mindig
  404 lenne); kép/SAM/átírás is kap egyszeri újrapróbálást
  átmeneti hálóhibára (`_resilientSend`). Tesztek:
  `test/meta_wire_fix_test.dart` (10 regressziós teszt) +
  a SAM/átírás-csoportok átírása az új szerződésre.
- 11-01 (este): a hangos válasz kikerült — a szójáték most
  koppintós (SEEN / NEW gombok), a Voice Transcribe-hívás, a
  `transcribe`-metódusok, a hangszövegek, a `record`/`cross_file`/
  `http_parser` függőségek és a mikrofonengedélyek (Android, iOS,
  macOS) törölve. Marad 4 hosted modell: Spark, Image, SAM 3.1,
  Wonder. A fenti drótjavítás-történet változatlanul igaz az
  eltávolítás előtti állapotra.
