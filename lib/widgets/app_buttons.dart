import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../services/app_feedback.dart';

import 'package:hugeicons/hugeicons.dart';

import '../theme/app_colors.dart' show blueDark, blueShadow, coralDark;
import '../theme/app_theme.dart';
import 'app_kit.dart';

enum EngramButtonVariant { primary, secondary, danger }

class EngramButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final EngramButtonVariant variant;
  final bool isLoading;
  final dynamic icon;

  final Widget? leading;

  final bool haptic;

  final double height;

  final String? semanticsLabel;

  const EngramButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.variant = EngramButtonVariant.primary,
    this.isLoading = false,
    this.icon,
    this.leading,
    this.haptic = true,
    this.height = 60,
    this.semanticsLabel,
  });

  bool get _disabled => onPressed == null && !isLoading;

  Color _top(BuildContext context) {
    if (_disabled) {
      return context.isDark ? context.faintBg : const Color(0xFFD7E0EC);
    }
    switch (variant) {
      case EngramButtonVariant.primary:
        return blueDark;
      case EngramButtonVariant.secondary:
        return context.cardBg;
      case EngramButtonVariant.danger:
        return coralDark;
    }
  }

  Color _label(BuildContext context) {
    // Letiltva világos módban sötét felirat kell: a fehér a halvány
    // szürke háttéren olvashatatlan lenne.
    // Sötétben is halvány: a tiszta fehér felirat aktív gombnak tűnne.
    if (_disabled) {
      return context.isDark
          ? Colors.white.withValues(alpha: 0.38)
          : context.mutedText;
    }
    return variant == EngramButtonVariant.secondary
        ? context.inkText
        : Colors.white;
  }

  @override
  Widget build(BuildContext context) {
    final tappable = !_disabled && !isLoading;
    final top = _top(context);
    final labelColor = _label(context);
    final minTap = height < 48 ? 48.0 : height;
    final visual = Container(
      constraints: BoxConstraints(minHeight: minTap),
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      decoration: BoxDecoration(
        color: top,
        borderRadius: BorderRadius.circular(999),
        border: variant == EngramButtonVariant.secondary && !_disabled
            ? Border.all(color: context.hairline, width: 2)
            : null,
      ),
      alignment: Alignment.center,
      child: isLoading
          ? AppLoader(size: 22, stroke: 2.5, color: labelColor, instant: true)
          : Row(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (leading != null) ...[
                  leading!,
                  const SizedBox(width: 8),
                ] else if (icon != null) ...[
                  HugeIcon(
                    icon: icon,
                    color: labelColor,
                    size: 22,
                    strokeWidth: 2.2,
                  ),
                  const SizedBox(width: 8),
                ],
                Flexible(
                  child: ExcludeSemantics(
                    child: Text(
                      label,
                      style: TextStyle(
                        color: labelColor,
                        fontWeight: FontWeight.w900,
                        fontSize: 17,
                        letterSpacing: 0,
                        height: 1.25,
                      ),
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
              ],
            ),
    );
    final VoidCallback? tap = tappable
        ? () {
            if (haptic) AppFeedback.light();
            onPressed?.call();
          }
        : null;
    Widget wrapped;
    if (tap == null) {
      wrapped = variant == EngramButtonVariant.secondary
          ? visual
          : Padding(padding: const EdgeInsets.only(bottom: 4), child: visual);
    } else if (variant == EngramButtonVariant.secondary) {
      wrapped = Tappable(
        scale: 0.97,
        haptic: false,
        semanticLabel: semanticsLabel ?? label,
        onTap: tap,
        child: visual,
      );
    } else {
      wrapped = EngramPress3D(
        onTap: tap,
        top: visual,
        shadowColor: variant == EngramButtonVariant.danger
            ? const Color(0xFF8E1414)
            : blueShadow,
        depth: 4,
        borderRadius: BorderRadius.circular(999),
        haptic: false,
        semanticLabel: semanticsLabel ?? label,
      );
    }
    return Semantics(
      button: true,
      enabled: tappable,
      label: semanticsLabel ?? label,
      child: wrapped,
    );
  }
}

/// Nyomásra lesüllyedő, felengedésre visszaugró 3D-s gomb.
///
/// Korlátolt magasságú szülőben (pl. fix `SizedBox`) kitölti a helyet,
/// korlátlanban (pl. `Column`/`ListView` gyereke) a `top` tartalmából
/// méretezi magát. Ilyenkor a `top` legyen önálló magasságú
/// (ne `Expanded`), ahogy minden tartalomméretes gomb.
class EngramPress3D extends StatefulWidget {
  final VoidCallback onTap;
  final Widget top;
  final Color shadowColor;
  final double depth;
  final BorderRadius borderRadius;
  final bool haptic;
  final String? semanticLabel;
  final BoxBorder? shadowBorder;
  final Duration pressDuration;
  final Duration releaseDuration;
  final Duration minDuration;

  const EngramPress3D({
    super.key,
    required this.onTap,
    required this.top,
    required this.shadowColor,
    this.depth = 4,
    this.borderRadius = const BorderRadius.all(Radius.circular(18)),
    this.haptic = true,
    this.semanticLabel,
    this.shadowBorder,
    this.pressDuration = const Duration(milliseconds: 90),
    this.releaseDuration = const Duration(milliseconds: 90),
    this.minDuration = const Duration(milliseconds: 30),
  });

  @override
  State<EngramPress3D> createState() => _EngramPress3DState();
}

class _EngramPress3DState extends State<EngramPress3D> {
  bool _pressed = false;
  late Duration _duration;
  DateTime? _downTime;
  DateTime? _upTime;

  @override
  void initState() {
    super.initState();
    _duration = widget.pressDuration;
  }

  Duration _scaled(Duration base, int elapsedMs) {
    if (elapsedMs >= base.inMilliseconds) return base;
    if (elapsedMs <= 0) return widget.minDuration;
    final scaled = (base.inMicroseconds * elapsedMs / base.inMilliseconds)
        .round();
    final clamped = scaled.clamp(
      widget.minDuration.inMicroseconds,
      base.inMicroseconds,
    );
    return Duration(microseconds: clamped);
  }

  void _down(TapDownDetails _) {
    final now = DateTime.now();
    final lastUp = _upTime;
    var dur = widget.pressDuration;
    if (lastUp != null) {
      dur = _scaled(
        widget.pressDuration,
        now.difference(lastUp).inMilliseconds,
      );
    }
    _downTime = now;
    _duration = dur;
    if (!_pressed) setState(() => _pressed = true);
    if (widget.haptic) AppFeedback.light();
  }

  void _release() {
    final now = DateTime.now();
    final down = _downTime;
    var dur = widget.releaseDuration;
    if (down != null) {
      dur = _scaled(
        widget.releaseDuration,
        now.difference(down).inMilliseconds,
      );
    }
    _upTime = now;
    _downTime = null;
    _duration = dur;
    if (_pressed) setState(() => _pressed = false);
  }

  void _up(TapUpDetails _) => _release();

  void _cancel() => _release();

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: widget.semanticLabel,
      child: GestureDetector(
        onTapDown: _down,
        onTapUp: _up,
        onTapCancel: _cancel,
        onTap: widget.onTap,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final shadow = Positioned(
              top: widget.depth,
              left: 0,
              right: 0,
              bottom: 0,
              child: Container(
                decoration: BoxDecoration(
                  color: widget.shadowColor,
                  borderRadius: widget.borderRadius,
                  border: widget.shadowBorder,
                ),
              ),
            );
            if (constraints.maxHeight.isFinite) {
              return Stack(
                children: [
                  shadow,
                  AnimatedPositioned(
                    duration: _duration,
                    curve: Curves.easeOut,
                    top: _pressed ? widget.depth : 0,
                    left: 0,
                    right: 0,
                    bottom: _pressed ? 0 : widget.depth,
                    child: widget.top,
                  ),
                ],
              );
            }
            return Container(
              decoration: BoxDecoration(
                color: widget.shadowColor,
                borderRadius: widget.borderRadius,
                border: widget.shadowBorder,
              ),
              child: AnimatedPadding(
                duration: _duration,
                curve: Curves.easeOut,
                padding: EdgeInsets.only(
                  top: _pressed ? widget.depth : 0,
                  bottom: _pressed ? 0 : widget.depth,
                ),
                child: widget.top,
              ),
            );
          },
        ),
      ),
    );
  }
}

