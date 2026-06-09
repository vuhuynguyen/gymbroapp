/// Sizing tokens — icon sizes, hairline/border widths, and recurring control dimensions from the
/// prototype. Keeps icon scale and component heights consistent instead of per-call magic numbers.
abstract final class AppSizes {
  AppSizes._();

  // ── Icon sizes ──────────────────────────────────────────────────────────
  static const double iconXs = 12;
  static const double iconSm = 14;
  static const double iconMd = 16;
  static const double iconLg = 18;
  static const double iconXl = 20;
  static const double iconXxl = 24;

  // ── Borders ──────────────────────────────────────────────────────────────
  static const double hairline = 1;
  static const double border = 1.5;

  // ── Controls ───────────────────────────────────────────────────────────
  /// Standard button height (`md`).
  static const double buttonHeight = 48;

  /// Large CTA height (`lg` — Resume, Log set, Join).
  static const double buttonHeightLg = 54;

  /// Compact button height (`sm`).
  static const double buttonHeightSm = 38;

  /// Pill chip height (filters, day chips, pager).
  static const double chipHeight = 36;

  /// Day/weekday status badge square.
  static const double dayBadge = 44;

  /// Stepper +/- button square.
  static const double stepperButton = 40;
}
