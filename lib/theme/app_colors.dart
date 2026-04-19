import 'package:flutter/material.dart';

class AppColors {
  AppColors._();

  static const Color primary = Color(0xFF4A90E2);
  static const Color accent = Color(0xFF6FCF97);
  static const Color background = Color(0xFFF7F8FA);
  static const Color card = Colors.white;
  static const Color textPrimary = Color(0xFF222222);
  static const Color textSecondary = Color(0xFF666666);
  static const Color border = Color(0xFFE0E0E0);
  static const Color error = Color(0xFFE53935);

  static Color manufacturerColor(String manufacturer) {
    switch (manufacturer.trim()) {
      case 'コカ・コーラ':
      case 'コカコーラ':
        return const Color(0xFFE53935);

      case 'サントリー':
        return const Color(0xFF1E88E5);

      case '伊藤園':
        return const Color(0xFF43A047);

      case 'キリン':
        return const Color(0xFFF9A825);

      case 'アサヒ':
        return const Color(0xFFFB8C00);

      case '大塚製薬':
        return const Color(0xFF3949AB);

      case 'AQUO':
        return const Color(0xFF00ACC1);

      case 'ダイドー':
        return const Color(0xFF8E24AA);

      default:
        return const Color(0xFFEC407A);
    }
  }
}