import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vending_app/features/product_master/data/fixtures/product_master_fixture.dart';
import 'package:vending_app/features/product_search/application/product_search_selection_controller.dart';

void main() {
  test('商品を選択して解除できる', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    final product = ProductMasterFixture.products.first;
    final controller = container.read(
      productSearchSelectionControllerProvider.notifier,
    );

    controller.select(product);

    expect(
      container.read(productSearchSelectionControllerProvider)?.id,
      product.id,
    );

    controller.clear();

    expect(container.read(productSearchSelectionControllerProvider), isNull);
  });
}
