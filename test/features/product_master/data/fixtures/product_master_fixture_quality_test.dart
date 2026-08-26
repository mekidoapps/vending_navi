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

    test('manufacturer presetは拡充前の33代表商品に限定する', () {
      const expectedCounts = <String, int>{
        'coca_cola': 6,
        'suntory': 5,
        'ito_en': 5,
        'kirin': 5,
        'asahi': 6,
        'dydo': 3,
        'otsuka': 3,
      };

      var totalPresetCount = 0;

      for (final manufacturer in manufacturers) {
        final presetIds = manufacturer.presetProductIds
            .map((productId) => productId.value)
            .toList(growable: false);

        expect(
          presetIds.length,
          expectedCounts[manufacturer.id.value],
          reason: '${manufacturer.id.value}: unexpected preset count',
        );

        expect(
          presetIds.toSet().length,
          presetIds.length,
          reason: '${manufacturer.id.value}: duplicate preset product',
        );

        totalPresetCount += presetIds.length;

        for (final presetId in manufacturer.presetProductIds) {
          final matches = products
              .where((product) => product.id == presetId)
              .toList(growable: false);

          expect(
            matches.length,
            1,
            reason:
                '${manufacturer.id.value}: missing preset ${presetId.value}',
          );

          expect(
            matches.single.manufacturerId,
            manufacturer.id,
            reason:
                '${manufacturer.id.value}: preset belongs to another manufacturer',
          );
        }
      }

      expect(totalPresetCount, 33);
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
