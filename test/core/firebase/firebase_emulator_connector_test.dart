import 'package:flutter_test/flutter_test.dart';
import 'package:vending_app/core/firebase/firebase_emulator_config.dart';
import 'package:vending_app/core/firebase/firebase_emulator_connector.dart';

void main() {
  group('FirebaseEmulatorConnector', () {
    test('有効時は4サービスへ決められた順番で接続する', () async {
      final calls = <String>[];
      const config = FirebaseEmulatorConfig(
        requested: true,
        releaseMode: false,
        host: ' 10.0.2.2 ',
      );

      final connector = FirebaseEmulatorConnector(
        config: config,
        connectAuth: (String host, int port) async {
          calls.add('auth:$host:$port');
        },
        connectFirestore: (String host, int port) async {
          calls.add('firestore:$host:$port');
        },
        connectFunctions: (String host, int port) async {
          calls.add('functions:$host:$port');
        },
        connectStorage: (String host, int port) async {
          calls.add('storage:$host:$port');
        },
      );

      await connector.connect();

      expect(calls, <String>[
        'auth:10.0.2.2:9099',
        'firestore:10.0.2.2:8080',
        'functions:10.0.2.2:5001',
        'storage:10.0.2.2:9199',
      ]);
    });

    test('未要求の場合はどのサービスにも接続しない', () async {
      var callCount = 0;
      const config = FirebaseEmulatorConfig(
        requested: false,
        releaseMode: false,
        host: '10.0.2.2',
      );

      Future<void> countCall(String host, int port) async {
        callCount += 1;
      }

      final connector = FirebaseEmulatorConnector(
        config: config,
        connectAuth: countCall,
        connectFirestore: countCall,
        connectFunctions: countCall,
        connectStorage: countCall,
      );

      await connector.connect();

      expect(callCount, 0);
    });

    test('release buildでは要求されても接続しない', () async {
      var callCount = 0;
      const config = FirebaseEmulatorConfig(
        requested: true,
        releaseMode: true,
        host: '10.0.2.2',
      );

      Future<void> countCall(String host, int port) async {
        callCount += 1;
      }

      final connector = FirebaseEmulatorConnector(
        config: config,
        connectAuth: countCall,
        connectFirestore: countCall,
        connectFunctions: countCall,
        connectStorage: countCall,
      );

      await connector.connect();

      expect(callCount, 0);
    });
  });
}
