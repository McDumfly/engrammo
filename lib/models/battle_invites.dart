import 'package:flutter/foundation.dart';

/// A friend you can invite to a battle.
///
/// Shared by the leaderboard "Friends" tab, the friend profile page and
/// the Battle Zone friend search, so all three see the same people.
class BattleFriend {
  final String name;
  final int xp;
  final int streak;
  final bool online;
  const BattleFriend({
    required this.name,
    required this.xp,
    required this.streak,
    this.online = false,
  });
}

/// Friss fióknál üres: a barátlista a backendre (Firestore) kerül,
/// mock nevek nélkül. Amíg nincs backend, a kereső üres állapotot mutat.
const battleFriends = <BattleFriend>[];

/// Case-insensitive substring search on friend names.
/// Empty/blank query returns the full list in order.
List<BattleFriend> filterBattleFriends(
  String query, [
  List<BattleFriend> source = battleFriends,
]) {
  final q = query.trim().toLowerCase();
  if (q.isEmpty) return List<BattleFriend>.unmodifiable(source);
  return [
    for (final f in source)
      if (f.name.toLowerCase().contains(q)) f,
  ];
}

/// In-memory outgoing battle invites, keyed by friend name.
///
/// One shared instance ([battleInvites]) keeps the Battle Zone list and
/// every friend profile page in sync.
class BattleInviteStore extends ChangeNotifier {
  final Set<String> _invited = {};

  bool isInvited(String name) => _invited.contains(name);

  List<String> get invitedNames => List<String>.unmodifiable(_invited);

  int get inviteCount => _invited.length;

  /// Returns true when this call actually added a new invite.
  bool invite(String name) {
    final added = _invited.add(name);
    if (added) notifyListeners();
    return added;
  }

  /// Returns true when a pending invite was removed.
  bool withdraw(String name) {
    final removed = _invited.remove(name);
    if (removed) notifyListeners();
    return removed;
  }

  void clear() {
    if (_invited.isEmpty) return;
    _invited.clear();
    notifyListeners();
  }
}

final battleInvites = BattleInviteStore();
