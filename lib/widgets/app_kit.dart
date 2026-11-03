import 'dart:async';
import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hugeicons/hugeicons.dart';

import '../l10n/app_localizations.dart';
import '../services/app_feedback.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import '../theme/app_tokens.dart';
import 'app_buttons.dart';

/// Shared dialog shadow: only toasts, dialogs and sheets get a shadow.
const BoxShadow kAppFloatShadow = BoxShadow(
  color: Color(0x1F000000),
  blurRadius: 24,
  offset: Offset(0, 8),
);

/// Branded arc loader: a track circle plus a breathing rotating head.
class AppLoader extends StatefulWidget {
  const AppLoader({
    super.key,
    this.size = 28,
    this.color,
    this.stroke = 3,
    this.caption,
  });
  final double size;
  final Color? color;
  final double stroke;
  final String? caption;

  @override
  State<AppLoader> createState() => _AppLoaderState();
}

class _AppLoaderState extends State<AppLoader> with TickerProviderStateMixin {
  late final AnimationController _spin;
  late final AnimationController _breath;
  late final AnimationController _delay;
  bool _visible = false;

  @override
  void initState() {
    super.initState();
    _spin = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat();
    _breath = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
    // Ticker-driven 150ms delay (not Future.delayed): leaves no pending
    // Timer behind, so tests that pump a loader briefly stay green.
    _delay =
        AnimationController(
          vsync: this,
          duration: const Duration(milliseconds: 150),
        )..addStatusListener((status) {
          if (status == AnimationStatus.completed && mounted) {
            setState(() => _visible = true);
          }
        });
    _delay.forward();
  }

  @override
  void dispose() {
    _spin.dispose();
    _breath.dispose();
    _delay.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final color = widget.color ?? blue;
    final arc = AnimatedBuilder(
      animation: Listenable.merge([_spin, _breath]),
      builder: (context, _) {
        final eased = Curves.easeInOut.transform(_breath.value);
        final sweepDeg = 200 + 100 * eased;
        return CustomPaint(
          size: Size(widget.size, widget.size),
          painter: _LoaderArcPainter(
            rotation: _spin.value,
            sweep: sweepDeg * math.pi / 180,
            color: color,
            stroke: widget.stroke,
          ),
        );
      },
    );
    final body = widget.caption == null
        ? arc
        : Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              arc,
              const SizedBox(height: 12),
              Text(
                widget.caption!,
                style: AppText.caption.copyWith(color: context.mutedText),
                textAlign: TextAlign.center,
              ),
            ],
          );
    return AnimatedOpacity(
      opacity: _visible ? 1 : 0,
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOutCubic,
      child: body,
    );
  }
}

class _LoaderArcPainter extends CustomPainter {
  _LoaderArcPainter({
    required this.rotation,
    required this.sweep,
    required this.color,
    required this.stroke,
  });

  final double rotation;
  final double sweep;
  final Color color;
  final double stroke;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = (size.shortestSide - stroke) / 2;
    final track = Paint()
      ..color = color.withValues(alpha: 0.15)
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round;
    canvas.drawCircle(center, radius, track);
    final head = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -math.pi / 2 + rotation * 2 * math.pi,
      sweep,
      false,
      head,
    );
  }

  @override
  bool shouldRepaint(covariant _LoaderArcPainter old) =>
      old.rotation != rotation ||
      old.sweep != sweep ||
      old.color != color ||
      old.stroke != stroke;
}

/// Shimmering placeholder block with a sweeping diagonal highlight band.
class AppSkeleton extends StatefulWidget {
  const AppSkeleton({
    super.key,
    this.width,
    required this.height,
    this.radius = AppRadius.m,
  });
  final double? width;
  final double height;
  final double radius;

  @override
  State<AppSkeleton> createState() => _AppSkeletonState();
}

class _SlideTransform extends GradientTransform {
  const _SlideTransform(this.dx);
  final double dx;

  @override
  Matrix4 transform(Rect bounds, {TextDirection? textDirection}) =>
      Matrix4.translationValues(dx, 0, 0);
}

class _AppSkeletonState extends State<AppSkeleton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final base = context.faintBg;
    final band = context.hairline;
    return LayoutBuilder(
      builder: (context, constraints) {
        final w = constraints.maxWidth.isFinite
            ? constraints.maxWidth
            : (widget.width ?? 320);
        return AnimatedBuilder(
          animation: _ctrl,
          builder: (context, _) {
            final dx = (_ctrl.value * 2 - 1) * w;
            return Container(
              width: widget.width,
              height: widget.height,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(widget.radius),
                gradient: LinearGradient(
                  colors: [base, band, base],
                  stops: const [0.35, 0.5, 0.65],
                  transform: _SlideTransform(dx),
                ),
              ),
            );
          },
        );
      },
    );
  }
}

