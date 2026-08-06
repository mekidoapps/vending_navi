import 'package:flutter_test/flutter_test.dart';
import 'package:vending_app/features/product_master/domain/entities/product.dart';
import 'package:vending_app/features/product_master/domain/entities/product_genre.dart';
import 'package:vending_app/features/product_master/domain/value_objects/master_id.dart';

void main() {
  final createdAt = DateTime.utc(2026, 8, 1);
  final updatedAt = DateTime.utc(2026, 8, 6);

  test('表示名と検索キーワードを重複なしの検索語として扱う', () {
    final product = Product(
      id: ProductId.parse('coca_cola_ayataka'),
      name: '綾鷹',
      manufacturerId: ManufacturerId.parse('coca_cola'),
      searchKeywords: const <String>['あやたか', '綾鷹', ' ayataka '],
      genres: const <ProductGenre>[ProductGenre.greenTea],
      createdAt: createdAt,
      updatedAt: updatedAt,
    );

    expect(product.isSelectable, isTrue);
    expect(product.searchTerms, <String>{'綾鷹', 'あやたか', 'ayataka'});
  });

  test('無効商品は検索・選択候補として扱わない', () {
    final product = Product(
      id: ProductId.parse('coca_cola_discontinued_product'),
      name: '終売商品',
      manufacturerId: ManufacturerId.parse('coca_cola'),
      isActive: false,
      createdAt: createdAt,
      updatedAt: updatedAt,
    );

    expect(product.isSelectable, isFalse);
  });
}
