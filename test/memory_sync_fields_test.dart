import 'package:engrammo/models/user_goals.dart';
import 'package:engrammo/services/memory_store.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    MemoryStore.clearMemoryCache();
    MemoryStore.onChanged = null;
  });

  tearDown(() {
    MemoryStore.onChanged = null;
  });

  test('goals save triggers sync, silent variant skips it', () async {
    var notified = false;
    MemoryStore.onChanged = () async {
      notified = true;
    };
    final goal = UserGoal.fresh(title: 'Remember names');

    await MemoryStore.saveUserGoalsWithoutNotify([goal]);
    expect(notified, isFalse);
    expect((await MemoryStore.loadUserGoals()).map((g) => g.id), [goal.id]);

    await MemoryStore.saveUserGoals([goal]);
    await Future<void>.delayed(const Duration(milliseconds: 20));
    expect(notified, isTrue);
  });

  test('own materials round-trip through bulk helpers', () async {
    await MemoryStore.saveOwnMaterial('t1', 'my palace route');
    expect(await MemoryStore.loadOwnMaterial('t1'), 'my palace route');
    expect(await MemoryStore.loadAllOwnMaterials(), {
      't1': 'my palace route',
    });

    await MemoryStore.saveAllOwnMaterialsWithoutNotify({
      't1': 'new text',
      't2': 'second',
      '': 'skipped',
    });
    expect(await MemoryStore.loadAllOwnMaterials(), {
      't1': 'new text',
      't2': 'second',
    });
  });

  test('missions bulk save merges into a sorted set', () async {
    await MemoryStore.saveMissionDone('m2');
    await MemoryStore.saveDoneMissionsWithoutNotify({'m1', 'm2'});
    expect(await MemoryStore.loadDoneMissions(), {'m1', 'm2'});
  });

  test('benchmark state round-trips with lenient decode', () async {
    await MemoryStore.saveBenchmark(
      const BenchmarkState(
        best: {'sequence': 8},
        attempts: {
          'sequence': [6, 8],
        },
        xp: 30,
        plays: 3,
        bonusClaimed: true,
      ),
    );
    final loaded = await MemoryStore.loadBenchmark();
    expect(loaded.best, {'sequence': 8});
    expect(loaded.attempts, {
      'sequence': [6, 8],
    });
    expect(loaded.xp, 30);
    expect(loaded.plays, 3);
    expect(loaded.bonusClaimed, isTrue);

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('benchmark_state_v1', '[]');
    final fallback = await MemoryStore.loadBenchmark();
    expect(fallback.best, isEmpty);
    expect(fallback.plays, 0);
  });

  test('invites round-trip and drop empty names', () async {
    await MemoryStore.saveBattleInvites({'Nóra', '', 'Marci'});
    expect(await MemoryStore.loadBattleInvites(), {'Nóra', 'Marci'});
  });

  test('clearAccountData removes the newly synced keys', () async {
    await MemoryStore.saveBenchmark(const BenchmarkState(xp: 10, plays: 1));
    await MemoryStore.saveBattleInvites({'Nóra'});
    await MemoryStore.saveUserGoals([UserGoal.fresh(title: 'x')]);

    await MemoryStore.clearAccountData();

    expect((await MemoryStore.loadBenchmark()).plays, 0);
    expect(await MemoryStore.loadBattleInvites(), isEmpty);
    expect(await MemoryStore.loadUserGoals(), isEmpty);
  });
}
