import 'package:flutter/material.dart';

import 'v2_color_tokens.dart';
import 'v2_radius.dart';

abstract final class V2Theme {
  static ThemeData light({V2ColorTokens colors = V2ColorTokens.skyBlue}) {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: colors.primary,
      brightness: Brightness.light,
      primary: colors.primaryStrong,
      surface: colors.surfaceElevated,
      error: colors.error,
    );

    final base = ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: colors.surface,
      splashFactory: InkSparkle.splashFactory,
      visualDensity: VisualDensity.standard,
      extensions: <ThemeExtension<dynamic>>[colors],
    );

    final textTheme = base.textTheme.copyWith(
      headlineSmall: base.textTheme.headlineSmall?.copyWith(
        color: colors.textPrimary,
        fontSize: 20,
        fontWeight: FontWeight.w600,
      ),
      titleMedium: base.textTheme.titleMedium?.copyWith(
        color: colors.textPrimary,
        fontSize: 17,
        fontWeight: FontWeight.w600,
      ),
      bodyMedium: base.textTheme.bodyMedium?.copyWith(
        color: colors.textPrimary,
        fontSize: 14,
        height: 1.5,
      ),
      bodySmall: base.textTheme.bodySmall?.copyWith(
        color: colors.textSecondary,
        fontSize: 12,
        height: 1.4,
      ),
      labelLarge: base.textTheme.labelLarge?.copyWith(
        fontSize: 15,
        fontWeight: FontWeight.w600,
      ),
    );

    return base.copyWith(
      textTheme: textTheme,
      appBarTheme: AppBarTheme(
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        backgroundColor: colors.surface,
        foregroundColor: colors.textPrimary,
        surfaceTintColor: Colors.transparent,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(48, 50),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          backgroundColor: colors.primaryStrong,
          foregroundColor: Colors.white,
          shape: const RoundedRectangleBorder(borderRadius: V2Radius.control),
          textStyle: textTheme.labelLarge,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(48, 50),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          foregroundColor: colors.primaryStrong,
          backgroundColor: colors.surfaceElevated,
          side: BorderSide(color: colors.border),
          shape: const RoundedRectangleBorder(borderRadius: V2Radius.control),
          textStyle: textTheme.labelLarge,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: colors.surfaceElevated,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
        border: OutlineInputBorder(
          borderRadius: V2Radius.control,
          borderSide: BorderSide(color: colors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: V2Radius.control,
          borderSide: BorderSide(color: colors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: V2Radius.control,
          borderSide: BorderSide(color: colors.primaryStrong, width: 1.5),
        ),
      ),
      dividerColor: colors.border,
    );
  }
}
