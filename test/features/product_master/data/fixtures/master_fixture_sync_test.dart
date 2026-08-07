import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:vending_app/features/product_master/data/fixtures/product_master_fixture.dart';

void main() {
  test('Functions seed fixtureとDart固定fixtureのID・主要値が一致する', () {
    final file = File('functions/fixtures/master_fixture.json');
    expect(file.existsSync(), isTrue);

    final json = jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
    final products = (json['products'] as List<dynamic>)
        .cast<Map<String, dynamic>>();
    final manufacturers = (json['manufacturers'] as List<dynamic>)
        .cast<Map<String, dynamic>>();

    expect(
      products.map((item) => item['id']).toSet(),
      ProductMasterFixture.products.map((product) => product.id.value).toSet(),
    );
    expect(
      manufacturers.map((item) => item['id']).toSet(),
      ProductMasterFixture.manufacturers
          .map((manufacturer) => manufacturer.id.value)
          .toSet(),
    );

    for (final product in ProductMasterFixture.products) {
      final item = products.singleWhere(
        (candidate) => candidate['id'] == product.id.value,
      );

      expect(item['name'], product.name);
      expect(item['manufacturerId'], product.manufacturerId.value);
      expect(
        (item['searchKeywords'] as List<dynamic>).cast<String>(),
        product.searchKeywords,
      );
      expect(
        (item['genreIds'] as List<dynamic>).cast<String>(),
        product.genres.map((genre) => genre.id).toList(growable: false),
      );
    }

    for (final manufacturer in ProductMasterFixture.manufacturers) {
      final item = manufacturers.singleWhere(
        (candidate) => candidate['id'] == manufacturer.id.value,
      );

      expect(item['name'], manufacturer.name);
      expect(item['displayShortName'], manufacturer.displayShortName);
      expect(
        (item['presetProductIds'] as List<dynamic>).cast<String>(),
        manufacturer.presetProductIds
            .map((productId) => productId.value)
            .toList(growable: false),
      );
    }
  });
}
