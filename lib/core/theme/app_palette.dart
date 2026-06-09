import 'package:flutter/widgets.dart';

/// Raw color palette — a 1:1 port of the design `--inv-*` / `--gb-*` hex values (tokens.css).
/// These are the *primitive* tokens; semantic access goes through [GbColors] (app_colors.dart).
/// Blue primary, no purple.
abstract final class AppPalette {
  AppPalette._();

  // ── Primary (blue) ──────────────────────────────────────────────────────
  static const primary0 = Color(0xFFEFF6FF);
  static const primary25 = Color(0xFFDBEAFE);
  static const primary50 = Color(0xFFBFDBFE);
  static const primary100 = Color(0xFF93C5FD);
  static const primary200 = Color(0xFF60A5FA);
  static const primary300 = Color(0xFF1E3A8A);
  static const primary500 = Color(0xFF3B82F6);
  static const primary600 = Color(0xFF2563EB);
  static const primary700 = Color(0xFF1D4ED8);
  static const primary800 = Color(0xFF1E40AF);
  static const primary900 = Color(0xFF172554);

  // ── Secondary (sky/cyan) ────────────────────────────────────────────────
  static const secondary0 = Color(0xFFEFF6FF);
  static const secondary25 = Color(0xFFE0F2FE);
  static const secondary300 = Color(0xFF0284C7);

  // ── Greys ────────────────────────────────────────────────────────────────
  static const grey0 = Color(0xFFF7F8F9);
  static const grey25 = Color(0xFFECEFF2);
  static const grey50 = Color(0xFFD0D5DD);
  static const grey100 = Color(0xFFC8CCD4);
  static const grey200 = Color(0xFFB5BAC5);
  static const grey300 = Color(0xFF98A1B0);
  static const grey400 = Color(0xFF858C9D);
  static const grey500 = Color(0xFF667085);
  static const grey600 = Color(0xFF475467);
  static const grey700 = Color(0xFF344054);
  static const grey800 = Color(0xFF1A2230);
  static const grey900 = Color(0xFF0B1220);

  // ── Status ────────────────────────────────────────────────────────────
  static const success0 = Color(0xFFE6F9F4);
  static const success50 = Color(0xFF7FD9C1);
  static const success300 = Color(0xFF178265);

  static const warning0 = Color(0xFFFFF9E6);
  static const warning50 = Color(0xFFFBD582);
  static const warning100 = Color(0xFFFFB040);
  static const warning200 = Color(0xFF996021);
  static const warning300 = Color(0xFF5D3E1C);

  static const error0 = Color(0xFFFFE6E6);
  static const error50 = Color(0xFFF28E8E);
  static const error100 = Color(0xFFE02424);
  static const error200 = Color(0xFFA32020);

  // ── Borders / surfaces ────────────────────────────────────────────────
  static const surface = Color(0xFFFFFFFF);
  static const borderCard = Color(0xFFE5E7EB);
  static const borderField = Color(0xFFD1D5DB);

  // ── Athletic-premium polish layer (`--gb-*`) ──────────────────────────
  static const canvas = Color(0xFFF1F4F9);
  static const ink = Color(0xFF0B1220);
  static const inkSoft = Color(0xFF2B3647);

  static const emerald = Color(0xFF10B981);
  static const emeraldSoft = Color(0xFFD6F5EA);
  static const emeraldInk = Color(0xFF0F7A5A);
  static const amber = Color(0xFFF59E0B);
  static const amberSoft = Color(0xFFFDF0D4);
  static const amberInk = Color(0xFFB4730B);

  // Hero gradient stops (`--gb-hero`, ~150deg).
  static const heroA = Color(0xFF2F6BFF);
  static const heroB = Color(0xFF1D4ED8);
  static const heroC = Color(0xFF1B2F8A);

  // Deep-navy gradient stops (`--gb-hero-deep`, rest bar).
  static const heroDeepA = Color(0xFF1E3A8A);
  static const heroDeepB = Color(0xFF14235E);

  // Progress-bar mint→white fill, and the live "active" dot.
  static const mint = Color(0xFFA5F3D0);
  static const liveDot = Color(0xFF34D399);

  /// Bottom stop of the live-session current-set card's tint gradient
  /// (design `linear-gradient(180deg, #eff6ff → #e6f0ff)`; the top stop is [primary0]).
  static const primaryTint = Color(0xFFE6F0FF);

  /// Light top-stop of the rest-timer ring gradient (design `#6ee7b7`; the bottom stop is [liveDot]).
  static const restRingLight = Color(0xFF6EE7B7);
}
