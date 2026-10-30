import 'package:flutter/foundation.dart';

import '../services/memory_store.dart';

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

const battleFriends = <BattleFriend>[];

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

class BattleInviteStore extends ChangeNotifier {
  final Set<String> _invited = {};
  Future<void>? _loading;
  Future<void> _persistQueue = Future.value();

  bool isInvited(String name) => _invited.contains(name);

  List<String> get invitedNames => List<String>.unmodifiable(_invited);

  int get inviteCount => _invited.length;

  /// Loads persisted invites once. Never throws.
  Future<void> ensureLoaded() {
    final pending = _loading;
    if (pending != null) return pending;
    final future = refresh();
    _loading = future;
    return future;
  }

  /// Reloads invites from local storage (already refreshed by a cloud pull).
  Future<void> refresh() async {
    try {
      final saved = await MemoryStore.loadBattleInvites();
      _invited
        ..clear()
        ..addAll(saved);
    } catch (_) {
    } finally {
      try {
        notifyListeners();
      } catch (_) {}
    }
  }

  bool invite(String name) {
    final added = _invited.add(name);
    if (added) {
      notifyListeners();
      _persist();
    }
    return added;
  }

  bool withdraw(String name) {
    final removed = _invited.remove(name);
    if (removed) {
      notifyListeners();
      _persist();
    }
    return removed;
  }

  void clear() {
    if (_invited.isEmpty) return;
    _invited.clear();
    notifyListeners();
    _persist();
  }

  void _persist() {
    _persistQueue = _persistQueue.then((_) => _saveNow());
  }

  Future<void> _saveNow() async {
    try {
      await MemoryStore.saveBattleInvites(Set.of(_invited));
    } catch (_) {}
  }

  @visibleForTesting
  void resetForTest() {
    _invited.clear();
    _loading = null;
    _persistQueue = Future.value();
  }
}

final battleInvites = BattleInviteStore();
