import 'package:flutter/widgets.dart';

/// Corner-radius scale — the design's `--gb-r-*` (rounder premium layer) plus the pill constant.
/// Cards use [md], hero/large surfaces [lg], buttons/fields [sm], full pills [pill].
abstract final class AppRadius {
  AppRadius._();

  /// 12 — buttons, fields, small surfaces (`--gb-r-sm`).
  static const double sm = 12;

  /// 16 — standard cards, sheets-inner, current-set card (`--gb-r-md`).
  static const double md = 16;

  /// 20 — hero cards, large feature surfaces (`--gb-r-lg`).
  static const double lg = 20;

  /// 26 — XL surfaces (`--gb-r-xl`).
  static const double xl = 26;

  /// 13 — weekday/day badge squircle.
  static const double badge = 13;

  /// Fully-rounded pill / stadium.
  static const double pill = 999;

  // ── Convenience BorderRadius values ─────────────────────────────────────
  static const BorderRadius brSm = BorderRadius.all(Radius.circular(sm));
  static const BorderRadius brMd = BorderRadius.all(Radius.circular(md));
  static const BorderRadius brLg = BorderRadius.all(Radius.circular(lg));
  static const BorderRadius brBadge = BorderRadius.all(Radius.circular(badge));

  /// Top-only rounding for bottom sheets (22px in the prototype).
  static const BorderRadius sheet = BorderRadius.vertical(top: Radius.circular(22));
}
