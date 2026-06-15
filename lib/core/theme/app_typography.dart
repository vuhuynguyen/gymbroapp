import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'app_palette.dart';

/// Typography tokens — "Inter Tight" (the portal/design typeface) plus the named text styles the
/// prototype reuses. Styles are color-agnostic (callers/widgets apply color) except where the role
/// implies one. Heavy weights (700/800) and tight tracking are the design's signature.
abstract final class AppText {
  AppText._();

  static const String family = 'Inter Tight';

  /// Tabular, athletic number display (`.gb-num`) — for stats, weights, timers.
  static const List<FontFeature> _tnum = [FontFeature.tabularFigures()];

  /// Large screen header title (`PlainHeader`). Slightly relaxed tracking + line-height so titles
  /// (incl. the 19px coach variant) don't read cramped.
  static const screenTitle =
      TextStyle(fontSize: 23, fontWeight: FontWeight.w800, letterSpacing: -0.4, height: 1.18);

  /// Gradient hero name (24px / 800 / -0.02em).
  static const heroTitle =
      TextStyle(fontSize: 24, fontWeight: FontWeight.w800, letterSpacing: -0.48, height: 1.1);

  /// Section heading (14px / 800).
  static const sectionTitle =
      TextStyle(fontSize: 14, fontWeight: FontWeight.w800, letterSpacing: -0.14);

  /// Card / list-row title (15px / 700).
  static const rowTitle = TextStyle(fontSize: 15, fontWeight: FontWeight.w700);

  /// Secondary body (14px).
  static const body = TextStyle(fontSize: 14);

  /// Muted meta line (12px) — colored grey500 by callers.
  static const meta = TextStyle(fontSize: 12);

  /// Small bold label (11px / 700).
  static const label = TextStyle(fontSize: 11, fontWeight: FontWeight.w700);

  /// Uppercase tracked eyebrow (10.5px / 800 / +0.12em). Caller uppercases the text.
  static const eyebrow =
      TextStyle(fontSize: 10.5, fontWeight: FontWeight.w800, letterSpacing: 1.2);

  /// Big stat numeral (22px / 800 / tabular / -0.03em).
  static const statNumber = TextStyle(
    fontSize: 22,
    fontWeight: FontWeight.w800,
    letterSpacing: -0.66,
    fontFeatures: _tnum,
  );

  /// Standard button label (15px / 700).
  static const button = TextStyle(fontSize: 15, fontWeight: FontWeight.w700, letterSpacing: -0.15);

  /// Large CTA label (16.5px / 800).
  static const buttonLg =
      TextStyle(fontSize: 16.5, fontWeight: FontWeight.w800, letterSpacing: -0.16);

  /// Build the Material [TextTheme] from Inter Tight, inked to the design grey-900.
  static TextTheme textTheme() => GoogleFonts.interTightTextTheme().apply(
        bodyColor: AppPalette.grey900,
        displayColor: AppPalette.grey900,
      );

  // ── Progress "data" styles (`.gb-num` / `.gb-label`) ──
  // The Progress tab uses the app's Inter Tight everywhere — there is no custom
  // mono typeface. These two helpers only add tabular figures (so numerals line
  // up) and a tight uppercase micro-label. The earlier JetBrains Mono "data
  // channel" was dropped per the device-readability override: the monospace cells
  // read as over-tracked and hard to read on real hardware.

  /// App font (Inter Tight) with tabular figures (`.gb-num`) — wraps any base style.
  /// Used for stat numerals, the DirTag delta, and data captions.
  static TextStyle mono(TextStyle base) => base.copyWith(fontFeatures: _tnum);

  /// Uppercase micro-label (`.gb-label`) — 10px / 600, app font, zero tracking.
  /// Caller uppercases the text; color defaults are applied at the call site.
  static TextStyle monoLabel() => const TextStyle(
        fontSize: 10,
        fontWeight: FontWeight.w600,
        letterSpacing: 0,
        fontFeatures: _tnum,
      );
}

/// Apply the design's tabular-figure treatment to any style (e.g. `AppText.rowTitle.tabular`).
extension TabularFigures on TextStyle {
  TextStyle get tabular => copyWith(fontFeatures: const [FontFeature.tabularFigures()]);
}
