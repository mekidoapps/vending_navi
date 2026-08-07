import 'package:freezed_annotation/freezed_annotation.dart';

import '../../../product_master/domain/value_objects/master_id.dart';
import '../value_objects/geo_coordinate.dart';
import '../value_objects/vending_machine_id.dart';
import 'vending_machine_enums.dart';
import 'vending_machine_product.dart';

part 'vending_machine.freezed.dart';

@freezed
abstract class VendingMachine with _$VendingMachine {
  const VendingMachine._();

  const factory VendingMachine({
    required VendingMachineId id,
    required int schemaVersion,
    required String name,
    ManufacturerId? manufacturerId,
    required ManufacturerStatus manufacturerStatus,
    required GeoCoordinate location,

    /// Required for schemaVersion=2. Nullable only while legacy documents
    /// coexist with v2.
    String? geohash,
    String? placeDescription,
    required InstallationType installationType,
    required VendingMachineStatus status,
    VendingMachineId? mergedIntoMachineId,

    /// Required for schemaVersion=2. Nullable only for legacy read data.
    VendingMachineDataLevel? dataLevel,
    String? primaryPhotoId,

    /// Required for schemaVersion=2. Nullable only for legacy read data.
    String? createdBy,
    DateTime? createdAt,
    DateTime? updatedAt,
    DateTime? lastProductUpdatedAt,
    @Default(<VendingMachineProduct>[]) List<VendingMachineProduct> products,
  }) = _VendingMachine;

  bool get isLegacy => schemaVersion < 2;

  Iterable<VendingMachineProduct> get activeProducts =>
      products.where((product) => product.isActive);

  Iterable<VendingMachineProduct> get confirmedProducts =>
      activeProducts.where((product) => product.isConfirmed);

  Iterable<VendingMachineProduct> get inferredProducts =>
      activeProducts.where((product) => product.isInferred);
}
