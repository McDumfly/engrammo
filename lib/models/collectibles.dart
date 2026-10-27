import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';

import '../theme/app_colors.dart' show amber;

/// The single collectible currency of the app.
///
/// There is exactly one collectible payment method: the [engram].
/// A stored memory trace, earned for correct answers and spent on
/// chests and rewards.
class CollectibleKind {
  final String id;
  final String name;
  final String tagline;
  final List<List<dynamic>> icon;
  final Color color;
  const CollectibleKind({
    required this.id,
    required this.name,
    required this.tagline,
    required this.icon,
    required this.color,
  });
}

const engram = CollectibleKind(
  id: 'engram',
  name: 'Engram',
  tagline: 'A stored memory trace',
  icon: HugeIcons.strokeRoundedBrainCircuit,
  color: amber,
);

const collectibles = <CollectibleKind>[engram];

CollectibleKind collectibleById(String id) {
  for (final c in collectibles) {
    if (c.id == id) return c;
  }
  return engram;
}
