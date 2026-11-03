import 'package:engrammo/services/memory_store.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('clearAccountData mindent torol, uj fiok nem orokol', () async {
    SharedPreferences.setMockInitialValues({
      'memory_scores_v1': '[10,20]',
      'onboarding_done_v1': true,
      'local_norms_v1': ['0=3,0.5,0.1'],
      'assessment_runs_data_v1': ['0.1,0.2'],
      'streak_history_v1': ['2026-10-01T00:00:00.000'],
      'streak_v1': 10,
      'best_streak_v1': 12,
      'engrams_v1': 200,
      'restore_prompt_day_v1': '2026-10-30',
      'growth_day_v1': ['2026-10-30', '0=5'],
      'goal_plan_done_v1': ['g1=0,2'],
      'ai_help_history_v1_general': '[{"mine":true,"text":"hi"}]',
      'active_palace_id_v1': 'room:1',
      'settings_dark_mode_v1': true,
    });

    await MemoryStore.clearAccountData();

    final prefs = await SharedPreferences.getInstance();
    for (final key in [
      'memory_scores_v1',
      'onboarding_done_v1',
      'local_norms_v1',
      'assessment_runs_data_v1',
      'streak_history_v1',
      'streak_v1',
      'best_streak_v1',
      'engrams_v1',
      'restore_prompt_day_v1',
      'growth_day_v1',
      'goal_plan_done_v1',
      'active_palace_id_v1',
      'ai_help_history_v1_general',
    ]) {
      expect(prefs.containsKey(key), isFalse, reason: key);
    }
    // Eszkoz-szintu beallitasok maradnak.
    expect(prefs.getBool('settings_dark_mode_v1'), isTrue);

    expect(await MemoryStore.loadOnboardingDone(), isFalse);
    expect(await MemoryStore.loadLocalNorms(), isEmpty);
    final streak = await MemoryStore.loadStreakState();
    expect(streak.streak, 0);
    expect(streak.engrams, 0);
    expect(MemoryStore.lastScores, isNull);
  });
}
