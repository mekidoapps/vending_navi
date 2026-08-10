import '../dtos/favorite_products_snapshot_dto.dart';

abstract interface class FavoriteProductsDataSource {
  Future<FavoriteProductsSnapshotDto> load({required String uid});

  Future<void> add({
    required String uid,
    required String productId,
    required int sortOrder,
  });

  Future<void> remove({required String uid, required String productId});

  Future<void> materializeLegacyFallback({
    required String uid,
    required List<String> productIds,
  });
}
