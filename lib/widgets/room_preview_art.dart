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
    final shapes = [
      (teal, Rect.fromLTWH(0.06 * w, 0.69 * h, 0.40 * w, 0.25 * h)),
      (blue, Rect.fromLTWH(0.62 * w, 0.60 * h, 0.32 * w, 0.22 * h)),
      (coral, Rect.fromLTWH(0.06 * w, 0.08 * h, 0.30 * w, 0.16 * h)),
      (orange, Rect.fromLTWH(0.76 * w, 0.08 * h, 0.16 * w, 0.22 * h)),
    ];
    for (var i = 0; i < shapes.length; i++) {
      final color = shapes[i].$1;
      final rect = shapes[i].$2;
      final ease = (i < opacities.length ? opacities[i] : 0.38) / 0.45;
      final op = i < opacities.length ? opacities[i] : 0.38;
      if (op <= 0) continue;
      final r = RRect.fromRectAndRadius(rect, const Radius.circular(12));
      canvas.drawRRect(r, Paint()..color = color.withValues(alpha: op));
      canvas.drawRRect(
        r,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2
          ..color = color.withValues(alpha: (ease * 0.9).clamp(0.0, 1.0)),
      );
      final c = rect.center;
      canvas.drawCircle(
        c,
        13,
        Paint()..color = Colors.white.withValues(alpha: ease.clamp(0.0, 1.0)),
      );
      final tp = TextPainter(
        text: TextSpan(
          text: '${i + 1}',
          style: TextStyle(
            color: color,
            fontWeight: FontWeight.w800,
            fontSize: 13,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, c - Offset(tp.width / 2, tp.height / 2));
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
