import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'colors.dart';

class AppTheme {
  // Border Radius Constants
  static const double radiusSmall = 8.0;
  static const double radiusMedium = 12.0;
  static const double radiusLarge = 16.0;
  static const double radiusXLarge = 24.0;

  // Spacing Constants
  static const double spaceXS = 4.0;
  static const double spaceS = 8.0;
  static const double spaceM = 16.0;
  static const double spaceL = 24.0;
  static const double spaceXL = 32.0;
  static const double spaceXXL = 48.0;

  // Animation Durations
  static const Duration animFast = Duration(milliseconds: 150);
  static const Duration animNormal = Duration(milliseconds: 300);
  static const Duration animSlow = Duration(milliseconds: 400);

  // Typography - Using centralized typography system
  static TextStyle get _baseTextStyle => GoogleFonts.sourceCodePro();

  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      scaffoldBackgroundColor: AppColors.background,
      primaryColor: AppColors.charcoal,
      colorScheme: const ColorScheme.light(
        primary: AppColors.charcoal,
        onPrimary: AppColors.textOnPrimary,
        secondary: AppColors.slateGray,
        onSecondary: AppColors.textOnAccent,
        surface: AppColors.surface,
        onSurface: AppColors.textPrimary,
        error: AppColors.error,
        onError: AppColors.textOnPrimary,
      ),

      // AppBar Theme
      appBarTheme: AppBarTheme(
        elevation: 0,
        centerTitle: false,
        backgroundColor: AppColors.surface,
        foregroundColor: AppColors.textPrimary,
        surfaceTintColor: Colors.transparent,
        systemOverlayStyle: SystemUiOverlayStyle.dark,
        titleTextStyle: _baseTextStyle.copyWith(
          fontSize: 20,
          fontWeight: FontWeight.bold,
          color: AppColors.textPrimary,
        ),
        iconTheme: const IconThemeData(
          color: AppColors.charcoal,
        ),
      ),

