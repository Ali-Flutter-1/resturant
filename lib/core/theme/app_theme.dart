import 'package:flutter/material.dart';

import '../animations/motion.dart';
import '../animations/page_transitions.dart';
import 'app_colors.dart';
import 'app_spacing.dart';
import 'app_typography.dart';

/// Assembles the tokens into `ThemeData`.
abstract final class AppTheme {
  static ThemeData get light {
    const scheme = ColorScheme.light(
      primary: AppColors.crimson600,
      onPrimary: AppColors.neutral0,
      primaryContainer: AppColors.crimson50,
      onPrimaryContainer: AppColors.crimson700,
      secondary: AppColors.crimson700,
      onSecondary: AppColors.neutral0,
      surface: AppColors.neutral0,
      onSurface: AppColors.neutral900,
      surfaceContainerLowest: AppColors.neutral0,
      surfaceContainer: AppColors.neutral25,
      surfaceContainerHigh: AppColors.neutral50,
      outline: AppColors.neutral200,
      outlineVariant: AppColors.neutral100,
      error: AppColors.crimson500,
      onError: AppColors.neutral0,
    );

    return _base(
      scheme: scheme,
      textTheme: AppTypography.lightTextTheme,
      surfaces: AppSurfaces.light,
      orderColors: OrderStateColors.light,
      scaffold: AppColors.neutral25,
    );
  }

  static ThemeData get dark {
    const scheme = ColorScheme.dark(
      primary: AppColors.darkAccent,
      onPrimary: Color(0xFF3A0509),
      primaryContainer: Color(0xFF4A1418),
      onPrimaryContainer: AppColors.darkAccentInk,
      secondary: AppColors.darkAccentInk,
      onSecondary: Color(0xFF3A0509),
      surface: AppColors.darkSurface,
      onSurface: AppColors.darkInk,
      surfaceContainerLowest: AppColors.darkGround,
      surfaceContainer: AppColors.darkSurface,
      surfaceContainerHigh: AppColors.darkRaised,
      outline: AppColors.darkLineFirm,
      outlineVariant: AppColors.darkLine,
      error: Color(0xFFEE7A80),
      onError: Color(0xFF3A0509),
    );

    return _base(
      scheme: scheme,
      textTheme: AppTypography.darkTextTheme,
      surfaces: AppSurfaces.dark,
      orderColors: OrderStateColors.dark,
      scaffold: AppColors.darkGround,
    );
  }

  static ThemeData _base({
    required ColorScheme scheme,
    required TextTheme textTheme,
    required AppSurfaces surfaces,
    required OrderStateColors orderColors,
    required Color scaffold,
  }) {
    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      textTheme: textTheme,
      scaffoldBackgroundColor: scaffold,
      extensions: [surfaces, orderColors],

      // Every platform mapped explicitly. The previous map covered only
      // Android and iOS, so desktop and web silently fell back to Flutter's
      // default — and mapping iOS to a shared axis had removed the
      // edge-swipe back gesture along with Cupertino's transition.
      pageTransitionsTheme: appPageTransitionsTheme,

      appBarTheme: AppBarTheme(
        backgroundColor: scaffold,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: true,
        titleTextStyle: textTheme.headlineMedium?.copyWith(
          color: scheme.primary,
        ),
        iconTheme: IconThemeData(color: scheme.onSurface, size: 24),
      ),

      cardTheme: CardThemeData(
        color: scheme.surface,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.lg),
        ),
      ),

      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: scheme.primary,
          foregroundColor: scheme.onPrimary,
          minimumSize: const Size.fromHeight(52),
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.x8,
            vertical: AppSpacing.x4,
          ),
          textStyle: textTheme.labelLarge,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.md),
          ),
          animationDuration: Motion.instant,
        ),
      ),

      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: scheme.onPrimaryContainer,
          minimumSize: const Size.fromHeight(52),
          side: BorderSide(color: surfaces.lineFirm),
          textStyle: textTheme.labelLarge,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.md),
          ),
          animationDuration: Motion.instant,
        ),
      ),

      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: scheme.primary,
          textStyle: textTheme.labelLarge,
        ),
      ),

      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: scheme.surface,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.x4,
          vertical: AppSpacing.x4,
        ),
        hintStyle: textTheme.bodyMedium?.copyWith(color: surfaces.inkSoft),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide: BorderSide(color: surfaces.line),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide: BorderSide(color: surfaces.line),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide: BorderSide(color: scheme.primary, width: 1.5),
        ),
      ),

      dividerTheme: DividerThemeData(
        color: surfaces.line,
        thickness: 1,
        space: 1,
      ),

      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: scheme.surface,
        surfaceTintColor: Colors.transparent,
        indicatorColor: Colors.transparent,
        elevation: 0,
        height: 68,
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return AppTypography.caption(
            selected ? scheme.primary : surfaces.inkSoft,
          ).copyWith(fontSize: 10);
        }),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return IconThemeData(
            size: 22,
            color: selected ? scheme.primary : surfaces.inkSoft,
          );
        }),
      ),

      chipTheme: ChipThemeData(
        backgroundColor: scheme.surface,
        side: BorderSide(color: surfaces.line),
        labelStyle: textTheme.labelMedium!,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.pill),
        ),
      ),

      snackBarTheme: SnackBarThemeData(
        backgroundColor: AppColors.neutral900,
        contentTextStyle: textTheme.bodyMedium?.copyWith(
          color: AppColors.neutral0,
        ),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
        ),
      ),
    );
  }
}
