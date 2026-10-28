import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// A felhős belépés őre: a `users/{uid}` dokumentum csak a saját
/// tulajdonosé lehet. Ha ez a fájl/szabály sérül, idegen fiók
/// olvashatná/írhatná más haladását.
void main() {
  test(
    'firestore.rules csak a tulajdonosnak enged a users/{uid}-ban',
    () async {
      final file = File('firestore.rules');
      expect(
        await file.exists(),
        isTrue,
        reason: 'Hiányzik a firestore.rules — deploy nélkül nincs védelem.',
      );
      final rules = await file.readAsString();
      expect(rules, contains('match /users/{userId}'));
      expect(rules, contains('request.auth != null'));
      expect(rules, contains('request.auth.uid == userId'));
    },
  );
}
