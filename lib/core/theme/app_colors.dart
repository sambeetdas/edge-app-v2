import 'package:flutter/material.dart';

class AppColors {
  AppColors._();

  // Brand & Gradient
  static const Color brandPurpleDeep = Color(0xFF4C1D95);
  static const Color brandPurpleMid = Color(0xFF6D28D9);
  static const Color brandBlue = Color(0xFF2563EB);

  static const LinearGradient brandGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [brandPurpleDeep, brandPurpleMid, brandBlue],
    stops: [0.0, 0.5, 1.0],
  );

  // Light Palette
  static const Color primary = Color(0xFF6750A4);
  static const Color secondary = Color(0xFF625B71);
  static const Color tertiary = Color(0xFF7D5260);
  static const Color surface = Color(0xFFFFFBFE);
  static const Color surfaceContainer = Color(0xFFF3EDF7);
  static const Color onPrimary = Color(0xFFFFFFFF);
  static const Color onSurface = Color(0xFF1C1B1F);
  static const Color onSurfaceVariant = Color(0xFF49454F);
  static const Color primaryContainer = Color(0xFFEADDFF);
  static const Color onPrimaryContainer = Color(0xFF21005D);
  static const Color outline = Color(0xFFCAC4D0);

  // Dark Palette
  static const Color primaryDark = Color(0xFFD0BCFF);
  static const Color secondaryDark = Color(0xFFCCC2DC);
  static const Color tertiaryDark = Color(0xFFEFB8C8);
  static const Color surfaceDark = Color(0xFF1C1B1F);
  static const Color surfaceContainerDark = Color(0xFF2B2930);
  static const Color onSurfaceDark = Color(0xFFE6E1E5);
  static const Color onSurfaceVariantDark = Color(0xFFCAC4D0);
  static const Color primaryContainerDark = Color(0xFF4F378B);
  static const Color outlineDark = Color(0xFF49454F);

  // Chat Bubbles
  static const Color userBubbleLight = Color(0xFF6750A4);
  static const Color userBubbleDark = Color(0xFF4F378B);
  static const Color aiBubbleLight = Color(0xFFCCEFCC);
  static const Color aiBubbleTextLight = Color(0xFF1A3520);
  static const Color aiBubbleDark = Color(0xFF1E3B22);
  static const Color aiBubbleTextDark = Color(0xFFCCEFCC);

  // Semantic
  static const Color success = Color(0xFF4CAF50);
  static const Color error = Color(0xFFB3261E);
  static const Color warning = Color(0xFFF9A825);
}