      // Text Theme - Source Code Pro (DejaVu Sans Mono alternatifi)
      textTheme: TextTheme(
        displayLarge: _baseTextStyle.copyWith(fontSize: 32, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
        displayMedium: _baseTextStyle.copyWith(fontSize: 28, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
        displaySmall: _baseTextStyle.copyWith(fontSize: 24, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
        headlineLarge: _baseTextStyle.copyWith(fontSize: 22, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
        headlineMedium: _baseTextStyle.copyWith(fontSize: 20, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
        headlineSmall: _baseTextStyle.copyWith(fontSize: 18, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
        titleLarge: _baseTextStyle.copyWith(fontSize: 16, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
        titleMedium: _baseTextStyle.copyWith(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
        titleSmall: _baseTextStyle.copyWith(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
        bodyLarge: _baseTextStyle.copyWith(fontSize: 16, fontWeight: FontWeight.normal, color: AppColors.textPrimary),
        bodyMedium: _baseTextStyle.copyWith(fontSize: 14, fontWeight: FontWeight.normal, color: AppColors.textSecondary),
        bodySmall: _baseTextStyle.copyWith(fontSize: 12, fontWeight: FontWeight.normal, color: AppColors.textTertiary),
        labelLarge: _baseTextStyle.copyWith(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
        labelMedium: _baseTextStyle.copyWith(fontSize: 12, fontWeight: FontWeight.w500, color: AppColors.textSecondary),
        labelSmall: _baseTextStyle.copyWith(fontSize: 10, fontWeight: FontWeight.w500, color: AppColors.textTertiary),
      ),

      // elevated Button Theme
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          elevation: 0,
          backgroundColor: AppColors.charcoal,
          foregroundColor: AppColors.textOnPrimary,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radiusMedium),
          ),
          textStyle: _baseTextStyle.copyWith(fontSize: 14, fontWeight: FontWeight.w600),
        ),
      ),

      // Text Button Theme
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.charcoal,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radiusMedium),
          ),
          textStyle: _baseTextStyle.copyWith(fontSize: 14, fontWeight: FontWeight.w600),
        ),
      ),

      // Outlined Button Theme
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.charcoal,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radiusMedium),
          ),
          side: const BorderSide(color: AppColors.charcoal, width: 1.5),
          textStyle: _baseTextStyle.copyWith(fontSize: 14, fontWeight: FontWeight.w600),
        ),
      ),

      // Input Decoration Theme
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.surfaceVariant,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusMedium),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusMedium),
          borderSide: const BorderSide(color: AppColors.border, width: 1),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusMedium),
          borderSide: const BorderSide(color: AppColors.charcoal, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusMedium),
          borderSide: const BorderSide(color: AppColors.error, width: 1),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusMedium),
          borderSide: const BorderSide(color: AppColors.error, width: 2),
        ),
        hintStyle: _baseTextStyle.copyWith(color: AppColors.textTertiary, fontSize: 14),
        labelStyle: _baseTextStyle.copyWith(color: AppColors.textSecondary, fontSize: 14),
        errorStyle: _baseTextStyle.copyWith(color: AppColors.error, fontSize: 12),
      ),

      // Card Theme
      cardTheme: CardThemeData(
        elevation: 0,
        color: AppColors.surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusLarge),
          side: const BorderSide(color: AppColors.border, width: 1),
        ),
        margin: EdgeInsets.zero,
      ),

      // Bottom Navigation Bar Theme
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        elevation: 0,
        backgroundColor: AppColors.surface,
        selectedItemColor: AppColors.charcoal,
        unselectedItemColor: AppColors.textTertiary,
        type: BottomNavigationBarType.fixed,
        selectedLabelStyle: _baseTextStyle.copyWith(fontSize: 12, fontWeight: FontWeight.w600),
        unselectedLabelStyle: _baseTextStyle.copyWith(fontSize: 12, fontWeight: FontWeight.normal),
      ),

      // Chip Theme
      chipTheme: ChipThemeData(
        elevation: 0,
        backgroundColor: AppColors.surfaceVariant,
        selectedColor: AppColors.charcoal,
        labelStyle: _baseTextStyle.copyWith(fontSize: 12, color: AppColors.textPrimary),
        secondaryLabelStyle: _baseTextStyle.copyWith(fontSize: 12, color: AppColors.textOnPrimary),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusSmall),
        ),
      ),

      // Floating Action Button Theme
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        elevation: 2,
        backgroundColor: AppColors.charcoal,
        foregroundColor: AppColors.textOnPrimary,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusLarge),
        ),
      ),

      // Bottom Sheet Theme
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: AppColors.surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(radiusXLarge),
          ),
        ),
      ),

      // Dialog Theme
      dialogTheme: DialogThemeData(
        backgroundColor: AppColors.surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusXLarge),
        ),
        titleTextStyle: _baseTextStyle.copyWith(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
        contentTextStyle: _baseTextStyle.copyWith(fontSize: 14, color: AppColors.textSecondary),
      ),

      // Snackbar Theme
      snackBarTheme: SnackBarThemeData(
        backgroundColor: AppColors.charcoal,
        contentTextStyle: _baseTextStyle.copyWith(fontSize: 14, color: AppColors.textOnPrimary),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusMedium),
        ),
        behavior: SnackBarBehavior.floating,
      ),

      // Divider Theme
      dividerTheme: const DividerThemeData(
        color: AppColors.divider,
        thickness: 1,
        space: 1,
      ),

      // Icon Theme
      iconTheme: const IconThemeData(
        color: AppColors.charcoal,
        size: 24,
      ),

      // List Tile Theme
      listTileTheme: ListTileThemeData(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusMedium),
        ),
        titleTextStyle: _baseTextStyle.copyWith(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
        subtitleTextStyle: _baseTextStyle.copyWith(fontSize: 12, color: AppColors.textSecondary),
      ),

      // Tab Bar Theme
      tabBarTheme: TabBarThemeData(
        labelColor: AppColors.charcoal,
        unselectedLabelColor: AppColors.textTertiary,
        labelStyle: _baseTextStyle.copyWith(fontSize: 14, fontWeight: FontWeight.w600),
        unselectedLabelStyle: _baseTextStyle.copyWith(fontSize: 14, fontWeight: FontWeight.normal),
        indicator: const UnderlineTabIndicator(
          borderSide: BorderSide(color: AppColors.charcoal, width: 2),
        ),
      ),
    );
  }
}
