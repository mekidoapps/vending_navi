import 'package:flutter/material.dart';

class AppColors {

  /// 基本カラー
  static const primary = Color(0xFF4DB6E5); // 水色
  static const background = Color(0xFFF7F9FB); // ややグレー白
  static const surface = Colors.white;

  /// テキスト
  static const textPrimary = Color(0xFF222222);
  static const textSecondary = Color(0xFF777777);

  /// ボーダー
  static const border = Color(0xFFE3E6EB);

  /// 成功 / 注意
  static const success = Color(0xFF4CAF50);
  static const warning = Color(0xFFFFC107);

  /// くすみカラー（アクセント）
  static const mutedBlue = Color(0xFF8FAFD9);
  static const mutedGreen = Color(0xFF9CCFB8);
  static const mutedOrange = Color(0xFFE6B89C);
  static const mutedPurple = Color(0xFFC2A4E0);

  static const List<String> checkinStatuses = [
    'available',
    'sold_out',
    'out_of_order',
  ];
}