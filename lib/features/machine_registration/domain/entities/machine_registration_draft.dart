import '../../../product_master/domain/value_objects/master_id.dart';
import '../../../vending_machine/domain/entities/vending_machine_enums.dart';
import '../../../vending_machine/domain/value_objects/geo_coordinate.dart';
import 'machine_registration_method.dart';

final class MachineRegistrationDraft {
  const MachineRegistrationDraft({
    required this.requestId,
    this.location,
    this.registrationMethod,
    this.name,
    this.manufacturerId,
    this.confirmedProductIds = const <ProductId>[],
    this.temporaryPhotoUploadId,
    this.placeDescription,
    this.installationType = InstallationType.unknown,
  });

  final String requestId;
  final GeoCoordinate? location;
  final MachineRegistrationMethod? registrationMethod;
  final String? name;
  final ManufacturerId? manufacturerId;
  final List<ProductId> confirmedProductIds;
  final String? temporaryPhotoUploadId;
  final String? placeDescription;
  final InstallationType installationType;

  bool get isReadyForPhase6Submission {
    if (requestId.trim().isEmpty || location == null) {
      return false;
    }

    return switch (registrationMethod) {
      MachineRegistrationMethod.manufacturer => manufacturerId != null,
      MachineRegistrationMethod.locationOnly =>
        manufacturerId == null &&
            confirmedProductIds.isEmpty &&
            temporaryPhotoUploadId == null,
      MachineRegistrationMethod.photo =>
        temporaryPhotoUploadId?.trim().isNotEmpty == true,
      null => false,
    };
  }

  MachineRegistrationDraft copyWith({
    String? requestId,
    GeoCoordinate? location,
    bool clearLocation = false,
    MachineRegistrationMethod? registrationMethod,
    bool clearRegistrationMethod = false,
    String? name,
    bool clearName = false,
    ManufacturerId? manufacturerId,
    bool clearManufacturerId = false,
    List<ProductId>? confirmedProductIds,
    String? temporaryPhotoUploadId,
    bool clearTemporaryPhotoUploadId = false,
    String? placeDescription,
    bool clearPlaceDescription = false,
    InstallationType? installationType,
  }) {
    return MachineRegistrationDraft(
      requestId: requestId ?? this.requestId,
      location: clearLocation ? null : (location ?? this.location),
      registrationMethod: clearRegistrationMethod
          ? null
          : (registrationMethod ?? this.registrationMethod),
      name: clearName ? null : (name ?? this.name),
      manufacturerId: clearManufacturerId
          ? null
          : (manufacturerId ?? this.manufacturerId),
      confirmedProductIds: confirmedProductIds ?? this.confirmedProductIds,
      temporaryPhotoUploadId: clearTemporaryPhotoUploadId
          ? null
          : (temporaryPhotoUploadId ?? this.temporaryPhotoUploadId),
      placeDescription: clearPlaceDescription
          ? null
          : (placeDescription ?? this.placeDescription),
      installationType: installationType ?? this.installationType,
    );
  }
}