/// Pill progress bar with a glossy fill; indeterminate slides a segment.
class AppProgressBar extends StatelessWidget {
  const AppProgressBar({
    super.key,
    this.value,
    this.height = 8,
    this.color,
    this.track,
    this.duration = const Duration(milliseconds: 320),
  });
  final double? value; // null = indeterminate
  final double height;
  final Color? color;
  final Color? track;
  final Duration duration;

  @override
  Widget build(BuildContext context) {
    final fill = color ?? blue;
    final trackColor = track ?? context.hairline;
    final highlight = Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(height / 2),
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color.lerp(fill, Colors.white, 0.25)!, fill],
        ),
      ),
    );
    if (value == null) {
      return Container(
        height: height,
        decoration: BoxDecoration(
          color: trackColor,
          borderRadius: BorderRadius.circular(height / 2),
        ),
        clipBehavior: Clip.antiAlias,
        child: _IndeterminateFill(height: height, fill: highlight),
      );
    }
    return Container(
      height: height,
      decoration: BoxDecoration(
        color: trackColor,
        borderRadius: BorderRadius.circular(height / 2),
      ),
      clipBehavior: Clip.antiAlias,
      child: Align(
        alignment: Alignment.centerLeft,
        child: TweenAnimationBuilder<double>(
          tween: Tween(end: value!.clamp(0, 1).toDouble()),
          duration: duration,
          curve: Curves.easeOutCubic,
          builder: (context, v, _) => FractionallySizedBox(
            widthFactor: v,
            alignment: Alignment.centerLeft,
            child: SizedBox(height: height, child: highlight),
          ),
        ),
      ),
    );
  }
}

class _IndeterminateFill extends StatefulWidget {
  const _IndeterminateFill({required this.height, required this.fill});
  final double height;
  final Widget fill;

  @override
  State<_IndeterminateFill> createState() => _IndeterminateFillState();
}

class _IndeterminateFillState extends State<_IndeterminateFill>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    )..repeat();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final w = constraints.maxWidth.isFinite ? constraints.maxWidth : 320.0;
        return AnimatedBuilder(
          animation: _ctrl,
          builder: (context, _) {
            final t = Curves.easeInOutCubic.transform(_ctrl.value);
            final left = (-0.35 + 1.35 * t) * w;
            return Stack(
              children: [
                Positioned(
                  left: left,
                  width: 0.35 * w,
                  top: 0,
                  bottom: 0,
                  child: widget.fill,
                ),
              ],
            );
          },
        );
      },
    );
  }
}

/// Determinate countdown ring with a centered child.
class AppProgressRing extends StatelessWidget {
  const AppProgressRing({
    super.key,
    required this.value,
    this.size = 56,
    this.stroke = 5,
    this.color,
    this.child,
  });
  final double value;
  final double size;
  final double stroke;
  final Color? color;
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    final arc = color ?? blue;
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          TweenAnimationBuilder<double>(
            tween: Tween(end: value.clamp(0, 1).toDouble()),
            duration: const Duration(milliseconds: 200),
            builder: (context, v, _) => CustomPaint(
              size: Size(size, size),
              painter: _RingPainter(
                value: v,
                arc: arc,
                track: context.hairline,
                stroke: stroke,
              ),
            ),
          ),
          child ?? const SizedBox.shrink(),
        ],
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  _RingPainter({
    required this.value,
    required this.arc,
    required this.track,
    required this.stroke,
  });

  final double value;
  final Color arc;
  final Color track;
  final double stroke;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = (size.shortestSide - stroke) / 2;
    final trackPaint = Paint()
      ..color = track
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke;
    canvas.drawCircle(center, radius, trackPaint);
    final arcPaint = Paint()
      ..color = arc
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -math.pi / 2,
      value * 2 * math.pi,
      false,
      arcPaint,
    );
  }

  @override
  bool shouldRepaint(covariant _RingPainter old) =>
      old.value != value ||
      old.arc != arc ||
      old.track != track ||
      old.stroke != stroke;
}

/// Top capsule toast; a new toast always replaces the previous one.
enum ToastKind { info, success, warning, error }

OverlayEntry? _currentToast;

void showAppToast(
  BuildContext context,
  String message, {
  ToastKind kind = ToastKind.info,
  String? actionLabel,
  VoidCallback? onAction,
  Duration duration = const Duration(milliseconds: 2800),
}) {
  try {
    _currentToast?.remove();
  } catch (_) {}
  _currentToast = null;
  if (kind == ToastKind.success) {
    AppFeedback.select();
  } else if (kind == ToastKind.error) {
    AppFeedback.medium();
  }
  final overlay = Overlay.of(context, rootOverlay: true);
  final key = GlobalKey<_ToastViewState>();
  late OverlayEntry entry;
  var dismissed = false;
  void dismiss() {
    if (dismissed) return;
    dismissed = true;
    final state = key.currentState;
    void remove() {
      if (_currentToast == entry) _currentToast = null;
      try {
        entry.remove();
      } catch (_) {}
    }

    if (state == null) {
      remove();
    } else {
      state.dismiss(remove);
    }
  }

  entry = OverlayEntry(
    builder: (entryContext) => _ToastView(
      key: key,
      message: message,
      kind: kind,
      actionLabel: actionLabel,
      duration: duration,
      onAction: () {
        onAction?.call();
        dismiss();
      },
      onSwipeUp: dismiss,
    ),
  );
  _currentToast = entry;
  overlay.insert(entry);
}

