import '../../../../core/errors/app_failure.dart';
import '../../../../core/result/app_result.dart';
import '../../../product_master/domain/value_objects/master_id.dart';
import '../../domain/entities/vending_machine.dart';
import '../../domain/entities/vending_machine_enums.dart';
import '../../domain/value_objects/geo_coordinate.dart';
import '../../domain/value_objects/vending_machine_id.dart';
import '../dtos/vending_machine_dto.dart';

abstract final class VendingMachineMapper {
  static AppResult<VendingMachine> fromFirestoreDocument({
    required String documentId,
    required Map<String, dynamic> data,
  }) {
    try {
      return toDomain(
        VendingMachineDto.fromFirestoreDocument(
          documentId: documentId,
          data: data,
        ),
      );
    } on Object {
      return _invalid('vendingMachine.document');
    }
  }

  static AppResult<VendingMachine> toDomain(VendingMachineDto dto) {
    final id = VendingMachineId.tryParse(dto.documentId);
    if (id == null) {
      return _invalid('vendingMachine.id');
    }

    if (dto.schemaVersion != 2) {
      return _invalid('vendingMachine.schemaVersion');
    }

    final name = dto.name.trim();
    if (name.isEmpty) {
      return _invalid('vendingMachine.name');
    }

    ManufacturerId? manufacturerId;
    final rawManufacturerId = dto.manufacturerId;
    if (rawManufacturerId != null) {
      manufacturerId = ManufacturerId.tryParse(rawManufacturerId);
      if (manufacturerId == null) {
        return _invalid('vendingMachine.manufacturerId');
      }
    }

    final manufacturerStatus = ManufacturerStatus.tryParse(
      dto.manufacturerStatus,
    );
    if (manufacturerStatus == null) {
      return _invalid('vendingMachine.manufacturerStatus');
    }

    final installationType = InstallationType.tryParse(dto.installationType);
    if (installationType == null) {
      return _invalid('vendingMachine.installationType');
    }

    final status = VendingMachineStatus.tryParse(dto.status);
    if (status == null) {
      return _invalid('vendingMachine.status');
    }

    final dataLevel = VendingMachineDataLevel.tryParse(dto.dataLevel);
    if (dataLevel == null) {
      return _invalid('vendingMachine.dataLevel');
    }

    VendingMachineId? mergedIntoMachineId;
    final rawMergedId = dto.mergedIntoMachineId;
    if (rawMergedId != null) {
      mergedIntoMachineId = VendingMachineId.tryParse(rawMergedId);
      if (mergedIntoMachineId == null) {
        return _invalid('vendingMachine.mergedIntoMachineId');
      }
    }

    try {
      return AppResult<VendingMachine>.success(
        VendingMachine(
          id: id,
          schemaVersion: dto.schemaVersion,
          name: name,
          manufacturerId: manufacturerId,
          manufacturerStatus: manufacturerStatus,
          location: GeoCoordinate(
            latitude: dto.location.latitude,
            longitude: dto.location.longitude,
          ),
          geohash: dto.geohash.trim(),
          placeDescription: _normalizedOptional(dto.placeDescription),
          installationType: installationType,
          status: status,
          mergedIntoMachineId: mergedIntoMachineId,
          dataLevel: dataLevel,
          primaryPhotoId: _normalizedOptional(dto.primaryPhotoId),
          createdBy: null,
          createdAt: dto.createdAt.toUtc(),
          updatedAt: dto.updatedAt.toUtc(),
          lastProductUpdatedAt: dto.lastProductUpdatedAt?.toUtc(),
        ),
      );
    } on FormatException {
      return _invalid('vendingMachine.location');
    }
  }

  static AppResult<VendingMachine> _invalid(String field) {
    return AppResult<VendingMachine>.failure(ValidationFailure(field: field));
  }

  static String? _normalizedOptional(String? value) {
    final normalized = value?.trim();
    if (normalized == null || normalized.isEmpty) {
      return null;
    }
    return normalized;
  }
}
