import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'main_shell_screen.dart';

class AuthGate extends StatelessWidget {
  const AuthGate({
    super.key,
    this.initialMachineId,
  });

  final String? initialMachineId;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const _AuthLoadingScreen();
        }

        if (snapshot.hasError) {
          return _AuthErrorScreen(
            message: snapshot.error.toString(),
            initialMachineId: initialMachineId,
          );
        }

        final user = snapshot.data;

        return MainShellScreen(
          key: ValueKey<String?>(
            user?.uid ?? 'guest',
          ),
          initialMachineId: initialMachineId,
        );
      },
    );
  }
}

class _AuthLoadingScreen extends StatelessWidget {
  const _AuthLoadingScreen();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 320),
          margin: const EdgeInsets.all(24),
          padding: const EdgeInsets.symmetric(
            horizontal: 20,
            vertical: 24,
          ),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(
              color: const Color(0xFFE3E7EB),
            ),
            boxShadow: const [
              BoxShadow(
                color: Color(0x14000000),
                blurRadius: 18,
                offset: Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(
                width: 36,
                height: 36,
                child: CircularProgressIndicator(),
              ),
              const SizedBox(height: 14),
              Text(
                '自販機ナビを準備しています',
                style: theme.textTheme.titleMedium,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 6),
              Text(
                'ログイン状態を確認中です。',
                style: theme.textTheme.bodySmall,
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AuthErrorScreen extends StatelessWidget {
  const _AuthErrorScreen({
    required this.message,
    required this.initialMachineId,
  });

  final String message;
  final String? initialMachineId;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Container(
            constraints: const BoxConstraints(maxWidth: 560),
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(22),
              border: Border.all(
                color: const Color(0xFFE3E7EB),
              ),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x14000000),
                  blurRadius: 18,
                  offset: Offset(0, 8),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.warning_amber_rounded,
                  size: 52,
                  color: theme.colorScheme.primary,
                ),
                const SizedBox(height: 12),
                Text(
                  'ログイン状態の確認に失敗しました',
                  style: theme.textTheme.titleLarge,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 10),
                SelectableText(
                  message,
                  style: theme.textTheme.bodyMedium,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () {
                      Navigator.of(context).pushReplacement(
                        MaterialPageRoute<void>(
                          builder: (_) => MainShellScreen(
                            initialMachineId: initialMachineId,
                          ),
                        ),
                      );
                    },
                    icon: const Icon(Icons.map_rounded),
                    label: const Text('ゲストとして続ける'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}