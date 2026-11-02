# Firebase beüzemelés (Engrammo)

Az app **konfig nélkül is elindul**: ilyenkor offline módban megy, a
belépőképernyő helyett egyből az app nyílik, minden adat a készüléken
marad. Amint megvan a projekt-konfig, a belépés (Google + email) és a
felhő-szinkron automatikusan él.

## 1. Location: EU-t válassz, ne USA-t

- **Te az EU-ban vagy, a felhasználóid is várhatóan itt lesznek** —
  az EU-s régió kisebb késleltetést ad.
- **GDPR**: EU-s régióval az adatok az EU-ban maradnak, ez a
  legegyszerűbb megfelelés.
- A hackathon helyszíne (USA) nem számít: az számíthat, hogy
  **honnan használják** az appot.
- A Firestore-location **később nem változtatható**, most döntsd el.

Ajánlott: **`eur3` (europe-west)** — EU-s multi-régió. Ha a konzol
csak zónát enged, válaszd a **`europe-west1` (Belgium)** vagy
**`europe-west3` (Frankfurt)** zónát.

## 2. Projekt létrehozása a konzolon

1. Nyisd meg: <https://console.firebase.google.com>
2. **Add project** → név: pl. `engrammo` → Google Analytics mehet,
   de nem kötelező.
3. **Build → Authentication → Sign-in method**:
   - **Google** → Enable.
   - **Email/Password** → Enable (az "Email link" nem kell).
   - **Anonymous** → Enable. Ez kell ahhoz, hogy a "Continue without
     account" névtelen Firebase-munkamenetet kapjon (azonnali uid +
     felhő-szinkron). Ha kikapcsolva marad, az app csendben helyi
     vendégmódba esik vissza — nem omlik össze, csak nincs szinkron.
4. **Build → Firestore Database → Create database**:
   - **Production mode**-ban indítsd.
   - Location: lásd fent (**eur3** / europe-west1).
5. Tedd be a repo gyökerében lévő `firestore.rules` tartalmát
   (**Rules** fül vagy `firebase deploy --only firestore:rules`) —
   mindenki csak a saját `users/{uid}` dokumentumát írhatja/olvashatja,
   a `usernames/{név}` foglalásokat pedig minden belépett felhasználó
   olvashatja (foglaltság-ellenőrzés), de írni/törölni csak a sajátját
   írhatja/törölheti:

```
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    match /users/{userId} {
      allow read, write: if request.auth != null
        && request.auth.uid == userId;
    }
    match /usernames/{name} {
      allow read: if request.auth != null;
      allow create: if request.auth != null
        && request.resource.data.uid == request.auth.uid;
      allow update: if request.auth != null
        && resource.data.uid == request.auth.uid
        && request.resource.data.uid == request.auth.uid;
      allow delete: if request.auth != null
        && resource.data.uid == request.auth.uid;
    }
  }
}
```

## 3. App összekötése (`flutterfire configure`)

```bash
dart pub global activate flutterfire_cli
flutterfire configure --project=engrammo-app
```

Ez legenerálja a `lib/firebase_options.dart`-ot, és beköti az
Android/iOS/Web natív fájlokat. Nálad ez már lefutott, ezért
kézzel már semmit nem kell letöltened. Ezután:

```bash
flutter pub get
flutter run
```

Google-belépéshez Androidon kellhet még az **SHA-1 ujjlenyomat**
(Play Console / release aláíráshoz is ismételd meg):

```bash
cd android && ./gradlew signingReport
```

→ a kapott SHA-1-et másold be a konzolon a
**Project settings → Android app** alá.

## 4. Mit szinkronizál az app?

Bejelentkezve a `users/{uid}` dokumentumba kerül (merge-írással):

- pontszámok (`scores`), battle-Elo, battle-mód
- széria + legjobb széria + engram-egyenleg + naptár-előzmény
- avatar-beállítások, megjelenő név, @név, email
- sötét mód + haptika kapcsolók

Minden írás best-effort: net vagy backend nélkül az app a helyi
mentéssel megy tovább, és a következő írásnál/olvasásnál utoléri
magát. Belépéskor a felhő **lehúzódik** a készülékre; új fióknál a
nullás helyi állapot töltődik fel kiindulásnak.

Fiókműveletek a **Settings → Account** alatt: email-csere
(megerősítő levéllel), jelszócsere, kijelentkezés, fióktörlés.

## 5. Kell-e a `google-services.json` és a `GoogleService-Info.plist`?

Igen, mindkettő kell, de más platformhoz:

- **Android** → `android/app/google-services.json`
- **iOS / macOS** → `ios/Runner/GoogleService-Info.plist`,
  `macos/Runner/GoogleService-Info.plist`
- **Web / Windows** → nincs külön fájl, a
  `lib/firebase_options.dart` hordozza a konfigot.

Jó hír: a `flutterfire configure` nálad **mindet legenerálta már**,
a fájlok a helyükön vannak, külön letöltés nem kell. Ha a konzolon
újra letöltöd őket, ugyanide másold vissza.

## 6. Git és a Firebase-fájlok

Ezek a fájlok API-kulcsokat tartalmaznak, ezért a `.gitignore`
kizárja őket a gitből:

- `android/app/google-services.json`
- `ios/Runner/GoogleService-Info.plist`
- `macos/Runner/GoogleService-Info.plist`
- `lib/firebase_options.dart`, `firebase.json`

A helyi példányaid megmaradnak, az app nálad változatlanul fut.
Új gépen / klónozás után futtasd újra a
`flutterfire configure --project=engrammo-app` parancsot —
az mindent újragenerál.
