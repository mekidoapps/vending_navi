import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../providers/auth_provider.dart';
import '../widgets/common/loading_view.dart';
import 'login_screen.dart';
import 'main_screen.dart';
import 'onboarding_screen.dart';

class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  bool? _onboardingDone;

  @override
  void initState() {
    super.initState();
    _loadOnboardingFlag();
  }

  Future<void> _loadOnboardingFlag() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      _onboardingDone = prefs.getBool('onboarding_done') ?? false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AuthProvider>(
      builder: (BuildContext context, AuthProvider authProvider, _) {
        // 認証状態 or フラグ読み込み中
        if (authProvider.isLoading || _onboardingDone == null) {
          return const LoadingView(
            fullScreen: true,
            message: '認証状態を確認しています…',
          );
        }

        // 未ログイン
        if (!authProvider.isLoggedIn) {
          return const LoginScreen();
        }

        // ログイン済み・初回 → オンボーディング
        if (!_onboardingDone!) {
          return const OnboardingScreen();
        }

        // ログイン済み・オンボーディング完了 → メイン画面
        return const MainScreen();
      },
    );
  }
}
