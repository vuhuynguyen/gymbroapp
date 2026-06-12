import 'package:flutter/material.dart';

import '../../core/theme/theme.dart';

enum GbButtonSeverity { primary, secondary, danger }

enum GbButtonVariant { filled, outlined, text }

enum GbButtonSize { sm, md, lg }

/// The design's primary action button (`GbButton`). Filled-primary uses the signature hero gradient
/// with a blue glow (Material's [FilledButton] can't paint a gradient, hence a custom build); also
/// covers secondary/danger and outlined/text variants, sizes, full-width, leading/trailing icons,
/// and a busy spinner. Use this for prominent CTAs; incidental buttons can use themed Material ones.
class GbButton extends StatelessWidget {
  const GbButton({
    required this.label,
    this.onPressed,
    this.icon,
    this.iconRight,
    this.severity = GbButtonSeverity.primary,
    this.variant = GbButtonVariant.filled,
    this.size = GbButtonSize.md,
    this.full = false,
    this.busy = false,
    super.key,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final IconData? iconRight;
  final GbButtonSeverity severity;
  final GbButtonVariant variant;
  final GbButtonSize size;
  final bool full;
  final bool busy;

  double get _height => switch (size) {
        GbButtonSize.lg => AppSizes.buttonHeightLg,
        GbButtonSize.sm => AppSizes.buttonHeightSm,
        GbButtonSize.md => AppSizes.buttonHeight,
      };

  double get _fontSize => switch (size) {
        GbButtonSize.lg => 16.5,
        GbButtonSize.sm => 13,
        GbButtonSize.md => 15,
      };

  @override
  Widget build(BuildContext context) {
    final gb = context.gb;
    final disabled = onPressed == null || busy;
    final outlined = variant == GbButtonVariant.outlined;
    final text = variant == GbButtonVariant.text;

    Color fg;
    Color? solidBg;
    Gradient? gradient;
    Color border = Colors.transparent;

    if (text) {
      fg = switch (severity) {
        GbButtonSeverity.danger => gb.danger,
        GbButtonSeverity.secondary => gb.grey600,
        GbButtonSeverity.primary => gb.primary600,
      };
    } else if (outlined) {
      fg = severity == GbButtonSeverity.primary ? gb.primary600 : gb.grey700;
      border =
          severity == GbButtonSeverity.primary ? gb.primary50 : gb.borderCard;
    } else {
      switch (severity) {
        case GbButtonSeverity.primary:
          gradient = GbColors.heroGradient;
          fg = Colors.white;
        case GbButtonSeverity.secondary:
          solidBg = gb.card;
          fg = gb.grey700;
          border = gb.borderCard;
        case GbButtonSeverity.danger:
          solidBg = gb.danger;
          fg = Colors.white;
      }
    }

    final labelStyle = TextStyle(
        fontSize: _fontSize,
        fontWeight: FontWeight.w800,
        letterSpacing: -0.15,
        color: fg);
    // `full` buttons fill + center (Flexible needs a bounded Row); compact buttons shrink-wrap
    // (MainAxisSize.min — never use Container alignment, which would expand under bounded parents).
    final rowChildren = busy
        ? [
            SizedBox(
              height: _fontSize + 4,
              width: _fontSize + 4,
              child: CircularProgressIndicator(strokeWidth: 2, color: fg),
            ),
          ]
        : [
            if (icon != null) ...[
              Icon(icon, size: _fontSize + 3, color: fg),
              const SizedBox(width: AppSpacing.xs)
            ],
            if (full)
              Flexible(
                  child: Text(label,
                      overflow: TextOverflow.ellipsis, style: labelStyle))
            else
              Text(label, style: labelStyle),
            if (iconRight != null) ...[
              const SizedBox(width: AppSpacing.xs),
              Icon(iconRight, size: _fontSize + 3, color: fg)
            ],
          ];

    return Opacity(
      opacity: disabled ? 0.5 : 1,
      child: Material(
        color: gradient != null
            ? Colors.transparent
            : (solidBg ?? Colors.transparent),
        shape: RoundedRectangleBorder(
          borderRadius: AppRadius.brSm,
          side: border == Colors.transparent
              ? BorderSide.none
              : BorderSide(color: border, width: AppSizes.border),
        ),
        clipBehavior: Clip.antiAlias,
        child: Ink(
          decoration: gradient != null
              ? BoxDecoration(
                  gradient: gradient,
                  borderRadius: AppRadius.brSm,
                  boxShadow: AppShadows.blueSm)
              : null,
          child: InkWell(
            onTap: disabled ? null : onPressed,
            child: SizedBox(
              height: _height,
              width: full ? double.infinity : null,
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: AppSpacing.md + 2),
                child: Row(
                  mainAxisSize: full ? MainAxisSize.max : MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: rowChildren,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Square icon button used on cards (live-session ⋯, etc.) — grey0 fill, hairline border.
/// [semanticLabel] is required (design a11y §: "icon-only buttons require a Semantics label").
class GbIconButton extends StatelessWidget {
  const GbIconButton({
    required this.icon,
    required this.onTap,
    required this.semanticLabel,
    this.size = 36,
    this.fill,
    super.key,
  });
  final IconData icon;
  final VoidCallback onTap;
  final String semanticLabel;
  final double size;

  /// Background fill. Defaults to the card-on-card [grey0] tint; pass [card] to sit flush on a white
  /// surface (e.g. next to an outlined-secondary button so the two read as a matched pair).
  final Color? fill;

  @override
  Widget build(BuildContext context) {
    final gb = context.gb;
    return Semantics(
      button: true,
      label: semanticLabel,
      child: Material(
        color: fill ?? gb.grey0,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(9),
            side: BorderSide(color: gb.borderCard)),
        child: InkWell(
          borderRadius: BorderRadius.circular(9),
          onTap: onTap,
          child: SizedBox(
            width: size,
            height: size,
            child: Icon(icon, size: AppSizes.iconXl, color: gb.grey700),
          ),
        ),
      ),
    );
  }
}

/// Circular translucent "glass" button for gradient headers (live-session X, etc.).
/// [semanticLabel] is required (design a11y §: "icon-only buttons require a Semantics label").
class GbGlassButton extends StatelessWidget {
  const GbGlassButton(
      {required this.icon,
      required this.onTap,
      required this.semanticLabel,
      super.key});
  final IconData icon;
  final VoidCallback onTap;
  final String semanticLabel;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: semanticLabel,
      child: Material(
        color: Colors.white.withValues(alpha: 0.16),
        shape: CircleBorder(
            side: BorderSide(color: Colors.white.withValues(alpha: 0.25))),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onTap,
          child: SizedBox(
              width: 40,
              height: 40,
              child: Icon(icon, size: AppSizes.iconXl, color: Colors.white)),
        ),
      ),
    );
  }
}
