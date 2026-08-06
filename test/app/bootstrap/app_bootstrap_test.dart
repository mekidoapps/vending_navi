import 'package:flutter_test/flutter_test.dart';
import 'package:vending_app/app/bootstrap/app_bootstrap.dart';
import 'package:vending_app/app/bootstrap/bootstrap_config.dart';

void main() {
  group('bootstrap', () {
    test('FirebaseとApp Checkの初期化に成功すると成功結果を返す', () async {
      var firebaseInitialized = false;
      var appCheckActivated = false;

      final result = await bootstrap(
        config: BootstrapConfig(
          initializeFirebase: () async {
            firebaseInitialized = true;
          },
          activateAppCheck: () async {
            appCheckActivated = true;
          },
        ),
      );

      expect(result.isSuccess, isTrue);
      expect(result.errorMessage, isNull);
      expect(firebaseInitialized, isTrue);
      expect(appCheckActivated, isTrue);
    });

    test('Firebase初期化に失敗すると失敗結果を返しApp Checkを実行しない', () async {
      var appCheckActivated = false;

      final result = await bootstrap(
        config: BootstrapConfig(
          initializeFirebase: () async {
            throw StateError('firebase initialization failed');
          },
          activateAppCheck: () async {
            appCheckActivated = true;
          },
        ),
      );

      expect(result.isSuccess, isFalse);
      expect(result.errorMessage, contains('firebase initialization failed'));
      expect(appCheckActivated, isFalse);
    });

    test('App Check初期化に失敗すると失敗結果を返す', () async {
      final result = await bootstrap(
        config: BootstrapConfig(
          initializeFirebase: () async {},
          activateAppCheck: () async {
            throw StateError('app check activation failed');
          },
        ),
      );

      expect(result.isSuccess, isFalse);
      expect(result.errorMessage, contains('app check activation failed'));
    });
  });
}
