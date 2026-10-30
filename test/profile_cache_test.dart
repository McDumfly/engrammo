import 'package:engrammo/screens/kreeds_profile.dart';
import 'package:engrammo/services/memory_store.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    MemoryStore.clearMemoryCache();
  });

  test('MemoryStore a profil-adatokat munkamenetben cacheli', () async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    SharedPreferences.setMockInitialValues({
      'profile_display_name_v1': 'Cache Elek',
      'profile_username_v1': 'cache_elek',
      'memory_scores_v1': ['10', '20', '90', '30', '40', '50'],
      'dominant_kind_v1': 2,
      'streak_history_v1': [today.toIso8601String()],
      'streak_v1': 5,
      'best_streak_v1': 7,
      'engrams_v1': 120,
      'battle_rating_v1': 1234,
      'battle_xp_v1': 777,
    });

    expect(MemoryStore.lastProfile, isNull);
    expect(MemoryStore.lastScores, isNull);
    expect(MemoryStore.lastStreakState, isNull);
    expect(MemoryStore.lastBattleRating, isNull);
    expect(MemoryStore.lastBattleXp, isNull);

    final profile = await MemoryStore.loadProfile();
    expect(profile.displayName, 'Cache Elek');
    expect(profile.username, 'cache_elek');
    expect(MemoryStore.lastProfile?.displayName, 'Cache Elek');
    expect(MemoryStore.lastProfile?.username, 'cache_elek');

    final scores = await MemoryStore.loadScores();
    expect(scores, [10, 20, 90, 30, 40, 50]);
    expect(MemoryStore.lastScores, [10, 20, 90, 30, 40, 50]);

    expect(await MemoryStore.loadDominantKind(), 2);
    expect(MemoryStore.lastDominantKind, 2);

    final streak = await MemoryStore.loadStreakState();
    expect(streak.streak, 5);
    expect(streak.engrams, 120);
    expect(MemoryStore.lastStreakState?.streak, 5);
    expect(MemoryStore.lastStreakState?.engrams, 120);

    expect(await MemoryStore.loadBattleRating(), 1234);
    expect(MemoryStore.lastBattleRating, 1234);
    expect(await MemoryStore.loadBattleXp(), 777);
    expect(MemoryStore.lastBattleXp, 777);

    await MemoryStore.saveProfile(
      displayName: 'Mentett Nev',
      username: 'mentett_nev',
      email: '',
    );
    expect(MemoryStore.lastProfile?.displayName, 'Mentett Nev');

    await MemoryStore.saveScores([1, 2, 3, 4, 5, 6]);
    expect(MemoryStore.lastScores, [1, 2, 3, 4, 5, 6]);

    await MemoryStore.clearAccountData();
    expect(MemoryStore.lastProfile, isNull);
    expect(MemoryStore.lastScores, isNull);
    expect(MemoryStore.lastDominantKind, isNull);
    expect(MemoryStore.lastStreakState, isNull);
    expect(MemoryStore.lastBattleRating, isNull);
    expect(MemoryStore.lastBattleXp, isNull);
  });

  testWidgets('profilba visszalepve a cachelt adatok azonnal latszanak', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({
      'profile_display_name_v1': 'Cache Elek',
      'profile_username_v1': 'cache_elek',
      'memory_scores_v1': ['10', '20', '90', '30', '40', '50'],
      'dominant_kind_v1': 2,
    });
    await tester.pumpWidget(const MaterialApp(home: KreedsProfilePage()));
    await tester.pumpAndSettle();
    expect(find.text('Cache Elek'), findsOneWidget);
    expect(find.text('@cache_elek'), findsOneWidget);
    expect(find.text('Spatial'), findsOneWidget);

    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: Text('masik ful'))),
    );
    await tester.pumpAndSettle();
    expect(find.text('masik ful'), findsOneWidget);

    SharedPreferences.setMockInitialValues({
      'profile_display_name_v1': 'Friss Adat',
      'profile_username_v1': 'friss_adat',
      'memory_scores_v1': ['60', '60', '60', '60', '95', '60'],
      'dominant_kind_v1': 4,
    });

    await tester.pumpWidget(const MaterialApp(home: KreedsProfilePage()));
    // Elso kepkocka: meg a cachelt regi adat latszik, nem ures profil.
    expect(find.text('Cache Elek'), findsOneWidget);
    expect(find.text('@cache_elek'), findsOneWidget);
    expect(find.text('Spatial'), findsOneWidget);

    // Hatter-frissites utan az uj adat ervenyesul.
    await tester.pumpAndSettle();
    expect(find.text('Friss Adat'), findsOneWidget);
    expect(find.text('@friss_adat'), findsOneWidget);
    expect(find.text('Episodic'), findsOneWidget);
    expect(find.text('Cache Elek'), findsNothing);
  });
}
