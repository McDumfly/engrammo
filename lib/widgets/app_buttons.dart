import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../services/app_feedback.dart';

import 'package:hugeicons/hugeicons.dart';

import '../theme/app_colors.dart' show blueDark, coralDark;
import '../theme/app_theme.dart';

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
    if (_disabled) return Colors.white;
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
    return Semantics(
      button: true,
      enabled: tappable,
      label: semanticsLabel ?? label,
      child: GestureDetector(
        onTap: tappable
            ? () {
                if (haptic) AppFeedback.light();
                onPressed?.call();
              }
            : null,
        child: Container(
          height: minTap,
          width: double.infinity,
          decoration: BoxDecoration(
            color: top,
            borderRadius: BorderRadius.circular(999),
            border: variant == EngramButtonVariant.secondary && !_disabled
                ? Border.all(color: context.hairline, width: 2)
                : null,
          ),
          alignment: Alignment.center,
          child: isLoading
              ? SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.5,
                    color: labelColor,
                  ),
                )
              : Row(
                  mainAxisSize: MainAxisSize.min,
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
                            letterSpacing: 0.5,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}

class EngramPress3D extends StatefulWidget {
  final VoidCallback onTap;
  final Widget top;
  final Color shadowColor;
  final double depth;
  final BorderRadius borderRadius;
  final bool haptic;
  final String? semanticLabel;

  const EngramPress3D({
    super.key,
    required this.onTap,
    required this.top,
    required this.shadowColor,
    this.depth = 4,
    this.borderRadius = const BorderRadius.all(Radius.circular(18)),
    this.haptic = true,
    this.semanticLabel,
  });

  @override
  State<EngramPress3D> createState() => _EngramPress3DState();
}

class _EngramPress3DState extends State<EngramPress3D> {
  bool _pressed = false;

  void _down(TapDownDetails _) {
    if (!_pressed) setState(() => _pressed = true);
    if (widget.haptic) AppFeedback.light();
  }

  void _up(TapUpDetails _) {
    if (_pressed) setState(() => _pressed = false);
  }

  void _cancel() {
    if (_pressed) setState(() => _pressed = false);
  }

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
        child: Stack(
          children: [
            Positioned(
              top: widget.depth,
              left: 0,
              right: 0,
              bottom: 0,
              child: Container(
                decoration: BoxDecoration(
                  color: widget.shadowColor,
                  borderRadius: widget.borderRadius,
                ),
              ),
            ),
            AnimatedPositioned(
              duration: const Duration(milliseconds: 90),
              curve: Curves.easeOut,
              top: _pressed ? widget.depth : 0,
              left: 0,
              right: 0,
              bottom: _pressed ? 0 : widget.depth,
              child: widget.top,
            ),
          ],
        ),
      ),
    );
  }
}

class EngramMiniButton extends StatelessWidget {
  final String label;
  final VoidCallback? onTap;
  final Color? background;
  final Color? shadowColor;

  final bool haptic;

  final String? semanticsLabel;

  const EngramMiniButton({
    super.key,
    required this.label,
    required this.onTap,
    this.background,
    this.shadowColor,
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
              style: const TextStyle(
                color: Colors.white,
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
    void tap() {
      if (haptic) AppFeedback.light();
      if (onPressed != null) {
        onPressed!();
      } else {
        Navigator.of(context).pop();
      }
    }

    final glyph = HugeIcon(
      icon: icon,
      color: context.inkText,
      size: 30,
      strokeWidth: 2.5,
    );
    final label =
        semanticLabel ?? tr(closeVariant ? 'common_close' : 'common_back');
    if (!boxed) {
      return Semantics(
        button: true,
        label: label,
        onTap: tap,
        child: ExcludeSemantics(
          child: IconButton(
            icon: glyph,
            onPressed: tap,
            tooltip: label,
          ),
        ),
      );
    }
    return Semantics(
      button: true,
      label: label,
      child: GestureDetector(
        onTap: tap,
        child: Container(
          width: 58,
          height: 58,
          decoration: BoxDecoration(
            color: context.cardBg,
            shape: BoxShape.circle,
            border: Border.all(color: context.hairline, width: 2),
          ),
          alignment: Alignment.center,
          child: glyph,
        ),
      ),
    );
  }
}

class EngramIconButton extends StatelessWidget {
  final dynamic icon;
  final VoidCallback? onTap;
  final double size;
  final Color? background;
  final Color? foreground;
  final Color? shadowColor;
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
    this.shadowColor,
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
            ? Colors.white
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
              ? SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.5,
                    color: glyphColor,
                  ),
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
