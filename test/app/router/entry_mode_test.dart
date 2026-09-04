import 'package:flutter_test/flutter_test.dart';
import 'package:vending_app/app/router/entry_mode.dart';

void main() {
  group('AppEntryMode.fromValue', () {
    test('v2を指定するとv2になる', () {
      expect(AppEntryMode.fromValue('v2'), AppEntryMode.v2);
    });

    test('legacyまたはv1を指定するとlegacyになる', () {
      expect(AppEntryMode.fromValue('legacy'), AppEntryMode.legacy);
      expect(AppEntryMode.fromValue('v1'), AppEntryMode.legacy);
    });

    test('空・null・不明な値はlegacyへフォールバックする', () {
      expect(AppEntryMode.fromValue(''), AppEntryMode.legacy);
      expect(AppEntryMode.fromValue(null), AppEntryMode.legacy);
      expect(AppEntryMode.fromValue('unknown'), AppEntryMode.legacy);
    });
  });

  group('AppEntryMode.resolve release guard', () {
    test('release + APP_ENTRY=v2 is allowed', () {
      expect(
        AppEntryMode.resolve(appEntry: 'v2', isReleaseBuild: true),
        AppEntryMode.v2,
      );
    });

    test('release + missing APP_ENTRY is rejected', () {
      expect(
        () => AppEntryMode.resolve(appEntry: null, isReleaseBuild: true),
        throwsStateError,
      );
    });

    test('release + legacy APP_ENTRY is rejected', () {
      expect(
        () => AppEntryMode.resolve(appEntry: 'legacy', isReleaseBuild: true),
        throwsStateError,
      );
    });

    test('debug/profile resolution preserves legacy development entry', () {
      expect(
        AppEntryMode.resolve(appEntry: null, isReleaseBuild: false),
        AppEntryMode.legacy,
      );
      expect(
        AppEntryMode.resolve(appEntry: 'legacy', isReleaseBuild: false),
        AppEntryMode.legacy,
      );
      expect(
        AppEntryMode.resolve(appEntry: 'v2', isReleaseBuild: false),
        AppEntryMode.v2,
      );
    });
  });
}
