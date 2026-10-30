import 'package:engrammo/screens/battle_zone.dart';
import 'package:engrammo/screens/benchmark_stats.dart'
    show BenchmarkDetailPage;
import 'package:engrammo/screens/kreeds_profile.dart';
import 'package:engrammo/services/bot_arena_store.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    botArena.resetForTest();
    SharedPreferences.setMockInitialValues({});
  });

  tearDown(() {
    botArena.resetForTest();
  });

  testWidgets('battle zone shows no fake online count', (tester) async {
    await botArena.ensureLoaded(now: DateTime(2026, 10, 28, 19));
    await tester.pumpWidget(const MaterialApp(home: BattleZonePage()));
    await tester.pumpAndSettle();

    expect(find.text('1,284 online'), findsNothing);
  });

  testWidgets('battle zone shows no fake live viewers', (tester) async {
    await botArena.ensureLoaded(now: DateTime(2026, 10, 28, 19));
    await tester.pumpWidget(const MaterialApp(home: BattleZonePage()));
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(
      find.text('Showcases'),
      500,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    expect(find.text('Live duels'), findsNothing);
  });

  testWidgets('fresh profile shows no tournament title', (tester) async {
    await botArena.ensureLoaded(now: DateTime(2026, 10, 28, 19));
    await tester.pumpWidget(const MaterialApp(home: KreedsProfilePage()));
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(find.text('Badges'), 300);
    await tester.pumpAndSettle();
    expect(find.text('tournament winner'), findsNothing);
  });

  testWidgets('benchmark detail shows no fake community rank', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: BenchmarkDetailPage(
          gameId: 'sequence',
          title: 'Sequence memory',
          subtitle: 'Repeat the flashing sequence!',
          tint: Colors.blue,
          bestLabel: 'rounds',
          higherIsBetter: true,
          best: 6,
          attempts: const [4, 5, 6],
          buildGame: () => const SizedBox(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('Top '), findsNothing);
    expect(find.text('of players'), findsNothing);
  });

  test('day tick adds no bot-authored feed events', () async {
    await botArena.ensureLoaded(now: DateTime(2026, 10, 28, 19));
    botArena.resetForTest();
    await botArena.ensureLoaded(now: DateTime(2026, 10, 29, 19));

    expect(botArena.feed, isNotEmpty);
    expect(botArena.feed.every((e) => e.botId == null), isTrue);
  });
}
