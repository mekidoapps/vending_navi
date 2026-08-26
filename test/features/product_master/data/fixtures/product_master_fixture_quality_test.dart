import 'package:flutter_test/flutter_test.dart';
import 'package:vending_app/features/product_master/data/fixtures/product_master_fixture.dart';

void main() {
  group('ProductMasterFixture release quality', () {
    final products = ProductMasterFixture.products;
    final manufacturers = ProductMasterFixture.manufacturers;

    test('初回公開マスタは96商品・7メーカー', () {
      expect(products.length, 96);
      expect(manufacturers.length, 7);
    });

    test('Product IDが重複しない', () {
      final ids = products.map((product) => product.id.value).toList();

      expect(ids.toSet().length, ids.length);
    });

    test('正式商品名が重複しない', () {
      final names = products.map((product) => product.name.trim()).toList();

      expect(names.toSet().length, names.length);
    });

    test('全商品のmanufacturerIdがメーカーMasterに存在する', () {
      final manufacturerIds = manufacturers
          .map((manufacturer) => manufacturer.id.value)
          .toSet();

      for (final product in products) {
        expect(
          manufacturerIds,
          contains(product.manufacturerId.value),
          reason:
              '${product.id.value}: unknown manufacturer '
              '${product.manufacturerId.value}',
        );
      }
    });

    test('全商品に正式名・検索keyword・genreが設定されている', () {
      for (final product in products) {
        expect(
          product.name.trim(),
          isNotEmpty,
          reason: '${product.id.value}: empty name',
        );

        expect(
          product.searchKeywords,
          isNotEmpty,
          reason: '${product.id.value}: searchKeywords is empty',
        );

        expect(
          product.searchKeywords.every((keyword) => keyword.trim().isNotEmpty),
          isTrue,
          reason: '${product.id.value}: empty searchKeyword',
        );

        expect(
          product.genres,
          isNotEmpty,
          reason: '${product.id.value}: genres is empty',
        );
      }
    });

    test('全商品が初回公開時点でactive', () {
      for (final product in products) {
        expect(
          product.isActive,
          isTrue,
          reason: '${product.id.value}: inactive product',
        );
      }
    });
  });
}
