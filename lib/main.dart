import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

import 'firebase_options.dart';
import 'screens/auth_gate.dart';
import 'theme/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  String? startupError;

  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  } catch (e) {
    startupError = e.toString();
  }

  runApp(VendingNaviApp(startupError: startupError));
}

class VendingNaviApp extends StatelessWidget {
  const VendingNaviApp({
    super.key,
    this.startupError,
  });

  final String? startupError;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '自販機ナビ',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      home: startupError == null
          ? const AuthGate()
          : StartupErrorScreen(message: startupError!),
    );
  }
}

class StartupErrorScreen extends StatelessWidget {
  const StartupErrorScreen({
    super.key,
    required this.message,
  });

  final String message;

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
                  Icons.error_outline_rounded,
                  size: 52,
                  color: theme.colorScheme.primary,
                ),
                const SizedBox(height: 12),
                Text(
                  '起動時にエラーが発生しました',
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
                Text(
                  'Firebase設定や初期化内容を確認してください。',
                  style: theme.textTheme.bodySmall,
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}