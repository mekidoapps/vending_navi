import '../../../../core/errors/app_failure.dart';
import '../../../../core/result/app_result.dart';
import '../../../product_master/domain/entities/product_genre.dart';
import '../../../product_master/domain/value_objects/master_id.dart';
import '../../../vending_machine/domain/entities/vending_machine_enums.dart';
import '../../../vending_machine/domain/value_objects/geo_coordinate.dart';
import '../../../vending_machine/domain/value_objects/vending_machine_id.dart';
import '../../domain/entities/machine_product_index_entry.dart';
import '../dtos/machine_product_index_dto.dart';

abstract final class MachineProductIndexMapper {
  static AppResult<MachineProductIndexEntry> fromFirestoreDocument({
    required String documentId,
    required Map<String, dynamic> data,
  }) {
    try {
      return toDomain(
        MachineProductIndexDto.fromFirestoreDocument(
          documentId: documentId,
          data: data,
        ),
      );
    } on Object {
      return _invalid('machineProductIndex.document');
    }
  }

  static AppResult<MachineProductIndexEntry> toDomain(
    MachineProductIndexDto dto,
  ) {
    final machineId = VendingMachineId.tryParse(dto.machineId);
    if (machineId == null) {
      return _invalid('machineProductIndex.machineId');
    }

    final productId = ProductId.tryParse(dto.productId);
    if (productId == null) {
      return _invalid('machineProductIndex.productId');
    }

    final genres = <ProductGenre>[];
    for (final genreId in dto.genreIds) {
      final genre = ProductGenre.tryFromId(genreId);
      if (genre == null) {
        return _invalid('machineProductIndex.genreIds');
      }
      genres.add(genre);
    }

    final evidenceType = ProductEvidenceType.tryParse(dto.evidenceType);
    if (evidenceType == null) {
      return _invalid('machineProductIndex.evidenceType');
    }

    final availability = ProductAvailability.tryParse(dto.availability);
    if (availability == null) {
      return _invalid('machineProductIndex.availability');
    }

    final machineStatus = VendingMachineStatus.tryParse(dto.machineStatus);
    if (machineStatus == null) {
      return _invalid('machineProductIndex.machineStatus');
    }

    try {
      return AppResult<MachineProductIndexEntry>.success(
        MachineProductIndexEntry(
          machineId: machineId,
          productId: productId,
          genres: List<ProductGenre>.unmodifiable(genres),
          location: GeoCoordinate(
            latitude: dto.location.latitude,
            longitude: dto.location.longitude,
          ),
          geohash: dto.geohash,
          evidenceType: evidenceType,
          availability: availability,
          isActive: dto.isActive,
          machineStatus: machineStatus,
          machineUpdatedAt: dto.machineUpdatedAt.toUtc(),
          updatedAt: dto.updatedAt.toUtc(),
        ),
      );
    } on Object {
      return _invalid('machineProductIndex.location');
    }
  }

  static AppResult<MachineProductIndexEntry> _invalid(String field) {
    return AppResult<MachineProductIndexEntry>.failure(
      ValidationFailure(field: field),
    );
  }
}
