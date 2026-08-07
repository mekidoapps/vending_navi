import 'package:flutter_test/flutter_test.dart';
import 'package:vending_app/features/product_master/data/fixtures/product_master_fixture.dart';

void main() {
  group('ProductMasterFixture', () {
    test('Product IDとManufacturer IDが重複しない', () {
      final productIds = ProductMasterFixture.products
          .map((product) => product.id.value)
          .toList(growable: false);
      final manufacturerIds = ProductMasterFixture.manufacturers
          .map((manufacturer) => manufacturer.id.value)
          .toList(growable: false);

      expect(productIds.toSet().length, productIds.length);
      expect(manufacturerIds.toSet().length, manufacturerIds.length);
    });

    test('全商品が存在するメーカーと最低1ジャンルを参照する', () {
      final manufacturerIds = ProductMasterFixture.manufacturers
          .map((manufacturer) => manufacturer.id)
          .toSet();

      for (final product in ProductMasterFixture.products) {
        expect(manufacturerIds, contains(product.manufacturerId));
        expect(product.genres, isNotEmpty);
      }
    });

    test('unknownやotherを架空メーカーとして登録しない', () {
      final ids = ProductMasterFixture.manufacturers
          .map((manufacturer) => manufacturer.id.value)
          .toSet();

      expect(ids, isNot(contains('unknown')));
      expect(ids, isNot(contains('other')));
    });

    test('各メーカーのpresetProductIdsがfixture商品と一致する', () {
      for (final manufacturer in ProductMasterFixture.manufacturers) {
        final expected = ProductMasterFixture.products
            .where((product) => product.manufacturerId == manufacturer.id)
            .map((product) => product.id)
            .toSet();

        expect(manufacturer.presetProductIds.toSet(), expected);
      }
    });
  });
}
