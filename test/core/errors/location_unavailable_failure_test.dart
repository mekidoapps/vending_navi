import 'package:flutter_test/flutter_test.dart';
import 'package:vending_app/core/errors/app_failure.dart';

void main() {
  test('位置取得失敗用の安全な表示文言を持つ', () {
    const failure = LocationUnavailableFailure();

    expect(failure.code, 'location.unavailable');
    expect(failure.userTitle, '現在地を取得できませんでした');
    expect(failure.isRetryable, isTrue);
  });
}
