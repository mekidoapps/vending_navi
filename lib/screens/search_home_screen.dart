import 'package:flutter/material.dart';
import 'main_shell_screen.dart';

/// 旧ホーム画面名との互換用ラッパー。
/// 既存コードで SearchHomeScreen を参照していても、
/// 実体は MainShellScreen を使うように統一する。
class SearchHomeScreen extends StatelessWidget {
  const SearchHomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const MainShellScreen();
  }
}