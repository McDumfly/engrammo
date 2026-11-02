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

  test('a lada elso nyitasra keves engramot ad, masodszorra semmit', () async {
    final chestId = MemoryStore.chestIdForChapter(3);

    final first = await MemoryStore.claimChest(chestId);
    expect(first, MemoryStore.chestEngramReward);
    expect(MemoryStore.chestEngramReward, lessThanOrEqualTo(10));
    expect((await MemoryStore.loadStreakState()).engrams, first);
    expect(await MemoryStore.loadClaimedChests(), {chestId});

    final second = await MemoryStore.claimChest(chestId);
    expect(second, 0);
    expect((await MemoryStore.loadStreakState()).engrams, first);
  });

  test('kulon fejezetek ladai fuggetlenek', () async {
    final a = MemoryStore.chestIdForChapter(0);
    final b = MemoryStore.chestIdForChapter(1);
    expect(a, isNot(b));

    await MemoryStore.claimChest(a);
    expect(await MemoryStore.loadClaimedChests(), {a});
    expect(await MemoryStore.claimChest(b), MemoryStore.chestEngramReward);
    expect((await MemoryStore.loadStreakState()).engrams,
        2 * MemoryStore.chestEngramReward);
  });
}
