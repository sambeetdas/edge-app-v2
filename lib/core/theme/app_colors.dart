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
  static const Color primary = Color(0xFF5B35D5);
  static const Color secondary = Color(0xFF4F5D75);
  static const Color tertiary = Color(0xFF2563EB);
  static const Color surface = Color(0xFFF7F8FC);
  static const Color surfaceContainer = Color(0xFFFFFFFF);
  static const Color onPrimary = Color(0xFFFFFFFF);
  static const Color onSurface = Color(0xFF14161F);
  static const Color onSurfaceVariant = Color(0xFF5C6274);
  static const Color primaryContainer = Color(0xFFEDE8FF);
  static const Color onPrimaryContainer = Color(0xFF2B127A);
  static const Color outline = Color(0xFFDCE0EC);

  // Dark Palette (Modern OLED-friendly slate)
  static const Color primaryDark = Color(0xFFBBA8FF);
  static const Color secondaryDark = Color(0xFFB8C0D4);
  static const Color tertiaryDark = Color(0xFF7CA7FF);
  static const Color surfaceDark = Color(0xFF0B0D14);
  static const Color surfaceContainerDark = Color(0xFF141824);
  static const Color onSurfaceDark = Color(0xFFF1F4FA);
  static const Color onSurfaceVariantDark = Color(0xFF98A0B8);
  static const Color primaryContainerDark = Color(0xFF2B2258);
  static const Color outlineDark = Color(0xFF23283B);

  // Chat Bubbles
  static const Color userBubbleLight = Color(0xFF5B35D5);
  static const Color userBubbleDark = Color(0xFF5B35D5);
  static const Color aiBubbleLight = Color(0xFFFFFFFF);
  static const Color aiBubbleTextLight = Color(0xFF14161F);
  static const Color aiBubbleDark = Color(0xFF161B29);
  static const Color aiBubbleTextDark = Color(0xFFF1F4FA);

  // Semantic
  static const Color success = Color(0xFF4CAF50);
  static const Color error = Color(0xFFB3261E);
  static const Color warning = Color(0xFFF9A825);
}
