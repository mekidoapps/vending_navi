import '../../../../core/errors/failure_mapper.dart';
import '../../../../core/result/app_result.dart';
import '../../domain/entities/favorite_product_record.dart';
import '../../domain/entities/favorite_products_snapshot.dart';
import '../../domain/repositories/favorite_products_repository.dart';
import '../sources/favorite_products_data_source.dart';

final class FavoriteProductsRepositoryImpl
    implements FavoriteProductsRepository {
  const FavoriteProductsRepositoryImpl(this._source);

  final FavoriteProductsDataSource _source;

  @override
  Future<AppResult<FavoriteProductsSnapshot>> load({
    required String uid,
  }) async {
    try {
      final dto = await _source.load(uid: uid);

      return AppResult<FavoriteProductsSnapshot>.success(
        FavoriteProductsSnapshot(
          records: List<FavoriteProductRecord>.unmodifiable(
            dto.records.map(
              (record) => FavoriteProductRecord(
                productId: record.productId,
                sortOrder: record.sortOrder,
              ),
            ),
          ),
          legacyFavoriteNames: List<String>.unmodifiable(
            dto.legacyFavoriteNames,
          ),
          legacyMigrationCompleted: dto.legacyMigrationCompleted,
        ),
      );
    } on Object catch (error) {
      return AppResult<FavoriteProductsSnapshot>.failure(
        FailureMapper.map(error),
      );
    }
  }

  @override
  Future<AppResult<bool>> add({
    required String uid,
    required String productId,
    required int sortOrder,
  }) async {
    try {
      await _source.add(uid: uid, productId: productId, sortOrder: sortOrder);
      return const AppResult<bool>.success(true);
    } on Object catch (error) {
      return AppResult<bool>.failure(FailureMapper.map(error));
    }
  }

  @override
  Future<AppResult<bool>> remove({
    required String uid,
    required String productId,
  }) async {
    try {
      await _source.remove(uid: uid, productId: productId);
      return const AppResult<bool>.success(true);
    } on Object catch (error) {
      return AppResult<bool>.failure(FailureMapper.map(error));
    }
  }

  @override
  Future<AppResult<bool>> materializeLegacyFallback({
    required String uid,
    required List<String> productIds,
  }) async {
    try {
      await _source.materializeLegacyFallback(uid: uid, productIds: productIds);
      return const AppResult<bool>.success(true);
    } on Object catch (error) {
      return AppResult<bool>.failure(FailureMapper.map(error));
    }
  }
}
