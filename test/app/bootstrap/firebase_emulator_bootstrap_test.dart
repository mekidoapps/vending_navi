import 'package:flutter_test/flutter_test.dart';
import 'package:vending_app/app/bootstrap/app_bootstrap.dart';
import 'package:vending_app/app/bootstrap/bootstrap_config.dart';

void main() {
  test('Firebase初期化・Emulator接続・App Checkの順に実行する', () async {
    final calls = <String>[];

    final result = await bootstrap(
      config: BootstrapConfig(
        initializeFirebase: () async {
          calls.add('firebase');
        },
        connectFirebaseEmulators: () async {
          calls.add('emulators');
        },
        activateAppCheck: () async {
          calls.add('app-check');
        },
      ),
    );

    expect(result.isSuccess, isTrue);
    expect(calls, <String>['firebase', 'emulators', 'app-check']);
  });

  test('Emulator接続に失敗した場合はApp Checkを実行しない', () async {
    var appCheckActivated = false;

    final result = await bootstrap(
      config: BootstrapConfig(
        initializeFirebase: () async {},
        connectFirebaseEmulators: () async {
          throw StateError('emulator connection failed');
        },
        activateAppCheck: () async {
          appCheckActivated = true;
        },
      ),
    );

    expect(result.isSuccess, isFalse);
    expect(result.errorMessage, contains('emulator connection failed'));
    expect(appCheckActivated, isFalse);
  });
}
