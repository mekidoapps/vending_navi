import '../../../vending_machine/domain/value_objects/vending_machine_id.dart';

final class MachinePhotoFinalizationResult {
  const MachinePhotoFinalizationResult({
    required this.machineId,
    required this.photoId,
    required this.added,
    required this.primaryPhotoChanged,
  });

  final VendingMachineId machineId;
  final String photoId;
  final bool added;
  final bool primaryPhotoChanged;
}
