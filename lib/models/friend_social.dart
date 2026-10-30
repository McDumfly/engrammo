/// One added bot friend.
class FriendEdge {
  final String botId;
  final DateTime addedAt;
  final bool favorite;

  const FriendEdge({
    required this.botId,
    required this.addedAt,
    this.favorite = false,
  });

  Map<String, dynamic> toJson() => {
    'botId': botId,
    'addedAt': addedAt.toIso8601String(),
    'favorite': favorite,
  };

  factory FriendEdge.fromJson(Map<String, dynamic> json) {
    final at = DateTime.tryParse(json['addedAt'] as String? ?? '');
    return FriendEdge(
      botId: (json['botId'] as String?) ?? '',
      addedAt: at ?? DateTime.fromMillisecondsSinceEpoch(0),
      favorite: (json['favorite'] as bool?) ?? false,
    );
  }
}

/// Friend activity feed event kinds.
enum FeedKind { levelUp, streak, battle, promotion, welcome }

FeedKind feedKindFromName(String name) {
  for (final kind in FeedKind.values) {
    if (kind.name == name) return kind;
  }
  return FeedKind.battle;
}

/// One row in the friends activity feed.
class FeedEvent {
  final String id;
  final DateTime at;
  final String? botId;
  final String? botName;
  final FeedKind kind;
  final String text;
  final int xpDelta;

  const FeedEvent({
    required this.id,
    required this.at,
    this.botId,
    this.botName,
    required this.kind,
    required this.text,
    this.xpDelta = 0,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'at': at.toIso8601String(),
    'botId': botId,
    'botName': botName,
    'kind': kind.name,
    'text': text,
    'xpDelta': xpDelta,
  };

  factory FeedEvent.fromJson(Map<String, dynamic> json) {
    final at = DateTime.tryParse(json['at'] as String? ?? '');
    return FeedEvent(
      id: (json['id'] as String?) ?? '',
      at: at ?? DateTime.fromMillisecondsSinceEpoch(0),
      botId: json['botId'] as String?,
      botName: json['botName'] as String?,
      kind: feedKindFromName((json['kind'] as String?) ?? 'battle'),
      text: (json['text'] as String?) ?? '',
      xpDelta: (json['xpDelta'] as num?)?.toInt() ?? 0,
    );
  }
}
