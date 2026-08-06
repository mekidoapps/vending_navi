import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

import '../../firebase_options.dart';

typedef BootstrapStep = Future<void> Function();

@immutable
class BootstrapConfig {
  const BootstrapConfig({
    required this.initializeFirebase,
    required this.activateAppCheck,
  });

  factory BootstrapConfig.production() {
    return BootstrapConfig(
      initializeFirebase: () async {
        if (Firebase.apps.isEmpty) {
          await Firebase.initializeApp(
            options: DefaultFirebaseOptions.currentPlatform,
          );
        }
      },
      activateAppCheck: () async {
        await FirebaseAppCheck.instance.activate(
          androidProvider: kDebugMode
              ? AndroidProvider.debug
              : AndroidProvider.playIntegrity,
          appleProvider: kDebugMode
              ? AppleProvider.debug
              : AppleProvider.deviceCheck,
        );
      },
    );
  }

  final BootstrapStep initializeFirebase;
  final BootstrapStep activateAppCheck;
}
