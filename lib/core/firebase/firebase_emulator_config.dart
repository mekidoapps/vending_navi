import 'package:flutter/foundation.dart';

@immutable
class FirebaseEmulatorConfig {
  const FirebaseEmulatorConfig({
    required this.requested,
    required this.releaseMode,
    required this.host,
    this.authPort = 9099,
    this.firestorePort = 8080,
    this.functionsPort = 5001,
    this.storagePort = 9199,
  });

  factory FirebaseEmulatorConfig.fromEnvironment() {
    return FirebaseEmulatorConfig(
      requested: const bool.fromEnvironment(
        'USE_FIREBASE_EMULATORS',
        defaultValue: false,
      ),
      releaseMode: kReleaseMode,
      host: const String.fromEnvironment(
        'FIREBASE_EMULATOR_HOST',
        defaultValue: '10.0.2.2',
      ),
      authPort: const int.fromEnvironment(
        'FIREBASE_AUTH_EMULATOR_PORT',
        defaultValue: 9099,
      ),
      firestorePort: const int.fromEnvironment(
        'FIRESTORE_EMULATOR_PORT',
        defaultValue: 8080,
      ),
      functionsPort: const int.fromEnvironment(
        'FIREBASE_FUNCTIONS_EMULATOR_PORT',
        defaultValue: 5001,
      ),
      storagePort: const int.fromEnvironment(
        'FIREBASE_STORAGE_EMULATOR_PORT',
        defaultValue: 9199,
      ),
    );
  }

  final bool requested;
  final bool releaseMode;
  final String host;
  final int authPort;
  final int firestorePort;
  final int functionsPort;
  final int storagePort;

  bool get enabled => requested && !releaseMode;

  bool get blockedByReleaseMode => requested && releaseMode;

  void validate() {
    if (!enabled) {
      return;
    }

    if (host.trim().isEmpty) {
      throw const FormatException('FIREBASE_EMULATOR_HOST must not be empty.');
    }

    _validatePort('FIREBASE_AUTH_EMULATOR_PORT', authPort);
    _validatePort('FIRESTORE_EMULATOR_PORT', firestorePort);
    _validatePort('FIREBASE_FUNCTIONS_EMULATOR_PORT', functionsPort);
    _validatePort('FIREBASE_STORAGE_EMULATOR_PORT', storagePort);
  }

  void _validatePort(String name, int port) {
    if (port < 1 || port > 65535) {
      throw RangeError.range(port, 1, 65535, name);
    }
  }
}
