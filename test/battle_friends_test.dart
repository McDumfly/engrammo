import 'package:engrammo/screens/battle_zone.dart';
import 'package:engrammo/services/bot_arena_store.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    botArena.resetForTest();
    SharedPreferences.setMockInitialValues({});
    await botArena.ensureLoaded(now: DateTime(2026, 10, 28, 19));
  });

  tearDown(() {
    botArena.resetForTest();
  });

  testWidgets('battle screen lists only added friends', (
    WidgetTester tester,
  ) async {
    final friend = botArena.roster.first;
    final stranger = botArena.roster[1];
    await botArena.addFriend(friend.id);

    await tester.pumpWidget(const MaterialApp(home: BattleZonePage()));
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(find.text(friend.name), 300);
    expect(find.text(friend.name), findsOneWidget);
    expect(find.text(stranger.name), findsNothing);
  });

  testWidgets('claimed rewards leave the friends directory intact', (
    WidgetTester tester,
  ) async {
    final friend = botArena.roster.first;
    await botArena.addFriend(friend.id);
    await botArena.claimDailyWinBonus(100, now: DateTime(2026, 10, 28, 20));
    await botArena.applySeasonRewards(
      seasonId: '2026-10-26',
      playerRank: 2,
      oldTierIndex: 0,
      newTierIndex: 1,
      now: DateTime(2026, 11, 2, 9),
    );
    expect(botArena.rewards.totalBonusXp, 300);

    await tester.pumpWidget(const MaterialApp(home: BattleZonePage()));
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(find.text(friend.name), 300);
    expect(find.text(friend.name), findsOneWidget);
  });

  testWidgets('battle screen without friends points to the friends tab', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: BattleZonePage()));
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(find.text('Battle with friends'), 300);
    expect(find.textContaining('No friends yet'), findsOneWidget);
    expect(find.text('FIND FRIENDS'), findsOneWidget);

    await tester.ensureVisible(find.text('FIND FRIENDS'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('FIND FRIENDS'));
    await tester.pumpAndSettle();
    expect(find.text('Suggested players'), findsOneWidget);
  });
}