class _ToastViewState extends State<_ToastView>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<Offset> _slide;
  late final Animation<double> _fade;
  Timer? _autoDismiss;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 260),
      reverseDuration: const Duration(milliseconds: 200),
    );
    _slide = Tween<Offset>(
      begin: const Offset(0, -1.2),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOutBack));
    _fade = Tween<double>(
      begin: 0,
      end: 1,
    ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOut));
    _ctrl.forward();
    // State-owned timer: cancelled on dispose, so a toast shown during a
    // test never leaves a pending Timer behind at teardown.
    _autoDismiss = Timer(widget.duration, () => widget.onSwipeUp());
  }

  void dismiss(VoidCallback onDone) {
    _ctrl.reverse().whenComplete(onDone);
  }

  @override
  void dispose() {
    _autoDismiss?.cancel();
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final iconData = switch (widget.kind) {
      ToastKind.info => HugeIcons.strokeRoundedInformationCircle,
      ToastKind.success => HugeIcons.strokeRoundedCheckmarkCircle02,
      ToastKind.warning => HugeIcons.strokeRoundedAlert02,
      ToastKind.error => HugeIcons.strokeRoundedCancelCircle,
    };
    final iconColor = switch (widget.kind) {
      ToastKind.info => blue,
      ToastKind.success => success,
      ToastKind.warning => orange,
      ToastKind.error => coral,
    };
    return Material(
      type: MaterialType.transparency,
      child: SafeArea(
        bottom: false,
        child: Container(
          margin: EdgeInsets.only(
            top: MediaQuery.paddingOf(context).top + 8,
            left: 16,
            right: 16,
          ),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: SlideTransition(
                position: _slide,
                child: FadeTransition(
                  opacity: _fade,
                  child: GestureDetector(
                    onVerticalDragEnd: (details) {
                      if ((details.primaryVelocity ?? 0) < 0) {
                        widget.onSwipeUp();
                      }
                    },
                    child: Container(
                      padding: const EdgeInsets.fromLTRB(14, 12, 18, 12),
                      decoration: BoxDecoration(
                        color: context.cardBg,
                        borderRadius: BorderRadius.circular(AppRadius.pill),
                        border: Border.all(color: context.hairline, width: 2),
                        boxShadow: const [kAppFloatShadow],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          HugeIcon(icon: iconData, color: iconColor, size: 22),
                          const SizedBox(width: 10),
                          Flexible(
                            child: Text(
                              widget.message,
                              style: AppText.body.copyWith(
                                color: context.inkText,
                                fontWeight: FontWeight.w600,
                              ),
                              maxLines: 3,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (widget.actionLabel != null) ...[
                            const SizedBox(width: 12),
                            GestureDetector(
                              onTap: widget.onAction,
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 4,
                                ),
                                child: Text(
                                  widget.actionLabel!,
                                  style: AppText.body.copyWith(
                                    color: context.accentText(blue),
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ToastView extends StatefulWidget {
  const _ToastView({
    super.key,
    required this.message,
    required this.kind,
    required this.duration,
    this.actionLabel,
    this.onAction,
    required this.onSwipeUp,
  });
  final String message;
  final ToastKind kind;
  final Duration duration;
  final String? actionLabel;
  final VoidCallback? onAction;
  final VoidCallback onSwipeUp;

  @override
  State<_ToastView> createState() => _ToastViewState();
}

/// Column of skeleton rows for whole-page or list loading states.
class AppSkeletonList extends StatelessWidget {
  const AppSkeletonList({super.key, this.count = 4, this.itemHeight = 72});
  final int count;
  final double itemHeight;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 0; i < count; i++) ...[
            if (i > 0) const SizedBox(height: 12),
            AppSkeleton(height: itemHeight),
          ],
        ],
      ),
    );
  }
}

/// One stacked dialog button: pops with [value] after [onPressed].
class AppDialogAction {
  const AppDialogAction(this.label, {this.onPressed, this.value});
  final String label;
  final VoidCallback? onPressed;
  final Object? value;
}

/// Centered branded dialog with stacked full-width buttons.
Future<T?> showAppDialog<T>(
  BuildContext context, {
  required String title,
  String? body,
  Widget? content,
  dynamic icon,
  Color? iconColor,
  required AppDialogAction primary,
  AppDialogAction? secondary,
  bool destructive = false,
  bool barrierDismissible = true,
}) {
  AppFeedback.light();
  return showGeneralDialog<T>(
    context: context,
    barrierColor: Colors.transparent,
    barrierDismissible: false,
    barrierLabel: barrierDismissible ? tr('common_close') : null,
    transitionDuration: const Duration(milliseconds: 220),
    pageBuilder: (dialogContext, _, _) {
      final theme = Theme.of(dialogContext);
      final dark = theme.brightness == Brightness.dark;
      final card = dark ? AppTheme.darkCard : Colors.white;
      final inkColor = theme.colorScheme.onSurface;
      final mutedColor = theme.colorScheme.onSurfaceVariant;
      final hairline = dark ? AppTheme.darkBorder : line;
      final tint = iconColor ?? blue;
      void pop(Object? value) => Navigator.of(dialogContext).pop(value);
      return Stack(
        children: [
          Positioned.fill(
            child: GestureDetector(
              onTap: barrierDismissible ? () => pop(null) : null,
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 6, sigmaY: 6),
                child: ColoredBox(color: Colors.black.withValues(alpha: 0.35)),
              ),
            ),
          ),
          Center(
            child: Container(
              constraints: const BoxConstraints(maxWidth: 400),
              margin: const EdgeInsets.all(24),
              padding: const EdgeInsets.fromLTRB(24, 28, 24, 20),
              decoration: BoxDecoration(
                color: card,
                borderRadius: BorderRadius.circular(AppRadius.xl),
                border: Border.all(color: hairline, width: 2),
                boxShadow: const [kAppFloatShadow],
              ),
              child: Material(
                type: MaterialType.transparency,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (icon != null) ...[
                      Container(
                        width: 64,
                        height: 64,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: tint.withValues(alpha: 0.12),
                        ),
                        alignment: Alignment.center,
                        child: HugeIcon(icon: icon, color: tint, size: 30),
                      ),
                      const SizedBox(height: 16),
                    ],
                    Text(
                      title,
                      style: AppText.title.copyWith(color: inkColor),
                      textAlign: TextAlign.center,
                    ),
                    if (body != null) ...[
                      const SizedBox(height: 8),
                      Text(
                        body,
                        style: AppText.body.copyWith(color: mutedColor),
                        textAlign: TextAlign.center,
                      ),
                    ],
                    if (content != null) ...[
                      const SizedBox(height: 12),
                      content,
                    ],
                    const SizedBox(height: 24),
                    EngramButton(
                      label: primary.label,
                      variant: destructive
                          ? EngramButtonVariant.danger
                          : EngramButtonVariant.primary,
                      height: 54,
                      onPressed: () {
                        if (destructive) AppFeedback.medium();
                        primary.onPressed?.call();
                        pop(primary.value);
                      },
                    ),
                    if (secondary != null) ...[
                      const SizedBox(height: 8),
                      EngramTextButton(
                        label: secondary.label,
                        onPressed: () {
                          secondary.onPressed?.call();
                          pop(secondary.value);
                        },
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ],
      );
    },
    transitionBuilder: (context, animation, _, child) {
      final curved = CurvedAnimation(
        parent: animation,
        curve: Curves.easeOutCubic,
      );
      return FadeTransition(
        opacity: curved,
        child: ScaleTransition(
          scale: Tween<double>(begin: 0.94, end: 1).animate(curved),
          child: child,
        ),
      );
    },
  );
}

/// Bottom-sheet shell with our grabber, radius and keyboard padding.
class AppSheet extends StatelessWidget {
  const AppSheet({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return AnimatedPadding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOutCubic,
      child: SafeArea(
        top: false,
        child: Container(
          decoration: BoxDecoration(
            color: context.cardBg,
            borderRadius: const BorderRadius.vertical(
              top: Radius.circular(AppRadius.xl),
            ),
            border: Border(top: BorderSide(color: context.hairline, width: 2)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 10),
                child: Container(
                  width: 44,
                  height: 5,
                  decoration: BoxDecoration(
                    color: context.hairline,
                    borderRadius: BorderRadius.circular(AppRadius.pill),
                  ),
                ),
              ),
              Flexible(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: child,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The one allowed showModalBottomSheet: every sheet goes through this.
Future<T?> showAppSheet<T>(
  BuildContext context, {
  required WidgetBuilder builder,
  bool isScrollControlled = true,
}) {
  return showModalBottomSheet<T>(
    context: context,
    backgroundColor: Colors.transparent,
    barrierColor: Colors.black.withValues(alpha: 0.35),
    elevation: 0,
    useSafeArea: true,
    isScrollControlled: isScrollControlled,
    showDragHandle: false,
    sheetAnimationStyle: const AnimationStyle(
      duration: Duration(milliseconds: 300),
      curve: Curves.easeOutCubic,
    ),
    builder: (sheetContext) => AppSheet(child: builder(sheetContext)),
  );
}

/// Pill toggle chip with an animated selected state.
class AppChip extends StatelessWidget {
  const AppChip({
    super.key,
    required this.label,
    this.selected = false,
    this.onTap,
    this.icon,
    this.tint,
  });
  final String label;
  final bool selected;
  final VoidCallback? onTap;
  final dynamic icon;
  final Color? tint;

  @override
  Widget build(BuildContext context) {
    final accent = tint ?? blue;
    return Tappable(
      haptic: false,
      onTap: onTap == null
          ? null
          : () {
              AppFeedback.select();
              onTap!();
            },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOutCubic,
        height: 36,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(
          color: selected ? accent.withValues(alpha: 0.14) : context.cardBg,
          borderRadius: BorderRadius.circular(AppRadius.pill),
          border: Border.all(
            color: selected ? accent : context.hairline,
            width: 2,
          ),
        ),
        alignment: Alignment.center,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              HugeIcon(icon: icon, color: accent, size: 16),
              const SizedBox(width: 6),
            ],
            Text(
              label,
              style: AppText.caption.copyWith(
                color: selected ? context.accentText(accent) : context.inkText,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Small non-tappable status pill for model names and states.
class AppBadge extends StatelessWidget {
  const AppBadge({
    super.key,
    required this.label,
    this.color = teal,
    this.icon,
  });
  final String label;
  final Color color;
  final dynamic icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 26,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
      alignment: Alignment.center,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            HugeIcon(icon: icon, color: color, size: 14),
            const SizedBox(width: 4),
          ],
          Text(
            label,
            style: AppText.micro.copyWith(color: context.accentText(color)),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

/// Round checkbox with a popping white tick.
class AppCheckbox extends StatelessWidget {
  const AppCheckbox({
    super.key,
    required this.value,
    required this.onChanged,
    this.size = 28,
  });
  final bool value;
  final ValueChanged<bool>? onChanged;
  final double size;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onChanged == null
          ? null
          : () {
              AppFeedback.light();
              onChanged!(!value);
            },
      child: SizedBox(
        width: 44,
        height: 44,
        child: Center(
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOutCubic,
            width: size,
            height: size,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: value ? success : Colors.transparent,
              border: Border.all(
                color: value ? success : context.hairline,
                width: 2,
              ),
            ),
            alignment: Alignment.center,
            child: AnimatedScale(
              scale: value ? 1 : 0,
              duration: const Duration(milliseconds: 160),
              curve: Curves.easeOutBack,
              child: const HugeIcon(
                icon: HugeIcons.strokeRoundedTick02,
                color: Colors.white,
                size: 18,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Pill switch with a sliding white thumb.
class AppSwitch extends StatelessWidget {
  const AppSwitch({super.key, required this.value, required this.onChanged});
  final bool value;
  final ValueChanged<bool>? onChanged;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onChanged == null
          ? null
          : () {
              AppFeedback.select();
              onChanged!(!value);
            },
      child: Container(
        constraints: const BoxConstraints(minWidth: 64, minHeight: 44),
        alignment: Alignment.center,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOutCubic,
          width: 52,
          height: 32,
          padding: const EdgeInsets.all(3),
          decoration: BoxDecoration(
            color: value ? blueDark : context.hairline,
            borderRadius: BorderRadius.circular(AppRadius.pill),
          ),
          child: AnimatedAlign(
            alignment: value ? Alignment.centerRight : Alignment.centerLeft,
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOutCubic,
            child: Container(
              width: 26,
              height: 26,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white,
                boxShadow: [kAppFloatShadow],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Sliding-thumb segmented control for 2-4 exclusive options.
class AppSegmented<T> extends StatelessWidget {
  const AppSegmented({
    super.key,
    required this.options,
    required this.value,
    required this.onChanged,
  });
  final List<(T, String)> options;
  final T value;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) {
    final n = options.length;
    final selectedIndex = options
        .indexWhere((o) => o.$1 == value)
        .clamp(0, n - 1);
    final align = n <= 1
        ? Alignment.center
        : Alignment(-1 + 2 * selectedIndex / (n - 1), 0);
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: context.softBg,
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final thumbWidth = constraints.maxWidth.isFinite
              ? constraints.maxWidth / n
              : null;
          return Stack(
            children: [
              AnimatedAlign(
                alignment: align,
                duration: const Duration(milliseconds: 220),
                curve: Curves.easeOutCubic,
                child: Container(
                  width: thumbWidth,
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  decoration: BoxDecoration(
                    color: context.cardBg,
                    borderRadius: BorderRadius.circular(AppRadius.pill),
                    boxShadow: const [kAppFloatShadow],
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    options[selectedIndex].$2,
                    style: AppText.caption.copyWith(
                      color: Colors.transparent,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
              Row(
                children: [
                  for (var i = 0; i < n; i++)
                    Expanded(
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: () {
                          if (options[i].$1 == value) return;
                          AppFeedback.select();
                          onChanged(options[i].$1);
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          alignment: Alignment.center,
                          child: Text(
                            options[i].$2,
                            style: AppText.caption.copyWith(
                              color: i == selectedIndex
                                  ? context.inkText
                                  : context.mutedText,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }
}

/// Collapsible section with a rotating arrow, no Material involved.
class AppDisclosure extends StatefulWidget {
  const AppDisclosure({
    super.key,
    required this.title,
    required this.children,
    this.initiallyOpen = false,
    this.leading,
  });
  final Widget title;
  final List<Widget> children;
  final bool initiallyOpen;
  final Widget? leading;

  @override
  State<AppDisclosure> createState() => _AppDisclosureState();
}

class _AppDisclosureState extends State<AppDisclosure> {
  late bool _open;

  @override
  void initState() {
    super.initState();
    _open = widget.initiallyOpen;
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Tappable(
          onTap: () {
            AppFeedback.light();
            setState(() => _open = !_open);
          },
          child: Container(
            constraints: const BoxConstraints(minHeight: 48),
            alignment: Alignment.center,
            child: Row(
              children: [
                if (widget.leading != null) ...[
                  widget.leading!,
                  const SizedBox(width: 8),
                ],
                Expanded(child: widget.title),
                AnimatedRotation(
                  turns: _open ? 0.25 : 0,
                  duration: const Duration(milliseconds: 220),
                  curve: Curves.easeOutCubic,
                  child: HugeIcon(
                    icon: HugeIcons.strokeRoundedArrowRight01,
                    color: context.mutedText,
                    size: 18,
                  ),
                ),
              ],
            ),
          ),
        ),
        AnimatedSize(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOutCubic,
          alignment: Alignment.topCenter,
          child: _open
              ? Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: widget.children,
                )
              : const SizedBox(width: double.infinity),
        ),
      ],
    );
  }
}

/// 1px hairline divider.
class AppDivider extends StatelessWidget {
  const AppDivider({super.key, this.indent = 0, this.thickness = 1});
  final double indent;
  final double thickness;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: thickness,
      margin: EdgeInsets.only(left: indent),
      color: context.hairline,
    );
  }
}

/// Press-scale + fade wrapper that replaces InkWell everywhere.
class Tappable extends StatefulWidget {
  const Tappable({
    super.key,
    required this.child,
    this.onTap,
    this.onLongPress,
    this.scale = 0.97,
    this.haptic = true,
    this.semanticLabel,
  });
  final Widget child;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final double scale;
  final bool haptic;
  final String? semanticLabel;

  @override
  State<Tappable> createState() => _TappableState();
}

class _TappableState extends State<Tappable> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final child = AnimatedScale(
      scale: _pressed ? widget.scale : 1,
      duration: const Duration(milliseconds: 90),
      curve: Curves.easeOut,
      child: AnimatedOpacity(
        opacity: _pressed ? 0.85 : (widget.onTap == null ? 0.5 : 1),
        duration: const Duration(milliseconds: 90),
        curve: Curves.easeOut,
        child: widget.child,
      ),
    );
    return Semantics(
      button: true,
      label: widget.semanticLabel,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: widget.onTap == null
            ? null
            : (_) => setState(() => _pressed = true),
        onTapUp: widget.onTap == null
            ? null
            : (_) {
                if (mounted) setState(() => _pressed = false);
              },
        onTapCancel: () {
          if (mounted) setState(() => _pressed = false);
        },
        onTap: widget.onTap == null
            ? null
            : () {
                if (widget.haptic) AppFeedback.light();
                widget.onTap!();
              },
        onLongPress: widget.onLongPress,
        child: child,
      ),
    );
  }
}

/// Branded text field with a static label, focus ring and shake on error.
class AppTextField extends StatefulWidget {
  const AppTextField({
    super.key,
    this.controller,
    this.focusNode,
    this.label,
    this.hint,
    this.minLines = 1,
    this.maxLines = 1,
    this.maxLength,
    this.prefix,
    this.suffix,
    this.onChanged,
    this.onSubmitted,
    this.textInputAction,
    this.keyboardType,
    this.textCapitalization = TextCapitalization.sentences,
    this.inputFormatters,
    this.obscureText = false,
    this.autocorrect = true,
    this.enableSuggestions = true,
    this.enabled = true,
    this.autofocus = false,
    this.errorText,
    this.scrollPadding = const EdgeInsets.only(bottom: 140),
  });
  final TextEditingController? controller;
  final FocusNode? focusNode;
  final String? label;
  final String? hint;
  final int minLines;
  final int maxLines;
  final int? maxLength;
  final Widget? prefix;
  final Widget? suffix;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final TextInputAction? textInputAction;
  final TextInputType? keyboardType;
  final TextCapitalization textCapitalization;
  final List<TextInputFormatter>? inputFormatters;
  final bool obscureText;
  final bool autocorrect;
  final bool enableSuggestions;
  final bool enabled;
  final bool autofocus;
  final String? errorText;
  final EdgeInsets scrollPadding;

  @override
  State<AppTextField> createState() => _AppTextFieldState();
}

class _AppTextFieldState extends State<AppTextField> {
  TextEditingController? _ownController;
  FocusNode? _ownFocus;
  bool _focused = false;
  int _shakeKey = 0;
  int _len = 0;

  TextEditingController get _controller => widget.controller ?? _ownController!;
  FocusNode get _focus => widget.focusNode ?? _ownFocus!;

  @override
  void initState() {
    super.initState();
    if (widget.controller == null) {
      _ownController = TextEditingController();
    }
    if (widget.focusNode == null) _ownFocus = FocusNode();
    _len = _controller.text.length;
    _controller.addListener(_onText);
    _focus.addListener(_onFocus);
  }

  void _onText() {
    final l = _controller.text.length;
    if (l != _len && mounted) setState(() => _len = l);
  }

  void _onFocus() {
    final f = _focus.hasFocus;
    if (f != _focused && mounted) setState(() => _focused = f);
  }

  @override
  void didUpdateWidget(covariant AppTextField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.controller != oldWidget.controller) {
      if (oldWidget.controller != null) {
        oldWidget.controller!.removeListener(_onText);
      } else {
        _ownController?.removeListener(_onText);
      }
      final text = oldWidget.controller?.text ?? _ownController?.text ?? '';
      if (widget.controller == null) {
        _ownController?.dispose();
        _ownController = TextEditingController(text: text);
      } else {
        _ownController?.removeListener(_onText);
        _ownController?.dispose();
        _ownController = null;
      }
      _controller.addListener(_onText);
      _len = _controller.text.length;
    }
    if (widget.focusNode != oldWidget.focusNode) {
      if (oldWidget.focusNode != null) {
        oldWidget.focusNode!.removeListener(_onFocus);
      } else {
        _ownFocus?.removeListener(_onFocus);
        _ownFocus?.dispose();
        _ownFocus = null;
      }
      if (widget.focusNode == null) _ownFocus = FocusNode();
      _focus.addListener(_onFocus);
    }
    if (widget.errorText != null && oldWidget.errorText == null) {
      setState(() => _shakeKey++);
    }
  }

  @override
  void dispose() {
    _controller.removeListener(_onText);
    _focus.removeListener(_onFocus);
    _ownController?.dispose();
    _ownFocus?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final hasError = widget.errorText != null;
    final border = hasError
        ? coral
        : _focused
        ? blue
        : context.hairline;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (widget.label != null) ...[
          Text(
            widget.label!,
            style: AppText.micro.copyWith(color: context.mutedText),
          ),
          const SizedBox(height: 6),
        ],
        TweenAnimationBuilder<double>(
          key: ValueKey(_shakeKey),
          tween: Tween(begin: 0, end: 1),
          duration: const Duration(milliseconds: 300),
          builder: (context, t, child) {
            final dx = _shakeKey == 0
                ? 0.0
                : math.sin(t * math.pi * 2) * 8 * (1 - t);
            return Transform.translate(offset: Offset(dx, 0), child: child);
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOutCubic,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: context.softBg,
              borderRadius: BorderRadius.circular(AppRadius.m),
              border: Border.all(color: border, width: 2),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (widget.prefix != null) ...[
                  widget.prefix!,
                  const SizedBox(width: 8),
                ],
                Expanded(
                  child: TextField(
                    controller: _controller,
                    focusNode: _focus,
                    minLines: widget.minLines,
                    maxLines: widget.maxLines,
                    maxLength: widget.maxLength,
                    onChanged: widget.onChanged,
                    onSubmitted: widget.onSubmitted,
                    textInputAction: widget.textInputAction,
                    keyboardType: widget.keyboardType,
                    textCapitalization: widget.textCapitalization,
                    inputFormatters: widget.inputFormatters,
                    obscureText: widget.obscureText,
                    autocorrect: widget.autocorrect,
                    enableSuggestions: widget.enableSuggestions,
                    enabled: widget.enabled,
                    autofocus: widget.autofocus,
                    scrollPadding: widget.scrollPadding,
                    style: AppText.body.copyWith(color: context.inkText),
                    decoration: InputDecoration(
                      border: InputBorder.none,
                      isCollapsed: true,
                      hintText: widget.hint,
                      hintStyle: AppText.body.copyWith(
                        color: context.mutedText,
                      ),
                      contentPadding: EdgeInsets.zero,
                      counterText: '',
                    ),
                    buildCounter: (
                      _, {
                      required int currentLength,
                      required bool isFocused,
                      int? maxLength,
                    }) => null,
                  ),
                ),
                if (widget.suffix != null) ...[
                  const SizedBox(width: 8),
                  widget.suffix!,
                ],
              ],
            ),
          ),
        ),
        if (widget.maxLength != null && _len > 0.8 * widget.maxLength!) ...[
          const SizedBox(height: 4),
          Align(
            alignment: Alignment.centerRight,
            child: Text(
              '$_len/${widget.maxLength}',
              style: AppText.micro.copyWith(color: context.mutedText),
            ),
          ),
        ],
        if (hasError) ...[
          const SizedBox(height: 6),
          Row(
            children: [
              HugeIcon(
                icon: HugeIcons.strokeRoundedAlert02,
                color: context.dangerText,
                size: 14,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  widget.errorText!,
                  style: AppText.caption.copyWith(color: context.dangerText),
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }
}

/// Borderless text action with press feedback.
class EngramTextButton extends StatelessWidget {
  const EngramTextButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.color,
    this.icon,
  });
  final String label;
  final VoidCallback? onPressed;
  final Color? color;
  final dynamic icon;

  @override
  Widget build(BuildContext context) {
    return Tappable(
      scale: 0.96,
      onTap: onPressed,
      child: Container(
        constraints: const BoxConstraints(minHeight: 48),
        padding: const EdgeInsets.symmetric(horizontal: 16),
        alignment: Alignment.center,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              HugeIcon(
                icon: icon,
                color: context.accentText(color ?? blue),
                size: 18,
              ),
              const SizedBox(width: 8),
            ],
            Flexible(
              child: Text(
                label,
                style: AppText.body.copyWith(
                  color: context.accentText(color ?? blue),
                  fontWeight: FontWeight.w700,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Round back button; defaults to popping the current route.
class AppBackButton extends StatelessWidget {
  const AppBackButton({
    super.key,
    this.icon = HugeIcons.strokeRoundedArrowLeft01,
    this.onTap,
    this.semanticLabel,
    this.haptic = true,
  });
  final dynamic icon;
  final VoidCallback? onTap;
  final String? semanticLabel;
  final bool haptic;

  @override
  Widget build(BuildContext context) {
    return Tappable(
      scale: 0.92,
      haptic: haptic,
      semanticLabel: semanticLabel ?? tr('common_back'),
      onTap: onTap ?? () => Navigator.maybePop(context),
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: context.softBg,
        ),
        alignment: Alignment.center,
        child: HugeIcon(icon: icon, color: context.inkText, size: 22),
      ),
    );
  }
}

/// Centered 56px top bar that replaces AppBar.
class AppTopBar extends StatelessWidget implements PreferredSizeWidget {
  const AppTopBar({
    super.key,
    this.title,
    this.leading,
    this.actions = const [],
    this.showBack = true,
    this.bottom,
    this.backgroundColor,
  });
  final String? title;
  final Widget? leading;
  final List<Widget> actions;
  final bool showBack;
  final PreferredSizeWidget? bottom;
  final Color? backgroundColor;

  @override
  Size get preferredSize =>
      Size.fromHeight(56 + (bottom?.preferredSize.height ?? 0));

  @override
  Widget build(BuildContext context) {
    final canPop = Navigator.canPop(context);
    Widget? left;
    if (leading != null) {
      left = leading;
    } else if (showBack && canPop) {
      left = const AppBackButton();
    }
    return ColoredBox(
      color: backgroundColor ?? Theme.of(context).scaffoldBackgroundColor,
      child: SafeArea(
        bottom: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              height: 56,
              child: Row(
                children: [
                  SizedBox(
                    width: 56,
                    child: Center(child: left ?? const SizedBox.shrink()),
                  ),
                  Expanded(
                    child: title == null
                        ? const SizedBox.shrink()
                        : Text(
                            title!,
                            style: AppText.heading.copyWith(
                              color: context.inkText,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            textAlign: TextAlign.center,
                          ),
                  ),
                  ConstrainedBox(
                    constraints: const BoxConstraints(minWidth: 56),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: actions,
                    ),
                  ),
                ],
              ),
            ),
            bottom ?? const SizedBox.shrink(),
          ],
        ),
      ),
    );
  }
}

/// Transparent round icon button that replaces IconButton.
class AppIconButton extends StatelessWidget {
  const AppIconButton({
    super.key,
    required this.icon,
    required this.onTap,
    this.size = 44,
    this.color,
    this.semanticLabel,
  });
  final dynamic icon;
  final VoidCallback? onTap;
  final double size;
  final Color? color;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    return Tappable(
      scale: 0.9,
      onTap: onTap,
      semanticLabel: semanticLabel,
      child: Container(
        width: size,
        height: size,
        decoration: const BoxDecoration(shape: BoxShape.circle),
        alignment: Alignment.center,
        child: HugeIcon(
          icon: icon,
          color: color ?? context.inkText,
          size: size * 0.5,
        ),
      ),
    );
  }
}
