import 'dart:convert';

import 'package:engrammo/l10n/app_localizations.dart';
import 'package:engrammo/models/fsrs_card.dart';
import 'package:engrammo/models/room_palace.dart';
import 'package:engrammo/screens/lesson_player.dart';
import 'package:engrammo/services/active_palace_store.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The spatial lesson walks the learner's own room: the coach card names
/// the palace, and the drill stimulus shows its real station names.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<void> seedOwnPalace() async {
    final room = RoomPalace(
      id: 'room:7',
      createdAt: DateTime.utc(2026, 11, 1, 12),
      imageRef: 'data:image/jpeg;base64,AAA',
      stations: const ['wardrobe', 'kettle', 'cushion', 'lantern'],
      items: const ['apple', 'hammer', 'key', 'rose'],
      links: const ['l1', 'l2', 'l3', 'l4'],
      live: true,
      card: FsrsCard(
        cardId: 'room:7',
        taskId: 'room_palace',
        due: DateTime.utc(2026),
      ),
    );
    SharedPreferences.setMockInitialValues({
      'room_palaces_v1': [jsonEncode(room.toJson())],
      'active_palace_id_v1': 'room:7',
    });
    ActivePalaceStore.last = null;
    AppLocalizations.useCode(AppLocalizations.englishCode);
  }

  testWidgets('spatial lesson shows the palace title and stations', (
    tester,
  ) async {
    await seedOwnPalace();
    // Tall surface: the coach button stays visible without scrolling, so
    // the drill opens at offset 0 (both lists share the primary scroller).
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      const MaterialApp(
        home: LessonPlayerPage(
          chapterIndex: 2,
          sectionIndex: 0,
          lessonIndex: 0,
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Coach card names the active palace.
    expect(find.textContaining('Your room palace'), findsWidgets);

    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('lesson-coach-next')),
      300,
    );
    await tester.tap(find.byKey(const ValueKey('lesson-coach-next')));
    await tester.pumpAndSettle();

    // Drill stimulus: the prompt, the palace chip and the room's stations.
    expect(
      find.text('Walk your room palace — one vivid image per station!'),
      findsOneWidget,
    );
    expect(find.text('4 stations'), findsOneWidget);
    expect(find.text('wardrobe'), findsOneWidget);
    expect(find.text('kettle'), findsOneWidget);
  });
}
