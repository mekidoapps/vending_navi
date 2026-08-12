import '../../../product_master/domain/value_objects/master_id.dart';
import '../../domain/entities/machine_registration_draft.dart';
import '../../domain/entities/machine_registration_method.dart';

final class CreateVendingMachineRequestDto {
  const CreateVendingMachineRequestDto({
    required this.requestId,
    required this.registrationMethod,
    required this.latitude,
    required this.longitude,
    required this.name,
    required this.manufacturerId,
    required this.confirmedProductIds,
    required this.temporaryPhotoUploadId,
    required this.placeDescription,
    required this.installationType,
  });

  factory CreateVendingMachineRequestDto.fromDraft(
    MachineRegistrationDraft draft,
  ) {
    final location = draft.location;
    final method = draft.registrationMethod;

    if (draft.requestId.trim().isEmpty) {
      throw const FormatException('requestId is required');
    }
    if (location == null) {
      throw const FormatException('location is required');
    }
    if (method == null) {
      throw const FormatException('registrationMethod is required');
    }

    if (method == MachineRegistrationMethod.manufacturer &&
        draft.manufacturerId == null) {
      throw const FormatException(
        'manufacturerId is required for manufacturer registration',
      );
    }

    if (method == MachineRegistrationMethod.locationOnly &&
        (draft.manufacturerId != null ||
            draft.confirmedProductIds.isNotEmpty ||
            draft.temporaryPhotoUploadId != null)) {
      throw const FormatException(
        'locationOnly registration cannot include manufacturer, products, or photo',
      );
    }

    return CreateVendingMachineRequestDto(
      requestId: draft.requestId.trim(),
      registrationMethod: method.wireValue,
      latitude: location.latitude,
      longitude: location.longitude,
      name: _normalizedNullable(draft.name),
      manufacturerId: draft.manufacturerId?.value,
      confirmedProductIds: List<String>.unmodifiable(
        _uniqueProductIds(draft.confirmedProductIds),
      ),
      temporaryPhotoUploadId: _normalizedNullable(draft.temporaryPhotoUploadId),
      placeDescription: _normalizedNullable(draft.placeDescription),
      installationType: draft.installationType.wireValue,
    );
  }

  final String requestId;
  final String registrationMethod;
  final double latitude;
  final double longitude;
  final String? name;
  final String? manufacturerId;
  final List<String> confirmedProductIds;
  final String? temporaryPhotoUploadId;
  final String? placeDescription;
  final String installationType;

  Map<String, Object?> toMap() {
    return <String, Object?>{
      'requestId': requestId,
      'registrationMethod': registrationMethod,
      'location': <String, Object?>{
        'latitude': latitude,
        'longitude': longitude,
      },
      'name': name,
      'manufacturerId': manufacturerId,
      'confirmedProductIds': confirmedProductIds,
      'temporaryPhotoUploadId': temporaryPhotoUploadId,
      'placeDescription': placeDescription,
      'installationType': installationType,
    };
  }

  static String? _normalizedNullable(String? value) {
    final normalized = value?.trim() ?? '';
    return normalized.isEmpty ? null : normalized;
  }

  static List<String> _uniqueProductIds(List<ProductId> values) {
    final result = <String>[];
    final seen = <String>{};

    for (final productId in values) {
      if (seen.add(productId.value)) {
        result.add(productId.value);
      }
    }

    return result;
  }
}
