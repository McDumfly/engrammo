import 'package:flutter/material.dart';

import '../services/app_feedback.dart';

import 'package:hugeicons/hugeicons.dart';

import '../theme/app_colors.dart' show coral, blue;
import '../theme/app_theme.dart';

/// AZ APP GOMBSZABÁLYA (döntés, 2026-10, végleges: pill + lapos).
/// Minden fontos gomb ebből a fájlból jön, új kódban mindig ezeket használd.
/// A Material-gombok (Elevated/Filled/Outlined) a pill formát témából
/// kapják ([AppTheme.buttonShape]), ezért új gombhoz soha nem kell
/// `shape`-et írni.
///
/// 1. Forma: minden feliratos gomb teljesen lekerekített pill
///    (Stadium, nem szögletes). Az ikon-only gombok körok —
///    ez geometriailag ugyanaz (1:1-es pill): egyetlen ikon
///    ovális pillben szétcsúszna, ezért a fejléc-ikonok
///    (memóriatípus-választó, vissza, beállítás, megosztás,
///    avatar-pipa) tudatosan körök, nem kimaradt munka.
/// 2. Lapos: minden gomb direkt lapos, nincs 3D-s alsó sáv. A vastag
///    alsó árnyéksáv idegen márkajegy lenne, ezért direkt nem
///    használjuk sehol.
/// 3. Készlet:
///    - [EngramButton]: nagy CTA (teljes szélesség, 60 magas).
///    - [EngramMiniButton]: kis inline akció (Invite, Watch, ...).
///    - [EngramIconButton] / [EngramBackButton]: ikon-only, lapos kör.
/// 4. Kivétel kettő: TextButton szöveges link (nincs háttere),
///    és az ikon-only kör (1. pont). Dialógus-actions és
///    FloatingActionButton is pill.
/// 5. Nem gomb → nem gombforma: kártyák, panelek, dialógusok,
///    inputmezők, jelvények (badge-ek), progress-sávok,
///    játéktábla-cellák maradnak a saját 8-24-es radiusszal.
/// 6. Rezgés: a gombok maguktól adnak egy könnyű rezgést, a kezelő
///    ehhez már nem rezegtet. Ha a kezelő saját, erősebb jelzést
///    ad, a gomb `haptic: false`-t kap — egy koppintás, egy rezgés.
///
/// - [EngramButtonVariant.primary]: app-kék lapos pill gomb (fő cselekvés).
/// - [EngramButtonVariant.secondary]: fehér lapos pill gomb (mellékes cselekvés).
/// - [EngramButtonVariant.danger]: piros lapos pill gomb (törlés, kilépés).
/// - `onPressed: null` esetén mindegyikből szürke, nyomhatatlan
///   (disabled) állapot lesz.
/// - [isLoading] esetén töltőpötty forog a felirat helyén.
enum EngramButtonVariant { primary, secondary, danger }

class EngramButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final EngramButtonVariant variant;
  final bool isLoading;
  final dynamic icon;

  /// Egyedi bevezető widget az [icon] helyett — pl. a színes Google „G"
  /// logó, ami nem HugeIcon, ezért nem fér bele az [icon] paraméterbe.
  /// Ha meg van adva, az [icon]-t figyelmen kívül hagyja.
  final Widget? leading;

  /// Koppintáskor a gomb ad egy könnyű rezgést. Ha a kezelő saját,
  /// erősebb visszajelzést ad (pl. medium találatjelzés), tedd
  /// `false`-ra, hogy ne legyen dupla rezgés.
  final bool haptic;

  const EngramButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.variant = EngramButtonVariant.primary,
    this.isLoading = false,
    this.icon,
    this.leading,
    this.haptic = true,
  });

  bool get _disabled => onPressed == null && !isLoading;

  Color _top(BuildContext context) {
    if (_disabled) {
      // Sötétben sötét lap, világosban a régi szürke.
      return context.isDark ? context.faintBg : const Color(0xFFD7E0EC);
    }
    switch (variant) {
      case EngramButtonVariant.primary:
        return blue;
      case EngramButtonVariant.secondary:
        return context.cardBg;
      case EngramButtonVariant.danger:
        return coral;
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
    return GestureDetector(
      onTap: tappable
          ? () {
              if (haptic) AppFeedback.light();
              onPressed?.call();
            }
          : null,
      child: Container(
        height: 60,
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
                ],
              ),
      ),
    );
  }
}

