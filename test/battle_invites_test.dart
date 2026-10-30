import 'package:engrammo/models/battle_invites.dart';
import 'package:engrammo/services/memory_store.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _sample = [
  BattleFriend(name: 'Nóra', xp: 2380, streak: 17, online: true),
  BattleFriend(name: 'Marci', xp: 2710, streak: 14, online: true),
  BattleFriend(name: 'Léna', xp: 2655, streak: 30),
];

void main() {
  group('filterBattleFriends', () {
    test('fresh account starts with no friends', () {
      expect(battleFriends, isEmpty);
      expect(filterBattleFriends('   '), isEmpty);
    });

    test('blank query returns everyone in order', () {
      final all = filterBattleFriends('   ', _sample);
      expect(all.map((f) => f.name).toList(), ['Nóra', 'Marci', 'Léna']);
    });

    test('matches case-insensitively on substrings', () {
      expect(
        filterBattleFriends('nÓ', _sample).map((f) => f.name),
        contains('Nóra'),
      );
      expect(
        filterBattleFriends('mar', _sample).map((f) => f.name),
        contains('Marci'),
      );
    });

    test('unknown name returns empty', () {
      expect(filterBattleFriends('zzz-no-such-friend', _sample), isEmpty);
    });
  });

  group('BattleInviteStore', () {
    test('invite is idempotent, withdraw removes', () {
      final store = BattleInviteStore();
      expect(store.invite('Nóra'), isTrue);
      expect(store.invite('Nóra'), isFalse);
      expect(store.isInvited('Nóra'), isTrue);
      expect(store.inviteCount, 1);

      expect(store.withdraw('Nóra'), isTrue);
      expect(store.withdraw('Nóra'), isFalse);
      expect(store.isInvited('Nóra'), isFalse);
    });

    test('clear empties pending invites', () {
      final store = BattleInviteStore();
      store.invite('Nóra');
      store.invite('Marci');
      store.clear();
      expect(store.invitedNames, isEmpty);
    });
  });

  group('BattleInviteStore persistence', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
      battleInvites.resetForTest();
    });

    tearDown(() {
      battleInvites.resetForTest();
    });

    Future<void> settle() =>
        Future<void>.delayed(const Duration(milliseconds: 20));

    test('invites survive a reload', () async {
      final first = BattleInviteStore();
      first.invite('Nóra');
      await settle();

      final second = BattleInviteStore();
      await second.ensureLoaded();
      expect(second.isInvited('Nóra'), isTrue);
      expect(second.inviteCount, 1);
    });

    test('withdraw persists the removal', () async {
      await MemoryStore.saveBattleInvites({'Nóra', 'Marci'});
      final store = BattleInviteStore();
      await store.ensureLoaded();
      expect(store.inviteCount, 2);

      store.withdraw('Nóra');
      await settle();
      expect(await MemoryStore.loadBattleInvites(), {'Marci'});
    });

    test('refresh picks up cloud-pulled invites', () async {
      await battleInvites.ensureLoaded();
      expect(battleInvites.inviteCount, 0);

      await MemoryStore.saveBattleInvitesWithoutNotify({'Léna'});
      await battleInvites.refresh();
      expect(battleInvites.isInvited('Léna'), isTrue);
    });
  });
}
