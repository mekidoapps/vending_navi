import 'legacy_master_resolution.dart';

/// Compatibility output used while v1 and v2 data coexist.
///
/// A dedicated v2 vending-machine Domain Model is introduced in the home-map
/// phase. Until then this object keeps legacy transport details separate from
/// the Product/Manufacturer Domain Models.
final class LegacyMappedVendingMachine {
  const LegacyMappedVendingMachine({
    required this.id,
    required this.schemaVersion,
    required this.name,
    required this.manufacturer,
    required this.latitude,
    required this.longitude,
    required this.products,
    required this.createdAt,
    required this.updatedAt,
    required this.lastCheckedAt,
    required this.address,
    required this.locationName,
    required this.imageUrl,
    required this.note,
    required this.tags,
    required this.cashlessSupported,
  });

  final String id;
  final int schemaVersion;
  final String name;
  final LegacyResolvedManufacturer manufacturer;
  final double? latitude;
  final double? longitude;
  final List<LegacyResolvedProduct> products;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final DateTime? lastCheckedAt;
  final String? address;
  final String? locationName;
  final String? imageUrl;
  final String? note;
  final List<String> tags;
  final bool cashlessSupported;

  int get unresolvedProductCount =>
      products.where((product) => !product.isResolved).length;

  bool get hasUsableLocation {
    final lat = latitude;
    final lng = longitude;
    if (lat == null || lng == null) {
      return false;
    }
    return lat >= -90 && lat <= 90 && lng >= -180 && lng <= 180;
  }
}
