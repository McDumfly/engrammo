import 'dart:math';

import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';

import '../l10n/app_localizations.dart';
import '../models/room_palace.dart';
import '../services/active_palace_store.dart';
import '../screens/room_palace_page.dart' show RoomPalacePage;
import '../services/app_feedback.dart';
import '../services/memory_store.dart';
import '../theme/app_colors.dart' show blue, coral, teal;
import '../theme/app_tokens.dart';
import '../utils/test_mode.dart';
import 'ai_image.dart';
import 'app_buttons.dart';
import 'app_kit.dart';

/// The one shared "SAM 3.1 · Muse Spark · Muse Image" caption: model names
/// are proper nouns, used in both the home card and the Practice hub hero.
const kRoomModelsCaption = 'SAM 3.1 · Muse Spark · Muse Image';

/// Dark hero card at the top of the Home tab: Room Palace entry.
/// Also reused as the Practice tab hero (with an explicit [onTap]).
class RoomPalaceHomeCard extends StatefulWidget {
  const RoomPalaceHomeCard({super.key, this.onTap});

  /// When null the card navigates to [RoomPalacePage] itself.
  final VoidCallback? onTap;

  @override
  State<RoomPalaceHomeCard> createState() => _RoomPalaceHomeCardState();
}

class _RoomPalaceHomeCardState extends State<RoomPalaceHomeCard>
    with TickerProviderStateMixin {
  late final AnimationController _enter;
  late final AnimationController _drift;
  late final Animation<double> _fade;
  bool _settled = false;

  /// The latest saved palace, if any. Loaded once; null keeps the
  /// default invite look exactly as before.
  RoomPalace? _mine;

  @override
  void initState() {
    super.initState();
    _loadMine();
    // 400ms with the first 80ms as delay (no Timer: test-safe).
    _enter = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _fade = CurvedAnimation(
      parent: _enter,
      curve: const Interval(0.2, 1, curve: Curves.easeOutCubic),
    );
    // After the entrance the Opacity layer is dropped so the scroll list
    // stays free of Opacity widgets (perf invariant, see home_scroll_perf).
    _enter.addStatusListener((status) {
      if (status == AnimationStatus.completed && mounted) {
        setState(() => _settled = true);
      }
    });
    _enter.forward();
    _drift = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 6),
    );
    // A repeating ticker never lets pumpAndSettle finish, so under
    // `flutter test` the blobs stay at their resting offsets.
    if (!isFlutterTest) _drift.repeat();
  }

  @override
  void dispose() {
    _enter.dispose();
    _drift.dispose();
    super.dispose();
  }

  /// Loads the saved palaces once; the card shows the active palace,
  /// falling back to the latest one.
  Future<void> _loadMine() async {
    final list = await MemoryStore.loadRoomPalaces();
    if (!mounted) return;
    if (list.isEmpty) return;
    final latest = list.reduce(
      (a, b) => a.createdAt.isAfter(b.createdAt) ? a : b,
    );
    RoomPalace pick = latest;
    try {
      final active = await ActivePalaceStore.load(AppLocalizations.localeCode);
      if (!mounted) return;
      if (active != null && active.own) {
        for (final p in list) {
          if (p.id == active.id) pick = p;
        }
      }
    } catch (_) {}
    if (!mounted) return;
    setState(() => _mine = pick);
  }

  /// "today" / "tomorrow" / "in N days" for the palace's due date.
  String _whenText(DateTime due) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final day = DateTime(due.year, due.month, due.day);
    final diff = day.difference(today).inDays;
    if (diff <= 0) return tr('room_home_today');
    if (diff == 1) return tr('room_home_tomorrow');
    return tr('room_home_in_days', {'d': '$diff'});
  }

  /// Card body: the palace list (with "New palace").
  Future<void> _openList() async {
    AppFeedback.light();
    if (widget.onTap != null) {
      widget.onTap!();
      return;
    }
    await Navigator.of(context)
        .push(MaterialPageRoute(builder: (_) => const RoomPalacePage()));
    // The due date may have moved while reviewing: reload the card.
    await _loadMine();
  }

  /// Review pill: straight into this palace's review.
  Future<void> _openReview() async {
    AppFeedback.light();
    if (widget.onTap != null) {
      widget.onTap!();
      return;
    }
    final mine = _mine;
    if (mine == null) {
      await Navigator.of(context)
          .push(MaterialPageRoute(builder: (_) => const RoomPalacePage()));
      await _loadMine();
      return;
    }
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => RoomPalacePage(reviewId: mine.id)),
    );
    await _loadMine();
  }

  @override
  Widget build(BuildContext context) {
    // A saved palace turns the card into its cover: the room photo under
    // a dark gradient. Without one the invite look stays exactly as is.
    final mine = _mine;
    // The entrance wraps the whole card (cached as `child`, so it never
    // rebuilds while fading in); the drift rebuilds ONLY the blob paint.
    return AnimatedBuilder(
      animation: _enter,
      builder: (context, card) {
        if (_settled) return card!;
        return Opacity(
          opacity: _fade.value,
          child: Transform.translate(
            offset: Offset(0, 12 * (1 - _fade.value)),
            child: card,
          ),
        );
      },
      // Grows past 152 pt at large text scales instead of clipping.
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 152),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(AppRadius.l),
          child: Stack(
            children: [
              if (mine == null) ...[
                Positioned.fill(
                  child: Container(
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [Color(0xFF16233B), Color(0xFF0E3B4A)],
                      ),
                    ),
                  ),
                ),
                Positioned.fill(
                  child: AnimatedBuilder(
                    animation: _drift,
                    builder: (context, _) {
                      final t = _drift.value * 2 * pi;
                      final offsets = [
                        Offset(0, 6 * sin(t)),
                        Offset(0, 6 * sin(t + 2.09)),
                        Offset(0, 6 * sin(t + 4.19)),
                      ];
                      return RepaintBoundary(
                        child: CustomPaint(
                          painter: _BlobPainter(offsets: offsets),
                        ),
                      );
                    },
                  ),
                ),
              ] else ...[
                Positioned.fill(
                  child: RepaintBoundary(
                    child: AiImage(imageRef: mine.imageRef, fit: BoxFit.cover),
                  ),
                ),
                Positioned.fill(
                  child: Container(
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [Color(0xCC16233B), Color(0x6616233B)],
                      ),
                    ),
                  ),
                ),
              ],
              Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Tappable(
                      haptic: false,
                      onTap: _openList,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Align(
                            alignment: Alignment.centerLeft,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 5,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.14),
                                borderRadius: BorderRadius.circular(
                                  AppRadius.pill,
                                ),
                              ),
                              child: Text(
                                kRoomModelsCaption,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: AppText.micro.copyWith(
                                  color: Colors.white.withValues(alpha: 0.92),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            tr(
                              mine == null
                                  ? 'room_home_title'
                                  : 'room_home_mine',
                            ),
                            style: AppText.title.copyWith(color: Colors.white),
                          ),
                          const SizedBox(height: 2),
                        ],
                      ),
                    ),
                    Row(
                      children: [
                        Expanded(
                          child: Tappable(
                            haptic: false,
                            onTap: _openList,
                            child: Text(
                              mine == null
                                  ? tr('room_home_sub')
                                  : tr('room_home_due', {
                                      'n': '${mine.items.length}',
                                      'when': _whenText(mine.card.due),
                                    }),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: AppText.caption.copyWith(
                                color: Colors.white.withValues(alpha: 0.8),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        EngramPress3D(
                          haptic: false,
                          onTap: _openReview,
                          shadowColor: const Color(0xFFB9C6DA),
                          borderRadius: BorderRadius.circular(AppRadius.pill),
                          top: Container(
                            height: 40,
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(
                                AppRadius.pill,
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const HugeIcon(
                                  icon: HugeIcons.strokeRoundedCamera01,
                                  color: Color(0xFF16233B),
                                  size: 18,
                                  strokeWidth: 2.0,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  tr(
                                    mine == null
                                        ? 'room_home_cta'
                                        : 'room_home_review',
                                  ),
                                  style: AppText.body.copyWith(
                                    fontWeight: FontWeight.w800,
                                    color: const Color(0xFF16233B),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Three soft blurred blobs hinting at SAM silhouettes on the card's right.
class _BlobPainter extends CustomPainter {
  final List<Offset> offsets;
  _BlobPainter({required this.offsets});

  @override
  void paint(Canvas canvas, Size size) {
    final colors = [teal, blue, coral];
    final radii = [36.0, 28.0, 32.0];
    final centers = [
      Offset(size.width - 72, 44),
      Offset(size.width - 36, 92),
      Offset(size.width - 104, 116),
    ];
    for (var i = 0; i < 3; i++) {
      final paint = Paint()
        ..color = colors[i].withValues(alpha: 0.45)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 18);
      canvas.drawCircle(centers[i] + offsets[i], radii[i], paint);
    }
  }

  @override
  bool shouldRepaint(_BlobPainter oldDelegate) =>
      oldDelegate.offsets != offsets;
}
