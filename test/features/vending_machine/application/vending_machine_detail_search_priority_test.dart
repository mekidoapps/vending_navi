import 'package:flutter_test/flutter_test.dart';
import 'package:vending_app/features/product_master/data/fixtures/product_master_fixture.dart';
import 'package:vending_app/features/product_master/domain/entities/product_genre.dart';
import 'package:vending_app/features/product_master/domain/value_objects/master_id.dart';
import 'package:vending_app/features/vending_machine/application/models/vending_machine_detail_data.dart';
import 'package:vending_app/features/vending_machine/application/vending_machine_detail_search_priority.dart';
import 'package:vending_app/features/vending_machine/domain/entities/vending_machine_enums.dart';

void main() {
  final boss = ProductMasterFixture.products.firstWhere(
    (product) => product.id.value == 'suntory_boss_black',
  );

  test('商品検索時はevidenceが弱くても検索対象商品を先頭へ出す', () {
    final ordered = VendingMachineDetailSearchPriority.orderedProducts(
      products: <VendingMachineProductDetailItem>[
        _item(
          id: 'suntory_tennensui',
          name: 'サントリー天然水',
          evidence: ProductEvidenceType.manualConfirmed,
          genres: const <ProductGenre>[ProductGenre.water],
        ),
        _item(
          id: 'suntory_boss_black',
          name: 'BOSS ブラック',
          evidence: ProductEvidenceType.manufacturerInferred,
          genres: const <ProductGenre>[ProductGenre.coffee],
        ),
      ],
      selectedProduct: boss,
      selectedGenre: null,
    );

    expect(ordered.first.productId, boss.id);
  });

  test('Genre検索時は該当Genreの商品群を非該当商品より先に出す', () {
    final ordered = VendingMachineDetailSearchPriority.orderedProducts(
      products: <VendingMachineProductDetailItem>[
        _item(
          id: 'suntory_tennensui',
          name: 'サントリー天然水',
          evidence: ProductEvidenceType.manualConfirmed,
          genres: const <ProductGenre>[ProductGenre.water],
        ),
        _item(
          id: 'suntory_boss_black',
          name: 'BOSS ブラック',
          evidence: ProductEvidenceType.manufacturerInferred,
          genres: const <ProductGenre>[ProductGenre.coffee],
        ),
        _item(
          id: 'suntory_craft_boss_black',
          name: 'クラフトボス ブラック',
          evidence: ProductEvidenceType.manualConfirmed,
          genres: const <ProductGenre>[ProductGenre.coffee],
        ),
      ],
      selectedProduct: null,
      selectedGenre: ProductGenre.coffee,
    );

    expect(
      ordered
          .take(2)
          .every((item) => item.genres.contains(ProductGenre.coffee)),
      isTrue,
    );
    expect(ordered.last.productId.value, 'suntory_tennensui');
  });

  test('検索条件なしでは従来どおりconfirmedを優先する', () {
    final ordered = VendingMachineDetailSearchPriority.orderedProducts(
      products: <VendingMachineProductDetailItem>[
        _item(
          id: 'suntory_boss_black',
          name: 'BOSS ブラック',
          evidence: ProductEvidenceType.manufacturerInferred,
          genres: const <ProductGenre>[ProductGenre.coffee],
        ),
        _item(
          id: 'suntory_tennensui',
          name: 'サントリー天然水',
          evidence: ProductEvidenceType.manualConfirmed,
          genres: const <ProductGenre>[ProductGenre.water],
        ),
      ],
      selectedProduct: null,
      selectedGenre: null,
    );

    expect(ordered.first.productId.value, 'suntory_tennensui');
  });
}

VendingMachineProductDetailItem _item({
  required String id,
  required String name,
  required ProductEvidenceType evidence,
  required List<ProductGenre> genres,
}) {
  return VendingMachineProductDetailItem(
    productId: ProductId.parse(id),
    productName: name,
    evidenceType: evidence,
    availability: ProductAvailability.available,
    genres: genres,
  );
}
