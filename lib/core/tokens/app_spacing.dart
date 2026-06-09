/// Spacing scale — a 1:1 port of the design `--inv-space-*` ramp (tokens.css), expressed in
/// logical pixels. One source of truth for gaps, padding, and insets; screens reference these
/// instead of magic numbers.
abstract final class AppSpacing {
  AppSpacing._();

  /// 4 — `--inv-space-1`
  static const double xxs = 4;

  /// 8 — `--inv-space-2`
  static const double xs = 8;

  /// 12 — `--inv-space-3`
  static const double sm = 12;

  /// 16 — `--inv-space-4`
  static const double md = 16;

  /// 24 — `--inv-space-5`
  static const double lg = 24;

  /// 32 — `--inv-space-6`
  static const double xl = 32;

  /// 40 — `--inv-space-7`
  static const double xxl = 40;

  /// 48 — `--inv-space-8`
  static const double xxxl = 48;

  // ── Semantic layout constants (recurring in the prototype) ──────────────
  /// Default horizontal screen gutter.
  static const double screenH = 16;

  /// Default vertical rhythm between stacked cards/sections.
  static const double gap = 14;

  /// Inner padding of standard content cards.
  static const double cardPad = 16;

  /// Inner padding of the gradient hero cards.
  static const double heroPad = 18;
}
