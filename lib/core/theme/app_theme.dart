import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'app_colors.dart';

class AppTheme {
  AppTheme._();

  static ThemeData light() {
    final base = ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      colorScheme: const ColorScheme.light(
        primary: AppColors.primary,
        onPrimary: AppColors.onPrimary,
        primaryContainer: AppColors.primaryContainer,
        onPrimaryContainer: AppColors.onPrimaryContainer,
        secondary: AppColors.secondary,
        tertiary: AppColors.tertiary,
        surface: AppColors.surface,
        onSurface: AppColors.onSurface,
        onSurfaceVariant: AppColors.onSurfaceVariant,
        surfaceContainerHighest: AppColors.surfaceContainer,
        outline: AppColors.outline,
        error: AppColors.error,
      ),
      scaffoldBackgroundColor: AppColors.surface,
    );

    return _applySharedStyling(base, isDark: false);
  }

  static ThemeData dark() {
    final base = ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: const ColorScheme.dark(
        primary: AppColors.primaryDark,
        onPrimary: Color(0xFF381E72),
        primaryContainer: AppColors.primaryContainerDark,
        onPrimaryContainer: AppColors.primaryContainer,
        secondary: AppColors.secondaryDark,
        tertiary: AppColors.tertiaryDark,
        surface: AppColors.surfaceDark,
        onSurface: AppColors.onSurfaceDark,
        onSurfaceVariant: AppColors.onSurfaceVariantDark,
        surfaceContainerHighest: AppColors.surfaceContainerDark,
        outline: AppColors.outlineDark,
        error: Color(0xFFF2B8B5),
      ),
      scaffoldBackgroundColor: AppColors.surfaceDark,
    );

    return _applySharedStyling(base, isDark: true);
  }

  static ThemeData _applySharedStyling(ThemeData base, {required bool isDark}) {
    final rawTextTheme = GoogleFonts.openSansTextTheme(base.textTheme);
    final textTheme = rawTextTheme.copyWith(
      headlineSmall: rawTextTheme.headlineSmall?.copyWith(
        fontSize: 25,
        fontWeight: FontWeight.w700,
      ),
      titleLarge: rawTextTheme.titleLarge?.copyWith(
        fontSize: 21,
        fontWeight: FontWeight.w700,
      ),
      titleMedium: rawTextTheme.titleMedium?.copyWith(
        fontSize: 17.5,
        fontWeight: FontWeight.w600,
      ),
      titleSmall: rawTextTheme.titleSmall?.copyWith(
        fontSize: 15,
        fontWeight: FontWeight.w600,
      ),
      bodyLarge: rawTextTheme.bodyLarge?.copyWith(
        fontSize: 16.5,
        height: 1.45,
      ),
      bodyMedium: rawTextTheme.bodyMedium?.copyWith(
        fontSize: 15.5,
        height: 1.45,
      ),
      bodySmall: rawTextTheme.bodySmall?.copyWith(
        fontSize: 13.5,
        height: 1.4,
      ),
      labelLarge: rawTextTheme.labelLarge?.copyWith(
        fontSize: 15.5,
        fontWeight: FontWeight.w600,
      ),
    );
    final cardColor =
        isDark ? AppColors.surfaceContainerDark : AppColors.surfaceContainer;

    return base.copyWith(
      textTheme: textTheme,
      appBarTheme: AppBarTheme(
        centerTitle: false,
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor: Colors.transparent,
        foregroundColor: isDark ? AppColors.onSurfaceDark : AppColors.onSurface,
        titleTextStyle: textTheme.titleLarge?.copyWith(
          fontWeight: FontWeight.w700,
          letterSpacing: -0.3,
          color: isDark ? AppColors.onSurfaceDark : AppColors.onSurface,
        ),
      ),
      cardTheme: CardThemeData(
        color: cardColor,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(
            color: (isDark ? AppColors.outlineDark : AppColors.outline)
                .withValues(alpha: isDark ? 0.55 : 0.65),
          ),
        ),
        margin: EdgeInsets.zero,
      ),
      chipTheme: ChipThemeData(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        side: BorderSide(
          color: (isDark ? AppColors.outlineDark : AppColors.outline)
              .withValues(alpha: 0.6),
        ),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        elevation: 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: cardColor,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(
            color: (isDark ? AppColors.outlineDark : AppColors.outline)
                .withValues(alpha: 0.35),
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(
            color: isDark ? AppColors.primaryDark : AppColors.primary,
            width: 1.5,
          ),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(double.infinity, 50),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          textStyle: textTheme.labelLarge?.copyWith(
            fontWeight: FontWeight.w600,
            fontSize: 15,
          ),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        height: 68,
        elevation: 0,
        backgroundColor:
            isDark ? AppColors.surfaceContainerDark : AppColors.surfaceContainer,
        indicatorColor:
            isDark ? AppColors.primaryContainerDark : AppColors.primaryContainer,
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
      ),
    );
  }
}
