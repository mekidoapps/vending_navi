import 'favorite_product_record.dart';

final class FavoriteProductsSnapshot {
  const FavoriteProductsSnapshot({
    this.records = const <FavoriteProductRecord>[],
    this.legacyFavoriteNames = const <String>[],
    this.legacyMigrationCompleted = false,
  });

  final List<FavoriteProductRecord> records;
  final List<String> legacyFavoriteNames;
  final bool legacyMigrationCompleted;
}
