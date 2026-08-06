import '../../../../core/errors/app_failure.dart';
import '../../../../core/result/app_result.dart';
import '../../domain/entities/manufacturer.dart';
import '../../domain/value_objects/master_id.dart';
import '../dtos/manufacturer_dto.dart';
import 'master_mapper_utils.dart';

abstract final class ManufacturerMapper {
  static AppResult<Manufacturer> fromFirestoreDocument({
    required String documentId,
    required Map<String, dynamic> data,
  }) {
    try {
      final dto = ManufacturerDto.fromFirestoreDocument(
        documentId: documentId,
        data: data,
      );
      return toDomain(dto);
    } on Object {
      return _invalid('manufacturer.document');
    }
  }

  static AppResult<Manufacturer> toDomain(ManufacturerDto dto) {
    final id = ManufacturerId.tryParse(dto.documentId);
    if (id == null) {
      return _invalid('manufacturer.id');
    }

    final name = dto.name.trim();
    if (name.isEmpty) {
      return _invalid('manufacturer.name');
    }

    final displayShortName = dto.displayShortName.trim();
    if (displayShortName.isEmpty) {
      return _invalid('manufacturer.displayShortName');
    }

    final presetProductIds = <ProductId>[];
    final seenProductIds = <ProductId>{};
    for (final rawProductId in dto.presetProductIds) {
      final productId = ProductId.tryParse(rawProductId.trim());
      if (productId == null) {
        return _invalid('manufacturer.presetProductIds');
      }
      if (seenProductIds.add(productId)) {
        presetProductIds.add(productId);
      }
    }

    return AppResult<Manufacturer>.success(
      Manufacturer(
        id: id,
        name: name,
        displayShortName: displayShortName,
        searchKeywords: normalizeMasterStrings(dto.searchKeywords),
        presetProductIds: List<ProductId>.unmodifiable(presetProductIds),
        isActive: dto.isActive,
        createdAt: dto.createdAt.toUtc(),
        updatedAt: dto.updatedAt.toUtc(),
      ),
    );
  }

  static ManufacturerDto toDto(Manufacturer manufacturer) {
    return ManufacturerDto(
      documentId: manufacturer.id.value,
      name: manufacturer.name,
      displayShortName: manufacturer.displayShortName,
      searchKeywords: manufacturer.searchKeywords,
      presetProductIds: manufacturer.presetProductIds
          .map((productId) => productId.value)
          .toList(growable: false),
      isActive: manufacturer.isActive,
      createdAt: manufacturer.createdAt.toUtc(),
      updatedAt: manufacturer.updatedAt.toUtc(),
    );
  }

  static AppResult<Manufacturer> _invalid(String field) {
    return AppResult<Manufacturer>.failure(ValidationFailure(field: field));
  }
}
