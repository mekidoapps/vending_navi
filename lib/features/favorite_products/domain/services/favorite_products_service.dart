import '../../../../core/result/app_result.dart';
import '../../../product_master/data/legacy/legacy_name_normalizer.dart';
import '../../../product_master/domain/entities/product.dart';
import '../../../product_master/domain/repositories/product_repository.dart';
import '../models/favorite_products_view.dart';
import '../repositories/favorite_products_repository.dart';

final class FavoriteProductsService {
  const FavoriteProductsService({
    required FavoriteProductsRepository favoriteProductsRepository,
    required ProductRepository productRepository,
  }) : _favoriteProductsRepository = favoriteProductsRepository,
       _productRepository = productRepository;

  final FavoriteProductsRepository _favoriteProductsRepository;
  final ProductRepository _productRepository;

  Future<AppResult<FavoriteProductsView>> load({required String uid}) async {
    final snapshotResult = await _favoriteProductsRepository.load(uid: uid);
    final snapshotFailure = snapshotResult.failureOrNull;
    if (snapshotFailure != null) {
      return AppResult<FavoriteProductsView>.failure(snapshotFailure);
    }

    final snapshot = snapshotResult.valueOrNull!;

    final productsResult = await _productRepository.getProducts();
    final productsFailure = productsResult.failureOrNull;
    if (productsFailure != null) {
      return AppResult<FavoriteProductsView>.failure(productsFailure);
    }

    final products = productsResult.valueOrNull ?? const <Product>[];
    final byId = <String, Product>{
      for (final product in products) product.id.value: product,
    };

    if (snapshot.records.isNotEmpty) {
      final sortedRecords = [...snapshot.records]
        ..sort((left, right) {
          final sortOrder = left.sortOrder.compareTo(right.sortOrder);
          if (sortOrder != 0) {
            return sortOrder;
          }
          return left.productId.compareTo(right.productId);
        });

      final resolved = <Product>[];
      var nextSortOrder = 0;

      for (final record in sortedRecords) {
        if (record.sortOrder >= nextSortOrder) {
          nextSortOrder = record.sortOrder + 1;
        }

        final product = byId[record.productId];
        if (product != null && product.isSelectable) {
          resolved.add(product);
        }
      }

      return AppResult<FavoriteProductsView>.success(
        FavoriteProductsView(
          products: List<Product>.unmodifiable(resolved),
          nextSortOrder: nextSortOrder,
        ),
      );
    }

    if (snapshot.legacyMigrationCompleted ||
        snapshot.legacyFavoriteNames.isEmpty) {
      return const AppResult<FavoriteProductsView>.success(
        FavoriteProductsView(),
      );
    }

    final legacyProducts = _resolveLegacyProducts(
      legacyFavoriteNames: snapshot.legacyFavoriteNames,
      products: products,
    );

    return AppResult<FavoriteProductsView>.success(
      FavoriteProductsView(
        products: List<Product>.unmodifiable(legacyProducts),
        isLegacyFallback: true,
        nextSortOrder: legacyProducts.length,
      ),
    );
  }

  Future<AppResult<bool>> add({
    required String uid,
    required Product product,
    required FavoriteProductsView current,
  }) async {
    var nextSortOrder = current.nextSortOrder;

    if (current.isLegacyFallback) {
      final migrationResult = await _favoriteProductsRepository
          .materializeLegacyFallback(
            uid: uid,
            productIds: <String>[
              for (final item in current.products) item.id.value,
            ],
          );

      final migrationFailure = migrationResult.failureOrNull;
      if (migrationFailure != null) {
        return AppResult<bool>.failure(migrationFailure);
      }

      nextSortOrder = current.products.length;
    }

    if (current.products.any((item) => item.id == product.id)) {
      return const AppResult<bool>.success(true);
    }

    return _favoriteProductsRepository.add(
      uid: uid,
      productId: product.id.value,
      sortOrder: nextSortOrder,
    );
  }

  Future<AppResult<bool>> remove({
    required String uid,
    required Product product,
    required FavoriteProductsView current,
  }) async {
    if (current.isLegacyFallback) {
      final migrationResult = await _favoriteProductsRepository
          .materializeLegacyFallback(
            uid: uid,
            productIds: <String>[
              for (final item in current.products) item.id.value,
            ],
          );

      final migrationFailure = migrationResult.failureOrNull;
      if (migrationFailure != null) {
        return AppResult<bool>.failure(migrationFailure);
      }
    }

    return _favoriteProductsRepository.remove(
      uid: uid,
      productId: product.id.value,
    );
  }

  static List<Product> _resolveLegacyProducts({
    required List<String> legacyFavoriteNames,
    required List<Product> products,
  }) {
    final lookup = <String, Map<String, Product>>{};

    for (final product in products) {
      if (!product.isSelectable) {
        continue;
      }

      final terms = <String>{product.name, ...product.searchKeywords};

      for (final term in terms) {
        final normalized = LegacyNameNormalizer.normalize(term);
        if (normalized.isEmpty) {
          continue;
        }

        lookup.putIfAbsent(
          normalized,
          () => <String, Product>{},
        )[product.id.value] = product;
      }
    }

    final resolved = <Product>[];
    final usedIds = <String>{};

    for (final legacyName in legacyFavoriteNames) {
      final normalized = LegacyNameNormalizer.normalize(legacyName);
      final candidates = lookup[normalized];

      if (candidates == null || candidates.length != 1) {
        continue;
      }

      final product = candidates.values.single;
      if (usedIds.add(product.id.value)) {
        resolved.add(product);
      }
    }

    return resolved;
  }
}