class EngramMiniButton extends StatelessWidget {
  final String label;
  final VoidCallback? onTap;
  final Color? background;

  final bool haptic;

  final String? semanticsLabel;

  const EngramMiniButton({
    super.key,
    required this.label,
    required this.onTap,
    this.background,
    this.haptic = true,
    this.semanticsLabel,
  });

  @override
  Widget build(BuildContext context) {
    final disabled = onTap == null;
    final top =
        background ??
        (context.isDark ? context.faintBg : const Color(0xFFD7E0EC));
    return Semantics(
      button: true,
      enabled: !disabled,
      label: semanticsLabel ?? label,
      child: GestureDetector(
        onTap: disabled
            ? null
            : () {
                if (haptic) AppFeedback.light();
                onTap?.call();
              },
        child: Container(
          constraints: const BoxConstraints(minHeight: 48, minWidth: 48),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: top,
            borderRadius: BorderRadius.circular(999),
          ),
          alignment: Alignment.center,
          child: ExcludeSemantics(
            child: Text(
              label,
              style: TextStyle(
                color: background != null
                    ? Colors.white
                    : (context.isDark ? Colors.white : context.inkText),
                fontWeight: FontWeight.w800,
                fontSize: 12,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ),
      ),
    );
  }
}

class EngramBackButton extends StatelessWidget {
  final VoidCallback? onPressed;
  final bool boxed;
  final List<List<dynamic>> icon;

  final bool haptic;

  final String? semanticLabel;
  final bool closeVariant;

  const EngramBackButton({
    super.key,
    this.onPressed,
    this.boxed = false,
    this.icon = HugeIcons.strokeRoundedArrowLeft01,
    this.haptic = true,
    this.semanticLabel,
    this.closeVariant = false,
  });

  const EngramBackButton.close({
    super.key,
    this.onPressed,
    this.boxed = true,
    this.icon = HugeIcons.strokeRoundedCancel01,
    this.haptic = true,
    this.semanticLabel,
    this.closeVariant = true,
  });

  @override
  Widget build(BuildContext context) {
    // All variants now render the kit back button; the old boxed size,
    // button widget and hover hint are gone.
    return AppBackButton(
      icon: icon,
      onTap: onPressed,
      semanticLabel:
          semanticLabel ?? tr(closeVariant ? 'common_close' : 'common_back'),
      haptic: haptic,
    );
  }
}

class EngramIconButton extends StatelessWidget {
  final dynamic icon;
  final VoidCallback? onTap;
  final double size;
  final Color? background;
  final Color? foreground;
  final bool isLoading;

  final bool haptic;

  final String? semanticLabel;

  const EngramIconButton({
    super.key,
    required this.icon,
    required this.onTap,
    this.size = 60,
    this.background,
    this.foreground,
    this.isLoading = false,
    this.haptic = true,
    this.semanticLabel,
  });

  @override
  Widget build(BuildContext context) {
    final disabled = onTap == null && !isLoading;
    final filled = background != null;
    final top =
        background ??
        (disabled
            ? (context.isDark ? context.faintBg : const Color(0xFFD7E0EC))
            : context.cardBg);
    final glyphColor =
        foreground ??
        (disabled
            ? (context.isDark ? Colors.white : context.mutedText)
            : filled
            ? Colors.white
            : context.inkText);
    final minTap = size < 48 ? 48.0 : size;
    return Semantics(
      button: true,
      enabled: !disabled,
      label: semanticLabel,
      child: GestureDetector(
        onTap: disabled
            ? null
            : () {
                if (haptic) AppFeedback.light();
                onTap?.call();
              },
        child: Container(
          width: minTap,
          height: minTap,
          decoration: BoxDecoration(
            color: top,
            shape: BoxShape.circle,
            border: filled
                ? null
                : Border.all(color: context.hairline, width: 2),
          ),
          alignment: Alignment.center,
          child: isLoading
              ? AppLoader(
                  size: 20,
                  stroke: 2.5,
                  color: glyphColor,
                  instant: true,
                )
              : HugeIcon(
                  icon: icon,
                  color: glyphColor,
                  size: 22,
                  strokeWidth: 2.2,
                ),
        ),
      ),
    );
  }
}
