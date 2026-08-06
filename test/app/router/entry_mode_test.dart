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
}
