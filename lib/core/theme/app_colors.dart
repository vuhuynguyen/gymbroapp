import 'package:flutter/material.dart';

import '../tokens/app_shadows.dart';
import 'app_palette.dart';

/// Semantic color tokens exposed through the theme. Read with
/// `Theme.of(context).extension<GbColors>()!` for the shades Material's [ColorScheme] doesn't
/// carry (greys, status soft-tints, athletic accents) plus the signature gradients.
///
/// Kept as a single immutable instance ([GbColors.light]) — GymBro mobile is light-only, so
/// [copyWith]/[lerp] are identity (the design system is fixed, not animated between schemes).
@immutable
class GbColors extends ThemeExtension<GbColors> {
  const GbColors({
    required this.primary0,
    required this.primary25,
    required this.primary50,
    required this.primary500,
    required this.primary600,
    required this.primary700,
    required this.primary800,
    required this.secondary0,
    required this.secondary300,
    required this.success,
    required this.success0,
    required this.success50,
    required this.warning,
    required this.warning0,
    required this.warning200,
    required this.warning300,
    required this.danger,
    required this.danger0,
    required this.planTag,
    required this.adhocTag,
    required this.grey0,
    required this.grey25,
    required this.grey400,
    required this.grey500,
    required this.grey600,
    required this.grey700,
    required this.grey900,
    required this.borderCard,
    required this.borderField,
    required this.canvas,
    required this.card,
    required this.ink,
    required this.inkSoft,
    required this.emerald,
    required this.emeraldSoft,
    required this.emeraldInk,
    required this.amber,
    required this.amberSoft,
    required this.amberInk,
    required this.progInk,
    required this.progInk2,
    required this.progInk3,
    required this.progInk4,
    required this.progPaper,
    required this.progCard2,
    required this.progLine,
    required this.progLine2,
    required this.progField,
    required this.progBrandSoft,
    required this.progBrandInk,
    required this.progRing,
    required this.progPos,
    required this.progWarn,
    required this.progNeg,
    required this.progHeat0,
    required this.progHeat1,
    required this.progHeat2,
    required this.progHeat3,
    required this.progHeat4,
  });

  final Color primary0, primary25, primary50, primary500, primary600, primary700, primary800;
  final Color secondary0, secondary300;
  final Color success, success0, success50;
  final Color warning, warning0, warning200, warning300;
  final Color danger, danger0;
  final Color planTag, adhocTag;
  final Color grey0, grey25, grey400, grey500, grey600, grey700, grey900;
  final Color borderCard, borderField;

  // Athletic-premium polish layer (`--gb-*`).
  final Color canvas, card, ink, inkSoft;
  final Color emerald, emeraldSoft, emeraldInk;
  final Color amber, amberSoft, amberInk;

  // Progress "Graphite / premium-blue" layer (gb-tokens.css) — the Progress
  // tab's own visual system. Navy ink ramp, cool layered surfaces, honest deep
  // pos/warn/neg (on text only), a single-hue blue heatmap ramp. Light-only
  // (the app is light-only; the design's `.gb-dark` variant is not populated).
  final Color progInk, progInk2, progInk3, progInk4;
  final Color progPaper, progCard2, progLine, progLine2, progField;
  final Color progBrandSoft, progBrandInk, progRing;
  final Color progPos, progWarn, progNeg;
  final Color progHeat0, progHeat1, progHeat2, progHeat3, progHeat4;

  /// The 5-step blue heatmap ramp as a list (heat0→heat4), for index lookup.
  List<Color> get progHeatRamp =>
      [progHeat0, progHeat1, progHeat2, progHeat3, progHeat4];

