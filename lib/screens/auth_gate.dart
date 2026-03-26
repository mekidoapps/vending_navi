import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/auth_provider.dart';
import '../widgets/common/loading_view.dart';
import 'login_screen.dart';
import 'onboarding_screen.dart';

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<AuthProvider>(
      builder: (BuildContext context, AuthProvider authProvider, _) {
        if (authProvider.isLoading && authProvider.currentUser == null) {
          return const LoadingView(
            fullScreen: true,
            message: '認証状態を確認しています…',
          );
        }

        if (authProvider.isLoggedIn) {
          return const OnboardingScreen();
        }

        return const LoginScreen();
      },
    );
  }
}