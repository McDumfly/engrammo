library;

import '../l10n/app_localizations.dart' show trFor;
import 'palace_drill.dart' show palaceRoutesFor;
import 'room_palace.dart' show RoomPalace, palaceHumanDate;

/// The palace lessons walk: the learner's real room when they built one,
/// otherwise a named practice route. Honest by construction — the title
/// always names the actual stations shown.
class ActivePalace {
  final String id; // 'room:<ms>' or 'route:<0..2>'
  final String title;
  final List<String> stations;
  final String imageRef; // '' for practice routes
  final List<List<double>> boxes;
  final List<String> masks;
  final bool own; // a RoomPalace the learner built
  final bool sample; // RoomPalace.sample

  const ActivePalace({
    required this.id,
    required this.title,
    required this.stations,
    required this.imageRef,
    required this.boxes,
    required this.masks,
    required this.own,
    required this.sample,
  });

  /// Practice-route index for 'route:<i>' ids, null for real rooms.
  int? get routeIndex {
    if (!id.startsWith('route:')) return null;
    final i = int.tryParse(id.substring('route:'.length));
    if (i == null || i < 0 || i > 2) return null;
    return i;
  }

  factory ActivePalace.fromRoom(
    RoomPalace p, [
    String locale = 'en',
    int ownCount = 1,
  ]) {
    final String title;
    if (p.sample) {
      title = trFor(locale, 'palace_sample_title');
    } else if (ownCount > 1) {
      title = trFor(locale, 'palace_own_title_dated', {
        'date': palaceHumanDate(p.createdAt, locale),
      });
    } else {
      title = trFor(locale, 'palace_own_title');
    }
    return ActivePalace(
      id: p.id,
      title: title,
      stations: List<String>.of(p.stations),
      imageRef: p.imageRef,
      boxes: p.boxes.length == p.stations.length
          ? [for (final b in p.boxes) List<double>.of(b)]
          : const [],
      masks: p.masks.length == p.stations.length
          ? List<String>.of(p.masks)
          : const [],
      own: true,
      sample: p.sample,
    );
  }

  factory ActivePalace.fromRoute(int index, [String locale = 'en']) {
    final i = index.clamp(0, 2);
    final routes = palaceRoutesFor(locale).values.toList();
    return ActivePalace(
      id: 'route:$i',
      title: trFor(locale, 'palace_route_$i'),
      stations: List<String>.of(routes[i]),
      imageRef: '',
      boxes: const [],
      masks: const [],
      own: false,
      sample: false,
    );
  }
}
