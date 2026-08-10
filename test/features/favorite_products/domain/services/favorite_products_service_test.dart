import 'package:flutter_test/flutter_test.dart';
import 'package:vending_app/core/errors/app_failure.dart';
import 'package:vending_app/core/result/app_result.dart';
import 'package:vending_app/features/favorite_products/domain/entities/favorite_product_record.dart';
import 'package:vending_app/features/favorite_products/domain/entities/favorite_products_snapshot.dart';
import 'package:vending_app/features/favorite_products/domain/repositories/favorite_products_repository.dart';
import 'package:vending_app/features/favorite_products/domain/services/favorite_products_service.dart';
import 'package:vending_app/features/product_master/data/fixtures/product_master_fixture.dart';
import 'package:vending_app/features/product_master/domain/entities/product.dart';
import 'package:vending_app/features/product_master/domain/repositories/product_repository.dart';
import 'package:vending_app/features/product_master/domain/value_objects/master_id.dart';

void main() {
  test('Product ID recordをsortOrder順でProductへ解決する', () async {
    final first = ProductMasterFixture.products.first;
    final second = ProductMasterFixture.products[1];

    final service = FavoriteProductsService(
      favoriteProductsRepository: _FakeFavoriteProductsRepository(
        snapshot: FavoriteProductsSnapshot(
          records: <FavoriteProductRecord>[
            FavoriteProductRecord(productId: second.id.value, sortOrder: 20),
            FavoriteProductRecord(productId: first.id.value, sortOrder: 10),
          ],
        ),
      ),
      productRepository: _FixtureProductRepository(),
    );

    final result = await service.load(uid: 'user_1');
    final view = result.valueOrNull!;

    expect(view.products.map((product) => product.id.value).toList(), <String>[
      first.id.value,
      second.id.value,
    ]);
    expect(view.nextSortOrder, 21);
    expect(view.isLegacyFallback, isFalse);
  });

  test('legacy favoriteDrinkNamesは一意完全一致だけfallback解決する', () async {
    final target = ProductMasterFixture.products.firstWhere(
      (product) => product.name == '綾鷹',
    );

    final service = FavoriteProductsService(
      favoriteProductsRepository: _FakeFavoriteProductsRepository(
        snapshot: const FavoriteProductsSnapshot(
          legacyFavoriteNames: <String>['綾鷹', '存在しない商品'],
        ),
      ),
      productRepository: _FixtureProductRepository(),
    );

    final result = await service.load(uid: 'user_1');
    final view = result.valueOrNull!;

    expect(view.products, <Product>[target]);
    expect(view.isLegacyFallback, isTrue);
  });

  test('migration完了後はlegacy文字列へfallbackしない', () async {
    final service = FavoriteProductsService(
      favoriteProductsRepository: _FakeFavoriteProductsRepository(
        snapshot: const FavoriteProductsSnapshot(
          legacyFavoriteNames: <String>['綾鷹'],
          legacyMigrationCompleted: true,
        ),
      ),
      productRepository: _FixtureProductRepository(),
    );

    final result = await service.load(uid: 'user_1');

    expect(result.valueOrNull!.products, isEmpty);
    expect(result.valueOrNull!.isLegacyFallback, isFalse);
  });
}

final class _FakeFavoriteProductsRepository
    implements FavoriteProductsRepository {
  _FakeFavoriteProductsRepository({required this.snapshot});

  final FavoriteProductsSnapshot snapshot;

  @override
  Future<AppResult<FavoriteProductsSnapshot>> load({
    required String uid,
  }) async {
    return AppResult<FavoriteProductsSnapshot>.success(snapshot);
  }

  @override
  Future<AppResult<bool>> add({
    required String uid,
    required String productId,
    required int sortOrder,
  }) async {
    return const AppResult<bool>.success(true);
  }

  @override
  Future<AppResult<bool>> remove({
    required String uid,
    required String productId,
  }) async {
    return const AppResult<bool>.success(true);
  }

  @override
  Future<AppResult<bool>> materializeLegacyFallback({
    required String uid,
    required List<String> productIds,
  }) async {
    return const AppResult<bool>.success(true);
  }
}

final class _FixtureProductRepository implements ProductRepository {
  @override
  Future<AppResult<Product>> getProduct(ProductId id) async {
    for (final product in ProductMasterFixture.products) {
      if (product.id == id) {
        return AppResult<Product>.success(product);
      }
    }
    return const AppResult<Product>.failure(NotFoundFailure());
  }

  @override
  Future<AppResult<List<Product>>> getProducts({bool activeOnly = true}) async {
    return AppResult<List<Product>>.success(
      ProductMasterFixture.products
          .where((product) => !activeOnly || product.isActive)
          .toList(growable: false),
    );
  }
}
