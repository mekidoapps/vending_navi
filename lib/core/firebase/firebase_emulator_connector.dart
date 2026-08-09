import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';

import 'firebase_emulator_config.dart';

typedef EmulatorConnectorStep = Future<void> Function(String host, int port);

@immutable
class FirebaseEmulatorConnector {
  /// VendingNavi resolves the emulator host explicitly via dart-define.
  ///
  /// Physical Android devices use 127.0.0.1 with adb reverse.
  /// Android emulators use 10.0.2.2 explicitly.
  /// FlutterFire's automatic Android host mapping must therefore stay off.
  static const bool automaticHostMapping = false;

  const FirebaseEmulatorConnector({
    required this.config,
    required this.connectAuth,
    required this.connectFirestore,
    required this.connectFunctions,
    required this.connectStorage,
  });

  factory FirebaseEmulatorConnector.production(FirebaseEmulatorConfig config) {
    return FirebaseEmulatorConnector(
      config: config,
      connectAuth: (String host, int port) async {
        await FirebaseAuth.instance.useAuthEmulator(
          host,
          port,
          automaticHostMapping: automaticHostMapping,
        );
      },
      connectFirestore: (String host, int port) async {
        FirebaseFirestore.instance.useFirestoreEmulator(
          host,
          port,
          automaticHostMapping: automaticHostMapping,
        );
      },
      connectFunctions: (String host, int port) async {
        FirebaseFunctions.instance.useFunctionsEmulator(
          host,
          port,
          automaticHostMapping: automaticHostMapping,
        );
      },
      connectStorage: (String host, int port) async {
        await FirebaseStorage.instance.useStorageEmulator(
          host,
          port,
          automaticHostMapping: automaticHostMapping,
        );
      },
    );
  }

  final FirebaseEmulatorConfig config;
  final EmulatorConnectorStep connectAuth;
  final EmulatorConnectorStep connectFirestore;
  final EmulatorConnectorStep connectFunctions;
  final EmulatorConnectorStep connectStorage;

  Future<void> connect() async {
    if (!config.enabled) {
      if (config.blockedByReleaseMode) {
        debugPrint(
          'Firebase Emulator connection was ignored in a release build.',
        );
      }
      return;
    }

    config.validate();
    final host = config.host.trim();

    await connectAuth(host, config.authPort);
    await connectFirestore(host, config.firestorePort);
    await connectFunctions(host, config.functionsPort);
    await connectStorage(host, config.storagePort);

    debugPrint(
      'Firebase Emulator Suite connected '
      '(host=$host, auth=${config.authPort}, '
      'firestore=${config.firestorePort}, '
      'functions=${config.functionsPort}, '
      'storage=${config.storagePort}).',
    );
  }
}
