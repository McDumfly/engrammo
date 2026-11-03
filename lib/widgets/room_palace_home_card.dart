import 'dart:math';

import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';

import '../l10n/app_localizations.dart';
import '../screens/room_palace_page.dart' show RoomPalacePage;
import '../services/app_feedback.dart';
import '../theme/app_colors.dart' show blue, coral, teal;
import '../theme/app_tokens.dart';
import '../utils/test_mode.dart';
import 'app_kit.dart';

/// The one shared "SAM 3.1 · Muse Spark · Muse Image" caption: model names
/// are proper nouns, used in both the home card and the Practice hub hero.
const kRoomModelsCaption = 'SAM 3.1 · Muse Spark · Muse Image';

/// Dark hero card at the top of the Home tab: Room Palace entry.
class RoomPalaceHomeCard extends StatefulWidget {
  const RoomPalaceHomeCard({super.key});

  @override
  State<RoomPalaceHomeCard> createState() => _RoomPalaceHomeCardState();
}

class _RoomPalaceHomeCardState extends State<RoomPalaceHomeCard>
    with TickerProviderStateMixin {
  late final AnimationController _enter;
  late final AnimationController _drift;
  late final Animation<double> _fade;
  bool _settled = false;

  @override
  void initState() {
    super.initState();
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

  Future<void> _open() async {
    AppFeedback.light();
    await Navigator.of(context)
        .push(MaterialPageRoute(builder: (_) => const RoomPalacePage()));
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([_enter, _drift]),
      builder: (context, _) {
        final t = _drift.value * 2 * pi;
        final offsets = [
          Offset(0, 6 * sin(t)),
          Offset(0, 6 * sin(t + 2.09)),
          Offset(0, 6 * sin(t + 4.19)),
        ];
        final card = Tappable(
          haptic: false,
          onTap: _open,
          child: SizedBox(
            height: 152,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(AppRadius.l),
              child: Stack(
                children: [
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
                    child: CustomPaint(painter: _BlobPainter(offsets: offsets)),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 16, 76, 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Align(
                          alignment: Alignment.centerLeft,
                          child: AppBadge(
                            label: kRoomModelsCaption,
                            color: teal,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          tr('room_home_title'),
                          style: AppText.title.copyWith(color: Colors.white),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          tr('room_home_sub'),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: AppText.caption.copyWith(
                            color: Colors.white.withValues(alpha: 0.8),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Positioned(
                    right: 16,
                    bottom: 16,
                    child: Container(
                      width: 44,
                      height: 44,
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                      ),
                      alignment: Alignment.center,
                      child: const HugeIcon(
                        icon: HugeIcons.strokeRoundedCamera01,
                        color: Color(0xFF16233B),
                        size: 22,
                        strokeWidth: 2.0,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
        if (_settled) return card;
        return Opacity(
          opacity: _fade.value,
          child: Transform.translate(
            offset: Offset(0, 12 * (1 - _fade.value)),
            child: card,
          ),
        );
      },
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
