import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  // firestore.rules is gitignored (deploy config), so a fresh clone or CI
  // has no copy; there the checks are skipped instead of failing.
  final rulesSkip = File('firestore.rules').existsSync()
      ? false
      : 'firestore.rules not in this checkout (gitignored)';

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
    skip: rulesSkip,
  );

  test(
    'firestore.rules: usernames-foglaltsag olvashato, irni csak sajatot lehet',
    () async {
      final rules = await File('firestore.rules').readAsString();
      expect(rules, contains('match /usernames/{name}'));
      expect(rules, contains('allow read: if request.auth != null;'));
      expect(rules, contains('request.resource.data.uid == request.auth.uid'));
      expect(rules, contains('resource.data.uid == request.auth.uid'));
    },
    skip: rulesSkip,
  );
}