  /// Signature 3-stop hero gradient (`--gb-hero`, ~150deg) — Log/Plan heroes, live header, CTAs.
  static const LinearGradient heroGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [AppPalette.heroA, AppPalette.heroB, AppPalette.heroC],
    stops: [0.0, 0.52, 1.0],
  );

  /// Deep-navy gradient (`--gb-hero-deep`) — live-session rest bar.
  static const LinearGradient heroDeepGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [AppPalette.heroDeepA, AppPalette.heroDeepB],
  );

  /// Progress-tab signature hero panel (`--hero-bg`, 156deg) — the "This week"
  /// dark panel. A subtly deeper, tonal-navy take on [heroGradient] tuned to the
  /// Graphite system (3 stops at 0 / 58% / 100%).
  static const LinearGradient progressHeroGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [AppPalette.progHeroA, AppPalette.progHeroB, AppPalette.progHeroC],
    stops: [0.0, 0.58, 1.0],
  );

  /// Mint→white progress-bar fill (hero/live progress).
  static const LinearGradient progressFill =
      LinearGradient(colors: [AppPalette.mint, Colors.white]);

  // Shadow getters — delegate to [AppShadows] so call-sites read `gb.cardShadow` etc.
  List<BoxShadow> get cardShadow => AppShadows.card;
  List<BoxShadow> get blueShadow => AppShadows.blue;
  List<BoxShadow> get blueShadowSm => AppShadows.blueSm;

  static const light = GbColors(
    primary0: AppPalette.primary0,
    primary25: AppPalette.primary25,
    primary50: AppPalette.primary50,
    primary500: AppPalette.primary500,
    primary600: AppPalette.primary600,
    primary700: AppPalette.primary700,
    primary800: AppPalette.primary800,
    secondary0: AppPalette.secondary0,
    secondary300: AppPalette.secondary300,
    success: AppPalette.success300,
    success0: AppPalette.success0,
    success50: AppPalette.success50,
    warning: AppPalette.warning100,
    warning0: AppPalette.warning0,
    warning200: AppPalette.warning200,
    warning300: AppPalette.warning300,
    danger: AppPalette.error100,
    danger0: AppPalette.error0,
    planTag: AppPalette.primary700,
    adhocTag: AppPalette.warning200,
    grey0: AppPalette.grey0,
    grey25: AppPalette.grey25,
    grey400: AppPalette.grey400,
    grey500: AppPalette.grey500,
    grey600: AppPalette.grey600,
    grey700: AppPalette.grey700,
    grey900: AppPalette.grey900,
    borderCard: AppPalette.borderCard,
    borderField: AppPalette.borderField,
    canvas: AppPalette.canvas,
    card: AppPalette.surface,
    ink: AppPalette.ink,
    inkSoft: AppPalette.inkSoft,
    emerald: AppPalette.emerald,
    emeraldSoft: AppPalette.emeraldSoft,
    emeraldInk: AppPalette.emeraldInk,
    amber: AppPalette.amber,
    amberSoft: AppPalette.amberSoft,
    amberInk: AppPalette.amberInk,
    progInk: AppPalette.progInk,
    progInk2: AppPalette.progInk2,
    progInk3: AppPalette.progInk3,
    progInk4: AppPalette.progInk4,
    progPaper: AppPalette.progPaper,
    progCard2: AppPalette.progCard2,
    progLine: AppPalette.progLine,
    progLine2: AppPalette.progLine2,
    progField: AppPalette.progField,
    progBrandSoft: AppPalette.progBrandSoft,
    progBrandInk: AppPalette.progBrandInk,
    progRing: AppPalette.progRing,
    progPos: AppPalette.progPos,
    progWarn: AppPalette.progWarn,
    progNeg: AppPalette.progNeg,
    progHeat0: AppPalette.progHeat0,
    progHeat1: AppPalette.progHeat1,
    progHeat2: AppPalette.progHeat2,
    progHeat3: AppPalette.progHeat3,
    progHeat4: AppPalette.progHeat4,
  );

  @override
  GbColors copyWith() => this;

  @override
  GbColors lerp(ThemeExtension<GbColors>? other, double t) => this;
}

/// Ergonomic `context.gb` accessor for the [GbColors] extension.
extension GbColorsContext on BuildContext {
  GbColors get gb => Theme.of(this).extension<GbColors>()!;
}
