import 'package:flutter_test/flutter_test.dart';
import 'package:vending_app/features/product_master/data/legacy/legacy_name_normalizer.dart';

void main() {
  test('ひらがな・波線・ダッシュ・空白の揺れを移行用に正規化する', () {
    expect(LegacyNameNormalizer.normalize('  お〜いお茶  -  緑茶  '), 'オ～イオ茶-緑茶');
    expect(LegacyNameNormalizer.normalize('お~いお茶 - 緑茶'), 'オ～イオ茶-緑茶');
  });
}
