import '../../../vending_machine/domain/value_objects/vending_machine_id.dart';

final class AddVendingMachinePhotoRequestDto {
  const AddVendingMachinePhotoRequestDto({
    required this.requestId,
    required this.machineId,
    required this.temporaryPhotoUploadId,
  });

  final String requestId;
  final VendingMachineId machineId;
  final String temporaryPhotoUploadId;

  Map<String, Object?> toMap() {
    return <String, Object?>{
      'requestId': requestId,
      'machineId': machineId.value,
      'temporaryPhotoUploadId': temporaryPhotoUploadId,
    };
  }
}
