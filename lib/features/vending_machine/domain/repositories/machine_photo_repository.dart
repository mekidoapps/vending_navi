import '../../../../core/result/app_result.dart';
import '../entities/public_machine_photo.dart';
import '../value_objects/vending_machine_id.dart';

abstract interface class MachinePhotoRepository {
  Future<AppResult<List<PublicMachinePhoto>>> getActivePhotos(
    VendingMachineId machineId,
  );
}
