import 'package:engrammo/l10n/strings_en.dart';
import 'package:engrammo/l10n/strings_hu.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('minden angol kulcsnak van magyar fordítása', () {
    final missing = enStrings.keys.where((k) => !huStrings.containsKey(k));
    expect(missing, isEmpty, reason: missing.join(', '));
  });

  test('minden magyar kulcsnak van angol eredetije', () {
    final extra = huStrings.keys.where((k) => !enStrings.containsKey(k));
    expect(extra, isEmpty, reason: extra.join(', '));
  });

  test('az interpolációs helyőrzők egyeznek', () {
    final bad = <String>[];
    final pattern = RegExp(r'\{[a-z_]+\}');
    for (final key in enStrings.keys) {
      final en = pattern
          .allMatches(enStrings[key]!)
          .map((m) => m.group(0))
          .toSet();
      final hu = pattern
          .allMatches(huStrings[key] ?? '')
          .map((m) => m.group(0))
          .toSet();
      if (en.length != hu.length || !en.containsAll(hu)) {
        bad.add('$key: EN=$en HU=$hu');
      }
    }
    expect(bad, isEmpty, reason: bad.join('\n'));
  });
}
