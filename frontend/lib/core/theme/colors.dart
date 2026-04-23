import 'package:flutter/material.dart';

/// Modern Minimalist Renk Paleti
/// Charcoal/Slate Gray temalı, sade ve şık bir görsel kimlik
class AppColors {
  // Primary Colors - Charcoal
  static const Color charcoal = Color(0xFF36454F);
  static const Color charcoalLight = Color(0xFF4A5D6A);
  static const Color charcoalDark = Color(0xFF2D383F);

  // Accent - Slate Gray
  static const Color slateGray = Color(0xFF708090);
  static const Color slateGrayLight = Color(0xFF8A9AAA);
  static const Color slateGrayDark = Color(0xFF5A6A7A);

  // Background & Surface - Light Gray & White
  static const Color lightGray = Color(0xFFD3D3D3);
  static const Color lightGrayLight = Color(0xFFE8E8E8);
  static const Color background = Color(0xFFFAFAFA);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color surfaceVariant = Color(0xFFF5F5F5);

  // Text Colors
  static const Color textPrimary = Color(0xFF36454F);
  static const Color textSecondary = Color(0xFF708090);
  static const Color textTertiary = Color(0xFF9A9A9A);
  static const Color textOnPrimary = Color(0xFFFFFFFF);
  static const Color textOnAccent = Color(0xFFFFFFFF);

  // Status Colors
  static const Color success = Color(0xFF10B981);
  static const Color successLight = Color(0xFFD1FAE5);
  static const Color warning = Color(0xFFF59E0B);
  static const Color warningLight = Color(0xFFFEF3C7);
  static const Color error = Color(0xFFEF4444);
  static const Color errorLight = Color(0xFFFEE2E2);
  static const Color info = Color(0xFF3B82F6);
  static const Color infoLight = Color(0xFFDBEAFE);

  // Border & Divider
  static const Color border = Color(0xFFE5E5E5);
  static const Color divider = Color(0xFFD3D3D3);

  // Shadow
  static const Color shadow = Color(0x1A36454F);
  static const Color shadowLight = Color(0x0D36454F);

  // Gradient
  static const LinearGradient primaryGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [charcoal, charcoalLight],
  );

  static const LinearGradient subtleGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [surface, background],
  );
}
