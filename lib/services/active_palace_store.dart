import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/active_palace.dart';
import '../models/room_palace.dart';

/// Which palace lessons walk. Device-only: the photos never leave the
/// device, so this never notifies CloudSync. Same try/catch style as
/// MemoryStore: storage failures resolve to null, never throw.
class ActivePalaceStore {
  static const prefKey = 'active_palace_id_v1';

  /// Last resolved palace in this session, or null when unknown.
  static ActivePalace? last;

  /// Resolves in order: the saved id (a route, or a still-existing room
  /// palace with 3+ stations), else the newest usable room palace
  /// (preferring a non-sample), else null.
  static Future<ActivePalace?> load([String locale = 'en']) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getString(prefKey);
      if (saved != null) {
        if (last != null && last!.id == saved && last!.routeIndex != null) {
          return last;
        }
        final hit = await _resolveId(saved, locale);
        if (hit != null) {
          last = hit;
          return hit;
        }
      }
      final palaces = await _loadPalaces();
      final usable = palaces.where((p) => p.stations.length >= 3).toList();
      if (usable.isEmpty) {
        last = null;
        return null;
      }
      final pick = usable.firstWhere(
        (p) => !p.sample,
        orElse: () => usable.first,
      );
      final palace = ActivePalace.fromRoom(pick, locale);
      last = palace;
      return palace;
    } catch (_) {
      return null;
    }
  }

  /// The saved palace id without resolving it.
  static Future<String?> loadId() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString(prefKey);
    } catch (_) {
      return null;
    }
  }

  static Future<void> setId(String id) async {
    last = null;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(prefKey, id);
    } catch (_) {}
  }

  static Future<void> clear() async {
    last = null;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(prefKey);
    } catch (_) {}
  }

  static Future<ActivePalace?> _resolveId(String id, String locale) async {
    if (id.startsWith('route:')) {
      final i = int.tryParse(id.substring('route:'.length));
      if (i == null || i < 0 || i > 2) return null;
      return ActivePalace.fromRoute(i, locale);
    }
    if (!id.startsWith('room:')) return null;
    final palaces = await _loadPalaces();
    for (final p in palaces) {
      if (p.id == id && p.stations.length >= 3) {
        return ActivePalace.fromRoom(p, locale);
      }
    }
    return null;
  }

  /// Newest first, mirroring MemoryStore.loadRoomPalaces without the
  /// import cycle (memory_store owns the write path and the cap).
  static Future<List<RoomPalace>> _loadPalaces() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getStringList('room_palaces_v1');
      if (raw == null || raw.isEmpty) return [];
      final out = <RoomPalace>[];
      for (final e in raw) {
        try {
          final parsed = jsonDecode(e);
          if (parsed is Map<String, dynamic>) {
            out.add(RoomPalace.fromJson(parsed));
          }
        } catch (_) {
          // Skip corrupt entries.
        }
      }
      return out;
    } catch (_) {
      return [];
    }
  }
}
