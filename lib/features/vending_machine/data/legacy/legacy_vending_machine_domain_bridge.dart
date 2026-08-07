import '../../../../core/errors/app_failure.dart';
import '../../../../core/result/app_result.dart';
import '../../../product_master/data/legacy/legacy_mapped_vending_machine.dart';
import '../../../product_master/data/legacy/legacy_master_resolution.dart';
import '../../../product_master/domain/value_objects/master_id.dart';
import '../../domain/entities/vending_machine.dart';
import '../../domain/entities/vending_machine_enums.dart';
import '../../domain/entities/vending_machine_product.dart';
import '../../domain/value_objects/geo_coordinate.dart';
import '../../domain/value_objects/vending_machine_id.dart';

final class LegacyVendingMachineBridgeResult {
  const LegacyVendingMachineBridgeResult({
    required this.machine,
    required this.unresolvedProductCount,
  });

  final VendingMachine machine;
  final int unresolvedProductCount;
}

abstract final class LegacyVendingMachineDomainBridge {
  static AppResult<LegacyVendingMachineBridgeResult> toDomain(
    LegacyMappedVendingMachine legacy,
  ) {
    final id = VendingMachineId.tryParse(legacy.id);
    if (id == null) {
      return _invalid('legacyVendingMachine.id');
    }

    if (!legacy.hasUsableLocation) {
      return _invalid('legacyVendingMachine.location');
    }

    final latitude = legacy.latitude;
    final longitude = legacy.longitude;
    if (latitude == null || longitude == null) {
      return _invalid('legacyVendingMachine.location');
    }

    final products = _resolvedProducts(legacy.products);

    final dataLevel = switch ((
      products.isNotEmpty,
      legacy.manufacturer.isResolved,
    )) {
      (true, _) => VendingMachineDataLevel.productsConfirmed,
      (false, true) => VendingMachineDataLevel.manufacturerOnly,
      (false, false) => VendingMachineDataLevel.locationOnly,
    };

    try {
      final machine = VendingMachine(
        id: id,
        schemaVersion: legacy.schemaVersion,
        name: legacy.name.trim().isEmpty ? '自販機' : legacy.name.trim(),
        manufacturerId: legacy.manufacturer.manufacturerId,
        manufacturerStatus: legacy.manufacturer.isResolved
            ? ManufacturerStatus.confirmed
            : ManufacturerStatus.unknown,
        location: GeoCoordinate(latitude: latitude, longitude: longitude),
        geohash: null,
        placeDescription: _placeDescription(legacy),
        installationType: InstallationType.unknown,
        status: VendingMachineStatus.active,
        mergedIntoMachineId: null,
        dataLevel: dataLevel,
        primaryPhotoId: null,
        createdBy: null,
        createdAt: legacy.createdAt,
        updatedAt: legacy.updatedAt,
        lastProductUpdatedAt: legacy.lastCheckedAt ?? legacy.updatedAt,
        products: List<VendingMachineProduct>.unmodifiable(products),
      );

      return AppResult<LegacyVendingMachineBridgeResult>.success(
        LegacyVendingMachineBridgeResult(
          machine: machine,
          unresolvedProductCount: legacy.unresolvedProductCount,
        ),
      );
    } on FormatException {
      return _invalid('legacyVendingMachine.location');
    }
  }

  static List<VendingMachineProduct> _resolvedProducts(
    Iterable<LegacyResolvedProduct> legacyProducts,
  ) {
    final grouped = <ProductId, List<LegacyResolvedProduct>>{};

    for (final legacyProduct in legacyProducts) {
      final productId = legacyProduct.productId;
      if (productId == null) {
        continue;
      }

      grouped.putIfAbsent(productId, () => <LegacyResolvedProduct>[])
        ..add(legacyProduct);
    }

    return grouped.entries
        .map(
          (entry) => VendingMachineProduct(
            productId: entry.key,
            evidenceType: ProductEvidenceType.manualConfirmed,
            availability: entry.value.any((item) => !item.isSoldOut)
                ? ProductAvailability.available
                : ProductAvailability.soldOut,
            isActive: true,
          ),
        )
        .toList(growable: false);
  }

  static String? _placeDescription(LegacyMappedVendingMachine legacy) {
    final candidates = <String?>[legacy.locationName, legacy.address];

    for (final value in candidates) {
      final normalized = value?.trim();
      if (normalized != null && normalized.isNotEmpty) {
        return normalized;
      }
    }

    return null;
  }

  static AppResult<LegacyVendingMachineBridgeResult> _invalid(String field) {
    return AppResult<LegacyVendingMachineBridgeResult>.failure(
      ValidationFailure(field: field),
    );
  }
}
