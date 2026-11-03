import 'package:flutter/material.dart';

import '../theme/app_colors.dart' show blue, coral, orange, teal;
import '../theme/app_tokens.dart';
import '../utils/test_mode.dart';

/// Dark preview of what the learner gets: four furniture silhouettes
/// fading in one after another, then breathing gently.
/// Shared by the Room Palace capture step and onboarding page 2.
class RoomPreviewArt extends StatefulWidget {
  final double aspectRatio;
  const RoomPreviewArt({super.key, this.aspectRatio = 1.25});

  @override
  State<RoomPreviewArt> createState() => _RoomPreviewArtState();
}

class _RoomPreviewArtState extends State<RoomPreviewArt>
    with TickerProviderStateMixin {
  late final AnimationController _stagger;
  late final AnimationController _pulse;

  @override
  void initState() {
    super.initState();
    _stagger = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300 + 120 * 3),
    )..forward();
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2400),
    );
    // A repeating ticker never settles: static preview under tests.
    if (!isFlutterTest) _pulse.repeat(reverse: true);
  }

  @override
  void dispose() {
    _stagger.dispose();
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: AspectRatio(
          aspectRatio: widget.aspectRatio,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(AppRadius.xl),
            child: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFF16233B), Color(0xFF0E3B4A)],
                ),
              ),
              child: AnimatedBuilder(
                animation: Listenable.merge([_stagger, _pulse]),
                builder: (context, _) {
                  final elapsed =
                      _stagger.value * _stagger.duration!.inMilliseconds;
                  final breath = 0.3 + 0.15 * _pulse.value;
                  return CustomPaint(
                    painter: _PreviewPainter(
                      opacities: [
                        for (var i = 0; i < 4; i++)
                          Curves.easeOutCubic.transform(
                                ((elapsed - i * 120) / 300).clamp(0.0, 1.0),
                              ) *
                              breath,
                      ],
                    ),
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Four furniture silhouettes with numbered badges, drawn on the
/// capture preview card.
class _PreviewPainter extends CustomPainter {
  final List<double> opacities;
  _PreviewPainter({required this.opacities});

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    // Faint room shell behind the furniture: a window and a floor line.
    final shell = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..color = Colors.white.withValues(alpha: .08);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(0.40 * w, 0.10 * h, 0.22 * w, 0.18 * h),
        const Radius.circular(8),
      ),
      shell,
    );
    canvas.drawLine(
      Offset(0.04 * w, 0.93 * h),
      Offset(0.96 * w, 0.93 * h),
      shell,
    );

    final regions = [
      Rect.fromLTWH(0.06 * w, 0.69 * h, 0.40 * w, 0.25 * h),
      Rect.fromLTWH(0.62 * w, 0.60 * h, 0.32 * w, 0.22 * h),
      Rect.fromLTWH(0.06 * w, 0.08 * h, 0.30 * w, 0.16 * h),
      Rect.fromLTWH(0.76 * w, 0.08 * h, 0.16 * w, 0.22 * h),
    ];
    final colors = [teal, blue, coral, orange];
    for (var i = 0; i < regions.length; i++) {
      final color = colors[i];
      final region = regions[i];
      final ease = ((i < opacities.length ? opacities[i] : 0.38) / 0.45).clamp(
        0.0,
        1.0,
      );
      final op = i < opacities.length ? opacities[i] : 0.38;
      if (op <= 0) continue;
      final path = _furniturePath(i, region);
      canvas.drawPath(path, Paint()..color = color.withValues(alpha: op));
      canvas.drawPath(
        path,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2
          ..color = color.withValues(alpha: (ease * 0.9).clamp(0.0, 1.0)),
      );
      if (i == 2) {
        // Shelf boards: 3 lines across in the edge colour at 60%.
        final boards = Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2
          ..color = color.withValues(alpha: 0.6 * ease);
        for (var k = 1; k <= 3; k++) {
          final y = region.top + region.height * k / 4;
          canvas.drawLine(
            Offset(region.left + 6, y),
            Offset(region.right - 6, y),
            boards,
          );
        }
      }
      // Numbered badge: opaque white with a dark digit.
      final c = region.center;
      canvas.drawCircle(c, 13, Paint()..color = Colors.white);
      final tp = TextPainter(
        text: TextSpan(
          text: '${i + 1}',
          style: const TextStyle(
            color: Color(0xFF16233B),
            fontWeight: FontWeight.w800,
            fontSize: 13,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, c - Offset(tp.width / 2, tp.height / 2));
    }
  }

  /// Furniture silhouette for slot [i] inside [r]: bed (body + pillow),
  /// desk (top + two legs), shelf (tall rect, boards drawn separately),
  /// lamp (round shade + thin stem).
  Path _furniturePath(int i, Rect r) {
    switch (i) {
      case 0:
        return Path()
          ..addRRect(RRect.fromRectAndRadius(r, const Radius.circular(12)))
          ..addRRect(
            RRect.fromRectAndRadius(
              Rect.fromLTWH(
                r.left + r.width * 0.08,
                r.top + r.height * 0.12,
                r.width * 0.30,
                r.height * 0.38,
              ),
              const Radius.circular(8),
            ),
          );
      case 1:
        final topH = r.height * 0.24;
        final legW = (r.width * 0.07).clamp(3.0, 8.0);
        return Path()
          ..addRRect(
            RRect.fromRectAndRadius(
              Rect.fromLTWH(r.left, r.top, r.width, topH),
              const Radius.circular(6),
            ),
          )
          ..addRect(
            Rect.fromLTWH(
              r.left + r.width * 0.10,
              r.top + topH,
              legW,
              r.height - topH,
            ),
          )
          ..addRect(
            Rect.fromLTWH(
              r.right - r.width * 0.10 - legW,
              r.top + topH,
              legW,
              r.height - topH,
            ),
          );
      case 2:
        return Path()
          ..addRRect(RRect.fromRectAndRadius(r, const Radius.circular(8)));
      default:
        final shadeR = r.width * 0.30;
        final cx = r.center.dx;
        final cy = r.top + shadeR + 2;
        return Path()
          ..addOval(Rect.fromCircle(center: Offset(cx, cy), radius: shadeR))
          ..addRect(
            Rect.fromLTWH(cx - 2, cy + shadeR, 4, r.bottom - cy - shadeR),
          );
    }
  }

  @override
  bool shouldRepaint(covariant _PreviewPainter old) {
    if (old.opacities.length != opacities.length) return true;
    for (var i = 0; i < opacities.length; i++) {
      if (old.opacities[i] != opacities[i]) return true;
    }
    return false;
  }
}
