import 'package:flutter/material.dart';

class AppColors {
  // Paleta principal
  static const Color background   = Color(0xFF1D4241);
  static const Color backgroundDeep  = Color(0xFF152E2D);
  static const Color backgroundCard  = Color(0xFF1A3B3A);
  static const Color backgroundLight = Color(0xFF234E4D);

  // Acentos
  static const Color peach  = Color(0xFFEF9C82);
  static const Color peachDark = Color(0xFFE8835F);
  static const Color mint   = Color(0xFF7DBBA8);
  static const Color mintDark  = Color(0xFF5A9E8B);
  static const Color cream  = Color(0xFFF5E6D3);

  // Textos
  static const Color textPrimary = Color(0xFFF5E6D3);
  static const Color textMuted   = Color(0xFF7DBBA8);
  static const Color textFaint   = Color(0x66F5E6D3);

  // Bordes
  static const Color border = Color(0x267DBBA8);
  static const Color borderFocus = Color(0x80EF9C82);
}

class AppTheme {
  static ThemeData get theme {
    return ThemeData(
      useMaterial3: true,
      scaffoldBackgroundColor: AppColors.backgroundDeep,
      fontFamily: 'DM Sans',

      colorScheme: ColorScheme.dark(
        primary: AppColors.peach,
        secondary: AppColors.mint,
        surface: AppColors.backgroundCard,
        onPrimary: AppColors.background,
        onSecondary: AppColors.background,
        onSurface: AppColors.textPrimary,
      ),

      // AppBar
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.background,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          fontFamily: 'Playfair Display',
          fontSize: 22,
          fontWeight: FontWeight.w700,
          color: AppColors.textPrimary,
        ),
      ),

      // Botón principal
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.peach,
          foregroundColor: AppColors.background,
          minimumSize: const Size(double.infinity, 56),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          textStyle: const TextStyle(
            fontFamily: 'DM Sans',
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),

      // Botón outline
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.cream,
          side: const BorderSide(color: AppColors.border),
          minimumSize: const Size(double.infinity, 56),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          textStyle: const TextStyle(
            fontFamily: 'DM Sans',
            fontSize: 15,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),

      // Inputs
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white.withOpacity(0.04),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 20,
          vertical: 18,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(
            color: AppColors.borderFocus,
            width: 1.5,
          ),
        ),
        hintStyle: TextStyle(
          color: AppColors.cream.withOpacity(0.25),
          fontFamily: 'DM Sans',
          fontSize: 15,
        ),
        labelStyle: const TextStyle(
          color: AppColors.mint,
          fontFamily: 'DM Sans',
          fontSize: 11,
          fontWeight: FontWeight.w600,
          letterSpacing: 1.5,
        ),
        floatingLabelStyle: const TextStyle(
          color: AppColors.peach,
          fontFamily: 'DM Sans',
          fontSize: 11,
          fontWeight: FontWeight.w600,
          letterSpacing: 1.5,
        ),
      ),

      // Divider
      dividerTheme: const DividerThemeData(
        color: AppColors.border,
        thickness: 1,
      ),

      // SnackBar
      snackBarTheme: SnackBarThemeData(
        backgroundColor: AppColors.backgroundLight,
        contentTextStyle: const TextStyle(
          color: AppColors.textPrimary,
          fontFamily: 'DM Sans',
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}