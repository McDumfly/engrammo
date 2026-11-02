# Verseny-napló — Engrammo

Meta Global AI Developer Hackathon (Cerebral Valley),
indie solo, **Build for Your World**. Időablak: okt. 27 –
nov. 4. (beadás: nov. 4. 21:00 ET). Minden érdemi munka
ebben az ablakban készült; a `git log` napra pontosan
visszaköveti.

## Okt. 26. (hétfő) — előkészület

- Sima `flutter create` váz (`Initial commit`), érdemi
  kód nélkül. Irány: memóriapalota + térközölt ismétlés,
  nem mechanikus agyjáték.

## Okt. 27. (kedd) — váz + Meta-alap

- Teljes app-váz: képernyők, témák, store-ok, tesztek
  (`UI ready` commit).
- Meta-modellek + FSRS-lite: adatmodellek,
  `MetaAIService` fallbackkal, képernyő-bekötés,
  perzisztencia, tesztek, részletes terv
  (`docs/META_TERV.md`).

## Okt. 28. (szerda) — teljes építés

- Tanterv, leckék, szintmérő, Meta AI élő+fallback,
  auth/szinkron, ikonok/téma, tesztek (`Full app build`).

## Okt. 30. (péntek) — rendszer + nyelvek

- Csatarendszer, célok, HU–EN lokalizáció, biztonságos
  kulcstárolás, tesztek.

## Okt. 31. (szombat) — audit és megfelelés

- Teljes audit: 834 teszt zöld (94 fájl), `flutter analyze`
  tiszta. Javítva: fiók-adatszivárgás kijelentkezéskor,
  felhő-merge szabályok, térköz-kapu (gyenge menet után
  nincs zár), AI-feladat validátor, EN↔HU paritás,
  onboarding-flow, platform-nevek/manifestek.
- Hackathon-megfelelés: Participant Guide végigolvasva
  (súlyozás javítva: 4 egyenlő 0–10-es kritérium),
  `docs/SUBMISSION.md` (demó-forgatókönyv + pontozási
  kereszt-referencia) és e napló megírva, README
  pontosítva (93 tesztfájl, scaffold-állítás, Linux
  Firebase-megjegyzés).
- Saját tananyag kivéve a felhő-szinkronból: a
  kutatási doksi (§12) szerint az eszközön marad.

## Nov. 1. (vasárnap) — beadás-előkészítés

- Kódváltoztatás nélkül: `flutter analyze` tiszta,
  834 teszt zöld (94 fájl). Doksi-számok pontosítva.
- Titok-ellenőrzés: `.env` nincs git alatt, a beadandó
  fájlokban nincs kulcsminta. `integration_test/tour_test.dart`
  (ideiglenes screenshot-körút) nem kerül be a repóba.
- Függő munka commit-terve készen, videó-próba
  checklist a SUBMISSION.md 5. fejezetében.

## Nov. 1–3. — demó-próba (terv)

- Élő kulcsos próba: hívásnapló `fallback: false`,
  majd kulcs nélkül `fallback: true` minden útvonalon.
- 3 perces videó felvétele a SUBMISSION-forgatókönyv
  szerint, repo + videó publikus ellenőrzése.

## Nov. 4. (szerda) — beadás (terv)

- Utolsó `flutter analyze` + `flutter test`, verziócímke,
  beadás a CV-platformon 21:00 ET előtt.
