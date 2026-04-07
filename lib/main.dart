import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

import 'firebase_options.dart';
import 'screens/auth_gate.dart';
import 'services/nearby_favorite_notification_service.dart';
import 'theme/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  String? startupError;

  try {
    await _initializeFirebaseSafely();
    await NearbyFavoriteNotificationService.initialize();
  } catch (e) {
    startupError = e.toString();
  }

  runApp(VendingApp(startupError: startupError));
}

Future<void> _initializeFirebaseSafely() async {
  if (Firebase.apps.isNotEmpty) {
    return;
  }

  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  } catch (e) {
    final message = e.toString();

    if (message.contains('duplicate-app') ||
        message.contains('already exists')) {
      return;
    }

    rethrow;
  }
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
    return Scaffold(
      appBar: AppBar(
        title: const Text('起動エラー'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: SelectableText(message),
      ),
    );
  }
}