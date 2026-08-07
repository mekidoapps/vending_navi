import 'package:flutter_test/flutter_test.dart';
import 'package:vending_app/features/product_search/domain/value_objects/product_search_query.dart';

void main() {
  group('ProductSearchNormalizer', () {
    test('空白・記号・大小文字を検索用に正規化する', () {
      expect(ProductSearchNormalizer.normalize(' BOSS・ブラック '), 'bossブラック');
      expect(ProductSearchNormalizer.normalize('C.C. レモン'), 'ccレモン');
    });

    test('日本語全角空白を除去する', () {
      expect(ProductSearchNormalizer.normalize('午後の紅茶　ミルクティー'), '午後の紅茶ミルクティー');
    });
  });

  test('空白だけはempty queryになる', () {
    expect(ProductSearchQuery('  　').isEmpty, isTrue);
  });
}