/// Kis inline lapos pill gomb (pl. battle képernyő Invite / Watch).
///
/// A nagy [EngramButton] kistestvére: ugyanaz a lapos pill forma,
/// csak kompakt méretben, sorokba, kártyák mellé.
/// `onTap: null` esetén szürke, nyomhatatlan állapot lesz.
class EngramMiniButton extends StatelessWidget {
  final String label;
  final VoidCallback? onTap;
  final Color? background;
  // Régi 3D-sáv színe: már nincs használva, csak a hívók
  // kompatibilitása miatt maradt meg a paraméter.
  final Color? shadowColor;

  /// Koppintáskor a gomb ad egy könnyű rezgést. Ha a kezelő saját
  /// visszajelzést ad, tedd `false`-ra, hogy ne legyen dupla rezgés.
  final bool haptic;

  const EngramMiniButton({
    super.key,
    required this.label,
    required this.onTap,
    this.background,
    this.shadowColor,
    this.haptic = true,
  });

  @override
  Widget build(BuildContext context) {
    final disabled = onTap == null;
    final top =
        background ??
        (context.isDark ? context.faintBg : const Color(0xFFD7E0EC));
    return GestureDetector(
      onTap: disabled
          ? null
          : () {
              if (haptic) AppFeedback.light();
              onTap?.call();
            },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: top,
          borderRadius: BorderRadius.circular(999),
        ),
        alignment: Alignment.center,
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
    );
  }
}

/// Komoly, egységes vissza gomb hugeicons-szal.
///
/// Minden visszalépéshez ezt használjuk az appban: AppBar `leading`
/// pozícióban sima ikon módban (`boxed: false`), egyedi fejlécekben
/// pedig lapos kör módban (`boxed: true`). Modális bezáráshoz
/// (pl. avatar szerkesztő) az [EngramBackButton.close] ad X jelet
/// ugyanabban a kör formában.
class EngramBackButton extends StatelessWidget {
  final VoidCallback? onPressed;
  final bool boxed;
  final List<List<dynamic>> icon;

  /// Koppintáskor a gomb ad egy könnyű rezgést. Ha a kezelő saját
  /// visszajelzést ad, tedd `false`-ra, hogy ne legyen dupla rezgés.
  final bool haptic;

  const EngramBackButton({
    super.key,
    this.onPressed,
    this.boxed = false,
    this.icon = HugeIcons.strokeRoundedArrowLeft01,
    this.haptic = true,
  });

  const EngramBackButton.close({
    super.key,
    this.onPressed,
    this.boxed = true,
    this.icon = HugeIcons.strokeRoundedCancel01,
    this.haptic = true,
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
    if (!boxed) {
      return IconButton(icon: glyph, onPressed: tap);
    }
    return GestureDetector(
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
    );
  }
}

/// Kör alakú lapos ikongomb (pl. megosztás, avatar-pipa,
/// memóriatípus-választó) — 1:1-es pill, tehát geometriailag kör.
///
/// Alapból kártya-színű, keretes — töltött változathoz add meg
/// a [background]-ot (pl. blue pipa): ilyenkor keret nélkül,
/// fehér ikonnal jelenik meg ugyanabban a lapos kör formában.
/// [isLoading] esetén töltőpötty forog az ikon helyén.
class EngramIconButton extends StatelessWidget {
  final dynamic icon;
  final VoidCallback? onTap;
  final double size;
  final Color? background;
  final Color? foreground;
  // Régi 3D-sáv színe: már nincs használva, csak a hívók
  // kompatibilitása miatt maradt meg a paraméter.
  final Color? shadowColor;
  final bool isLoading;

  /// Koppintáskor a gomb ad egy könnyű rezgést. Ha a kezelő saját
  /// visszajelzést ad, tedd `false`-ra, hogy ne legyen dupla rezgés.
  final bool haptic;

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
    return GestureDetector(
      onTap: disabled
          ? null
          : () {
              if (haptic) AppFeedback.light();
              onTap?.call();
            },
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: top,
          shape: BoxShape.circle,
          border: filled ? null : Border.all(color: context.hairline, width: 2),
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
    );
  }
}
