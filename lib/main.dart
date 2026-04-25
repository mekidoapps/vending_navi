import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'firebase_options.dart';
import 'screens/startup_router_screen.dart';
import 'theme/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  String? startupError;

  try {
    if (Firebase.apps.isEmpty) {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
    }

    await FirebaseAppCheck.instance.activate(
      androidProvider:
      kDebugMode ? AndroidProvider.debug : AndroidProvider.playIntegrity,
      appleProvider:
      kDebugMode ? AppleProvider.debug : AppleProvider.deviceCheck,
    );
  } catch (e) {
    startupError = e.toString();
  }

  runApp(VendingApp(startupError: startupError));
}

class VendingApp extends StatelessWidget {
  const VendingApp({
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
          ? const StartupRouterScreen()
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
    return Scaffold(
      backgroundColor: const Color(0xFFEAF6FF),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: const Color(0xFFE3E7EB)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                const Icon(
                  Icons.error_outline_rounded,
                  size: 44,
                  color: Colors.redAccent,
                ),
                const SizedBox(height: 12),
                const Text(
                  '起動に失敗しました',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF334148),
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  message,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 13,
                    color: Color(0xFF60707A),
                    height: 1.6,
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