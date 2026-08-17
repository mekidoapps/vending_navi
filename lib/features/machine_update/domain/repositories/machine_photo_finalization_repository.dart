import '../../../../core/result/app_result.dart';
import '../../../vending_machine/domain/value_objects/vending_machine_id.dart';
import '../models/machine_photo_finalization_result.dart';

abstract interface class MachinePhotoFinalizationRepository {
  Future<AppResult<MachinePhotoFinalizationResult>> addPhoto({
    required String requestId,
    required VendingMachineId machineId,
    required String temporaryPhotoUploadId,
  });
}
