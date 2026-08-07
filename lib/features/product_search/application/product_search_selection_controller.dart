import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../product_master/domain/entities/product.dart';

final productSearchSelectionControllerProvider =
    NotifierProvider<ProductSearchSelectionController, Product?>(
      ProductSearchSelectionController.new,
      name: 'productSearchSelectionControllerProvider',
    );

final class ProductSearchSelectionController extends Notifier<Product?> {
  @override
  Product? build() => null;

  void select(Product product) {
    state = product;
  }

  void clear() {
    state = null;
  }
}
