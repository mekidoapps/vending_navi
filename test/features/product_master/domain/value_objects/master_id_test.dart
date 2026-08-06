import 'package:flutter_test/flutter_test.dart';
import 'package:vending_app/features/product_master/domain/value_objects/master_id.dart';

void main() {
  group('MasterIdRules', () {
    test('小文字snake_caseのIDを受け入れる', () {
      expect(MasterIdRules.isValid('coca_cola'), isTrue);
      expect(MasterIdRules.isValid('coca_cola_ayataka'), isTrue);
      expect(MasterIdRules.isValid('p2'), isTrue);
    });

    test('大文字・空白・連続underscore・先頭数字を拒否する', () {
      expect(MasterIdRules.isValid('CocaCola'), isFalse);
      expect(MasterIdRules.isValid('coca cola'), isFalse);
      expect(MasterIdRules.isValid('coca__cola'), isFalse);
      expect(MasterIdRules.isValid('2product'), isFalse);
      expect(MasterIdRules.isValid(' coca_cola'), isFalse);
    });
  });

  group('ProductId', () {
    test('同じ種別と値なら等価になる', () {
      final first = ProductId.parse('suntory_boss_black');
      final second = ProductId.parse('suntory_boss_black');

      expect(first, second);
      expect(first.value, 'suntory_boss_black');
    });

    test('不正なIDはparseで例外、tryParseでnullになる', () {
      expect(
        () => ProductId.parse('BOSS BLACK'),
        throwsA(isA<FormatException>()),
      );
      expect(ProductId.tryParse('BOSS BLACK'), isNull);
    });
  });

  test('ProductIdとManufacturerIdは同じ文字列でも等価にならない', () {
    final productId = ProductId.parse('suntory');
    final manufacturerId = ManufacturerId.parse('suntory');

    expect(productId, isNot(manufacturerId));
  });
}
