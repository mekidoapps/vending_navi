import '../../../../core/result/app_result.dart';
import '../entities/favorite_products_snapshot.dart';

abstract interface class FavoriteProductsRepository {
  Future<AppResult<FavoriteProductsSnapshot>> load({required String uid});

  Future<AppResult<bool>> add({
    required String uid,
    required String productId,
    required int sortOrder,
  });

  Future<AppResult<bool>> remove({
    required String uid,
    required String productId,
  });

  Future<AppResult<bool>> materializeLegacyFallback({
    required String uid,
    required List<String> productIds,
  });
}
