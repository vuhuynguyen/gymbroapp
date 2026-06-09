import 'package:flutter/widgets.dart';

/// Elevation tokens — the design's softer/spread `--gb-shadow-*` layer (low opacity, navy tint).
/// Shadow colors are fixed in the design, so these are compile-time constants.
abstract final class AppShadows {
  AppShadows._();

  /// Subtle-but-visible lift for list rows / cards. Black-based (not navy) so white cards read as
  /// crisp white on the light canvas instead of flat grey panels.
  static const List<BoxShadow> sm = [
    BoxShadow(color: Color(0x14000000), blurRadius: 3, offset: Offset(0, 1)),
    BoxShadow(color: Color(0x0A000000), blurRadius: 8, spreadRadius: -2, offset: Offset(0, 4)),
  ];

  /// `--gb-shadow` — standard content cards.
  static const List<BoxShadow> card = [
    BoxShadow(color: Color(0x0D101C36), blurRadius: 6, offset: Offset(0, 2)),
    BoxShadow(color: Color(0x24101C36), blurRadius: 24, spreadRadius: -10, offset: Offset(0, 10)),
  ];

  /// `--gb-shadow-lg` — raised surfaces (sheets, dialogs).
  static const List<BoxShadow> lg = [
    BoxShadow(color: Color(0x29101C36), blurRadius: 18, spreadRadius: -8, offset: Offset(0, 8)),
    BoxShadow(color: Color(0x38101C36), blurRadius: 48, spreadRadius: -22, offset: Offset(0, 22)),
  ];

  /// `--gb-shadow-blue` — blue glow under the hero / primary CTA pill.
  static const List<BoxShadow> blue = [
    BoxShadow(color: Color(0x732563EB), blurRadius: 26, spreadRadius: -8, offset: Offset(0, 10)),
  ];

  /// `--gb-shadow-blue-sm` — small blue glow under inline primary buttons.
  static const List<BoxShadow> blueSm = [
    BoxShadow(color: Color(0x6B2563EB), blurRadius: 14, spreadRadius: -4, offset: Offset(0, 4)),
  ];
}
