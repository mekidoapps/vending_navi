import 'package:flutter/material.dart';

class AppTheme {
  static ThemeData light() {
    const baseTextTheme = TextTheme(
      displayLarge: TextStyle(fontFamily: 'NotoSansJP'),
      displayMedium: TextStyle(fontFamily: 'NotoSansJP'),
      displaySmall: TextStyle(fontFamily: 'NotoSansJP'),
      headlineLarge: TextStyle(fontFamily: 'NotoSansJP'),
      headlineMedium: TextStyle(fontFamily: 'NotoSansJP'),
      headlineSmall: TextStyle(fontFamily: 'NotoSansJP'),
      titleLarge: TextStyle(fontFamily: 'NotoSansJP'),
      titleMedium: TextStyle(fontFamily: 'NotoSansJP'),
      titleSmall: TextStyle(fontFamily: 'NotoSansJP'),
      bodyLarge: TextStyle(fontFamily: 'NotoSansJP'),
      bodyMedium: TextStyle(fontFamily: 'NotoSansJP'),
      bodySmall: TextStyle(fontFamily: 'NotoSansJP'),
      labelLarge: TextStyle(fontFamily: 'NotoSansJP'),
      labelMedium: TextStyle(fontFamily: 'NotoSansJP'),
      labelSmall: TextStyle(fontFamily: 'NotoSansJP'),
    );

    return ThemeData(
      useMaterial3: true,
      fontFamily: 'NotoSansJP',
      textTheme: baseTextTheme,

      appBarTheme: const AppBarTheme(
        centerTitle: false,
        titleTextStyle: TextStyle(
          fontFamily: 'NotoSansJP',
          fontSize: 20,
          fontWeight: FontWeight.w700,
          color: Colors.black,
        ),
      ),

      scaffoldBackgroundColor: Colors.white,

      colorScheme: ColorScheme.fromSeed(
        seedColor: Colors.green,
      ),
    );
  }
}