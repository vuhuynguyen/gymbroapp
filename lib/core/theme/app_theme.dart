import 'package:flutter/material.dart';

import '../tokens/app_radius.dart';
import '../tokens/app_sizes.dart';
import 'app_colors.dart';
import 'app_palette.dart';
import 'app_typography.dart';

/// Assembles the GymBro Material 3 theme from the design tokens. Light-only (the design is a
/// light theme). Component themes are tuned to the prototype: flat white cards with a hairline
/// border (no M3 tonal tint), pill chips, blue nav indicator, radius-12 inputs/buttons.
abstract final class AppTheme {
  AppTheme._();

  static ThemeData light() {
    final scheme = ColorScheme.fromSeed(seedColor: AppPalette.primary600).copyWith(
      primary: AppPalette.primary600,
      onPrimary: Colors.white,
      primaryContainer: AppPalette.primary0,
      onPrimaryContainer: AppPalette.primary700,
      surface: AppPalette.surface,
      onSurface: AppPalette.grey900,
      onSurfaceVariant: AppPalette.grey500,
      outline: AppPalette.borderField,
      outlineVariant: AppPalette.borderCard,
      error: AppPalette.error100,
    );

    final textTheme = AppText.textTheme();

    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: AppPalette.canvas,
      textTheme: textTheme,
      extensions: const [GbColors.light],

      appBarTheme: AppBarTheme(
        backgroundColor: AppPalette.surface,
        surfaceTintColor: Colors.transparent,
        foregroundColor: AppPalette.grey900,
        elevation: 0,
        scrolledUnderElevation: 0.5,
        centerTitle: false,
        titleTextStyle: textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
      ),

      cardTheme: const CardThemeData(
        elevation: 0,
        color: AppPalette.surface,
        surfaceTintColor: Colors.transparent,
        margin: EdgeInsets.symmetric(vertical: 5),
        shape: RoundedRectangleBorder(
          borderRadius: AppRadius.brMd,
          side: BorderSide(color: AppPalette.borderCard),
        ),
      ),

      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(0, AppSizes.buttonHeight),
          textStyle: AppText.button,
          shape: const RoundedRectangleBorder(borderRadius: AppRadius.brSm),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(0, AppSizes.buttonHeight),
          foregroundColor: AppPalette.grey900,
          side: const BorderSide(color: AppPalette.borderCard),
          textStyle: AppText.button,
          shape: const RoundedRectangleBorder(borderRadius: AppRadius.brSm),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppPalette.primary600,
          textStyle: AppText.button,
        ),
      ),

      // Incidental Material chips (status/source badges); selectable filters use [GbChip].
      chipTheme: const ChipThemeData(
        backgroundColor: AppPalette.surface,
        showCheckmark: false,
        side: BorderSide(color: AppPalette.borderCard),
        shape: StadiumBorder(),
        labelStyle: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: AppPalette.grey900),
        padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      ),

      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: AppPalette.surface,
        surfaceTintColor: Colors.transparent,
        indicatorColor: AppPalette.primary25,
        elevation: 1,
        height: 64,
        labelTextStyle: WidgetStateProperty.resolveWith(
          (states) => TextStyle(
            fontSize: 12,
            fontWeight: states.contains(WidgetState.selected) ? FontWeight.w700 : FontWeight.w500,
            color: states.contains(WidgetState.selected) ? AppPalette.primary700 : AppPalette.grey500,
          ),
        ),
        iconTheme: WidgetStateProperty.resolveWith(
          (states) => IconThemeData(
            size: 24,
            color: states.contains(WidgetState.selected) ? AppPalette.primary600 : AppPalette.grey400,
          ),
        ),
      ),

      inputDecorationTheme: const InputDecorationTheme(
        filled: true,
        fillColor: AppPalette.surface,
        border: OutlineInputBorder(
          borderRadius: AppRadius.brSm,
          borderSide: BorderSide(color: AppPalette.borderField),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: AppRadius.brSm,
          borderSide: BorderSide(color: AppPalette.borderField),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: AppRadius.brSm,
          borderSide: BorderSide(color: AppPalette.primary500, width: AppSizes.border),
        ),
      ),

      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: AppPalette.surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: AppRadius.sheet),
        showDragHandle: true,
        dragHandleColor: AppPalette.grey50,
      ),

      dividerTheme: const DividerThemeData(color: AppPalette.borderCard, thickness: 1, space: 1),
    );
  }
}
