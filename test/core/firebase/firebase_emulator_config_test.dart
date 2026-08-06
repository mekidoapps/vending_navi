import 'package:flutter_test/flutter_test.dart';
import 'package:vending_app/core/firebase/firebase_emulator_config.dart';

void main() {
  group('FirebaseEmulatorConfig', () {
    test('要求されていて非releaseの場合だけ有効になる', () {
      const enabled = FirebaseEmulatorConfig(
        requested: true,
        releaseMode: false,
        host: '10.0.2.2',
      );
      const notRequested = FirebaseEmulatorConfig(
        requested: false,
        releaseMode: false,
        host: '10.0.2.2',
      );
      const release = FirebaseEmulatorConfig(
        requested: true,
        releaseMode: true,
        host: '10.0.2.2',
      );

      expect(enabled.enabled, isTrue);
      expect(notRequested.enabled, isFalse);
      expect(release.enabled, isFalse);
      expect(release.blockedByReleaseMode, isTrue);
    });

    test('有効時に空のhostを拒否する', () {
      const config = FirebaseEmulatorConfig(
        requested: true,
        releaseMode: false,
        host: '   ',
      );

      expect(config.validate, throwsA(isA<FormatException>()));
    });

    test('有効時に範囲外のportを拒否する', () {
      const config = FirebaseEmulatorConfig(
        requested: true,
        releaseMode: false,
        host: '10.0.2.2',
        firestorePort: 70000,
      );

      expect(config.validate, throwsA(isA<RangeError>()));
    });

    test('無効時はhostとportを検証しない', () {
      const config = FirebaseEmulatorConfig(
        requested: false,
        releaseMode: false,
        host: '',
        authPort: 0,
      );

      expect(config.validate, returnsNormally);
    });
  });
}
