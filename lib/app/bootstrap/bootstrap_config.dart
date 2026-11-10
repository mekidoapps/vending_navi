import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

import '../../core/firebase/firebase_emulator_config.dart';
import '../../core/firebase/firebase_emulator_connector.dart';
import '../../firebase_options.dart';
import '../../core/errors/capture_diagnostics.dart';

typedef BootstrapStep = Future<void> Function();

@immutable
class BootstrapConfig {
  const BootstrapConfig({
    required this.initializeFirebase,
    this.connectFirebaseEmulators,
    required this.activateAppCheck,
  });

  factory BootstrapConfig.production() {
    final emulatorConfig = FirebaseEmulatorConfig.fromEnvironment();

    return BootstrapConfig(
      initializeFirebase: () async {
        if (Firebase.apps.isEmpty) {
          await Firebase.initializeApp(
            options: DefaultFirebaseOptions.currentPlatform,
          );
        }
      },
      connectFirebaseEmulators: () async {
        await FirebaseEmulatorConnector.production(emulatorConfig).connect();
      },
      activateAppCheck: () async {
        // Emulator Suite does not need a production App Check token.
        if (emulatorConfig.enabled) {
          return;
        }

        await FirebaseAppCheck.instance.activate(
          androidProvider: kDebugMode
              ? AndroidProvider.debug
              : AndroidProvider.playIntegrity,
          appleProvider: kDebugMode
              ? AppleProvider.debug
              : AppleProvider.deviceCheck,
        );
        if (CaptureDiagnostics.enabled) {
          final token = await CaptureDiagnostics.trace(
            'appcheck', () => FirebaseAppCheck.instance.getToken(true));
          if (token == null || token.isEmpty) {
            CaptureDiagnostics.emit('appcheck', 'unknown');
            throw StateError('Capture App Check probe failed');
          }
          CaptureDiagnostics.emit('appcheck', 'accepted');
        }
      },
    );
  }

  final BootstrapStep initializeFirebase;
  final BootstrapStep? connectFirebaseEmulators;
  final BootstrapStep activateAppCheck;
}
