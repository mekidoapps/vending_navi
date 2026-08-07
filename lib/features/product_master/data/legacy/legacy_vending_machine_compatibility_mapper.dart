import '../../../../core/errors/app_failure.dart';
import '../../../../core/errors/failure_mapper.dart';
import '../../../../core/result/app_result.dart';
import '../../domain/entities/manufacturer.dart';
import '../../domain/entities/product.dart';
import '../../domain/value_objects/master_id.dart';
import 'legacy_mapped_vending_machine.dart';
import 'legacy_master_resolver.dart';
import 'legacy_vending_machine_document.dart';

abstract final class LegacyVendingMachineCompatibilityMapper {
  static AppResult<LegacyMappedVendingMachine> fromDocumentData({
    required String documentId,
    required Map<String, dynamic> data,
    required Iterable<Product> products,
    required Iterable<Manufacturer> manufacturers,
    Map<String, ProductId> productAliases = const <String, ProductId>{},
    Map<String, ManufacturerId> manufacturerAliases =
        const <String, ManufacturerId>{},
  }) {
    if (documentId.trim().isEmpty) {
      return const AppResult<LegacyMappedVendingMachine>.failure(
        ValidationFailure(field: 'legacyVendingMachine.id'),
      );
    }

    try {
      final document = LegacyVendingMachineDocument.fromDocumentData(
        documentId: documentId,
        data: data,
      );
      final productCatalog = products.toList(growable: false);
      final manufacturerCatalog = manufacturers.toList(growable: false);

      final resolvedManufacturer = LegacyMasterResolver.resolveManufacturer(
        legacyName: document.manufacturer,
        manufacturers: manufacturerCatalog,
        manualAliases: manufacturerAliases,
      );
      final resolvedProducts = document.products
          .map(
            (candidate) => LegacyMasterResolver.resolveProduct(
              candidate: candidate,
              products: productCatalog,
              manufacturer: resolvedManufacturer,
              manualAliases: productAliases,
            ),
          )
          .toList(growable: false);

      return AppResult<LegacyMappedVendingMachine>.success(
        LegacyMappedVendingMachine(
          id: document.documentId,
          schemaVersion: document.schemaVersion,
          name: document.name,
          manufacturer: resolvedManufacturer,
          latitude: document.latitude,
          longitude: document.longitude,
          products: List.unmodifiable(resolvedProducts),
          createdAt: document.createdAt,
          updatedAt: document.updatedAt,
          lastCheckedAt: document.lastCheckedAt,
          address: document.address,
          locationName: document.locationName,
          imageUrl: document.imageUrl,
          note: document.note,
          tags: document.tags,
          cashlessSupported: document.cashlessSupported,
        ),
      );
    } on Object catch (error) {
      return AppResult<LegacyMappedVendingMachine>.failure(
        FailureMapper.map(error),
      );
    }
  }
}
