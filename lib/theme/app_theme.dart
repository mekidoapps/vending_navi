import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  static const Color appBackground = Color(0xFFD6ECFF);
  static const Color panelBackground = Colors.white;
  static const Color softSurface = Color(0xFFF4F6F8);
  static const Color softBorder = Color(0xFFE3E7EB);
  static const Color strongText = Color(0xFF334148);
  static const Color softText = Color(0xFF60707A);
  static const Color primaryBlue = Color(0xFF3E7BFA);

  static ThemeData light() {
    final base = ThemeData(
      useMaterial3: true,
      scaffoldBackgroundColor: appBackground,
      canvasColor: appBackground,
      colorScheme: ColorScheme.fromSeed(
        seedColor: primaryBlue,
        brightness: Brightness.light,
      ),
    );

    final textTheme = GoogleFonts.notoSansJpTextTheme(base.textTheme).copyWith(
      titleLarge: GoogleFonts.notoSansJp(
        fontSize: 18,
        fontWeight: FontWeight.w700,
        color: strongText,
      ),
      titleMedium: GoogleFonts.notoSansJp(
        fontSize: 16,
        fontWeight: FontWeight.w700,
        color: strongText,
      ),
      bodyMedium: GoogleFonts.notoSansJp(
        fontSize: 14,
        fontWeight: FontWeight.w500,
        color: strongText,
      ),
      bodySmall: GoogleFonts.notoSansJp(
        fontSize: 12,
        fontWeight: FontWeight.w500,
        color: softText,
      ),
      labelLarge: GoogleFonts.notoSansJp(
        fontSize: 14,
        fontWeight: FontWeight.w700,
        color: Colors.white,
      ),
    );

    return base.copyWith(
      textTheme: textTheme,
      primaryTextTheme: textTheme,
      appBarTheme: AppBarTheme(
        backgroundColor: appBackground,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        iconTheme: const IconThemeData(color: strongText),
        titleTextStyle: GoogleFonts.notoSansJp(
          fontSize: 18,
          fontWeight: FontWeight.w700,
          color: strongText,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: panelBackground,
        isDense: true,
        hintStyle: GoogleFonts.notoSansJp(
          fontSize: 14,
          fontWeight: FontWeight.w500,
          color: softText,
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 12,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: softBorder),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: softBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(
            color: primaryBlue,
            width: 1.5,
          ),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryBlue,
          foregroundColor: Colors.white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 14,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          textStyle: GoogleFonts.notoSansJp(
            fontSize: 14,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: strongText,
          side: const BorderSide(color: softBorder),
          padding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 14,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          textStyle: GoogleFonts.notoSansJp(
            fontSize: 14,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: primaryBlue,
          foregroundColor: Colors.white,
          textStyle: GoogleFonts.notoSansJp(
            fontSize: 14,
            fontWeight: FontWeight.w700,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: primaryBlue,
          textStyle: GoogleFonts.notoSansJp(
            fontSize: 13,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: primaryBlue,
        foregroundColor: Colors.white,
        extendedTextStyle: GoogleFonts.notoSansJp(
          fontSize: 14,
          fontWeight: FontWeight.w700,
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: panelBackground,
        selectedColor: const Color(0xFFE8F1FF),
        side: const BorderSide(color: softBorder),
        labelStyle: GoogleFonts.notoSansJp(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: strongText,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(999),
        ),
      ),
      tabBarTheme: TabBarThemeData(
        labelColor: primaryBlue,
        unselectedLabelColor: softText,
        indicatorColor: primaryBlue,
        dividerColor: Colors.transparent,
        labelStyle: GoogleFonts.notoSansJp(
          fontSize: 13,
          fontWeight: FontWeight.w700,
        ),
        unselectedLabelStyle: GoogleFonts.notoSansJp(
          fontSize: 13,
          fontWeight: FontWeight.w600,
        ),
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: primaryBlue,
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: panelBackground,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(22),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: strongText,
        contentTextStyle: GoogleFonts.notoSansJp(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: Colors.white,
        ),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
      ),
    );
  }
}