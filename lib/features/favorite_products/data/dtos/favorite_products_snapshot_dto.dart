import 'favorite_product_record_dto.dart';

final class FavoriteProductsSnapshotDto {
  const FavoriteProductsSnapshotDto({
    this.records = const <FavoriteProductRecordDto>[],
    this.legacyFavoriteNames = const <String>[],
    this.legacyMigrationCompleted = false,
  });

  final List<FavoriteProductRecordDto> records;
  final List<String> legacyFavoriteNames;
  final bool legacyMigrationCompleted;
}
