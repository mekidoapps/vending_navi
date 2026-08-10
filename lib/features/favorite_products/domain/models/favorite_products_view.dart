import '../../../product_master/domain/entities/product.dart';

final class FavoriteProductsView {
  const FavoriteProductsView({
    this.products = const <Product>[],
    this.isLegacyFallback = false,
    this.nextSortOrder = 0,
  });

  final List<Product> products;
  final bool isLegacyFallback;
  final int nextSortOrder;
}
