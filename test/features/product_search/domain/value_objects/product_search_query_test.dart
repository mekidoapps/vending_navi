import 'package:flutter_test/flutter_test.dart';
import 'package:vending_app/features/product_search/domain/value_objects/product_search_query.dart';

void main() {
  group('ProductSearchNormalizer', () {
    test('空白・記号・大小文字を検索用に正規化する', () {
      expect(ProductSearchNormalizer.normalize(' BOSS・ブラック '), 'bossブラック');
      expect(ProductSearchNormalizer.normalize('C.C. レモン'), 'ccレモン');
    });

    test('日本語全角空白を除去する', () {
      expect(ProductSearchNormalizer.normalize('午後の紅茶　ミルクティー'), '午後ノ紅茶ミルクティー');
    });

    test('ひらがなとカタカナを同一視する', () {
      expect(
        ProductSearchNormalizer.normalize('あやたか'),
        ProductSearchNormalizer.normalize('アヤタカ'),
      );
      expect(
        ProductSearchNormalizer.normalize('ぽかり'),
        ProductSearchNormalizer.normalize('ポカリ'),
      );
    });

    test('全角英数字と半角英数字を同一視する', () {
      expect(ProductSearchNormalizer.normalize('ＢＯＳＳ ＢＬＡＣＫ'), 'bossblack');
      expect(
        ProductSearchNormalizer.normalize('１６茶'),
        ProductSearchNormalizer.normalize('16茶'),
      );
    });

    test('波線と長音の表記揺れを同一視する', () {
      expect(
        ProductSearchNormalizer.normalize('お〜いお茶'),
        ProductSearchNormalizer.normalize('おーいお茶'),
      );
      expect(
        ProductSearchNormalizer.normalize('お～いお茶'),
        ProductSearchNormalizer.normalize('おーいお茶'),
      );
    });

    test('中黒・空白・ハイフンなどの区切りを無視する', () {
      expect(
        ProductSearchNormalizer.normalize('コカ・コーラ'),
        ProductSearchNormalizer.normalize('コカコーラ'),
      );
      expect(
        ProductSearchNormalizer.normalize('coca-cola'),
        ProductSearchNormalizer.normalize('coca cola'),
      );
    });
  });

  test('空白だけはempty queryになる', () {
    expect(ProductSearchQuery('  　').isEmpty, isTrue);
  });
}
