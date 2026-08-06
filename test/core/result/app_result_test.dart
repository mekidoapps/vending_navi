import 'package:flutter_test/flutter_test.dart';
import 'package:vending_app/core/errors/app_failure.dart';
import 'package:vending_app/core/result/app_result.dart';

void main() {
  group('AppResult', () {
    test('成功値をmapとfoldで扱える', () {
      const result = AppResult<int>.success(3);

      final mapped = result.map((int value) => value * 2);
      final message = mapped.fold(
        onSuccess: (int value) => 'value:$value',
        onFailure: (AppFailure failure) => failure.code,
      );

      expect(result.isSuccess, isTrue);
      expect(mapped.valueOrNull, 6);
      expect(message, 'value:6');
    });

    test('失敗時はmapを実行せずFailureを維持する', () {
      const failure = NetworkFailure();
      const result = AppResult<int>.failure(failure);
      var called = false;

      final mapped = result.map((int value) {
        called = true;
        return value.toString();
      });

      expect(called, isFalse);
      expect(mapped.isFailure, isTrue);
      expect(mapped.failureOrNull, same(failure));
      expect(mapped.valueOrNull, isNull);
    });

    test('flatMapで成功処理を連結できる', () {
      const result = AppResult<int>.success(4);

      final mapped = result.flatMap(
        (int value) => AppResult<String>.success('count:$value'),
      );

      expect(mapped.valueOrNull, 'count:4');
    });
  });
}
