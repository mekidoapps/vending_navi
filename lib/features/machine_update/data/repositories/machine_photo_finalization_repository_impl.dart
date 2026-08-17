import '../../../../core/errors/app_failure.dart';
import '../../../../core/errors/failure_mapper.dart';
import '../../../../core/result/app_result.dart';
import '../../../vending_machine/domain/value_objects/vending_machine_id.dart';
import '../../domain/models/machine_photo_finalization_result.dart';
import '../../domain/repositories/machine_photo_finalization_repository.dart';
import '../dtos/add_vending_machine_photo_request_dto.dart';
import '../dtos/add_vending_machine_photo_response_dto.dart';
import '../sources/machine_photo_finalization_data_source.dart';

final class MachinePhotoFinalizationRepositoryImpl
    implements MachinePhotoFinalizationRepository {
  const MachinePhotoFinalizationRepositoryImpl(this._source);

  final MachinePhotoFinalizationDataSource _source;

  @override
  Future<AppResult<MachinePhotoFinalizationResult>> addPhoto({
    required String requestId,
    required VendingMachineId machineId,
    required String temporaryPhotoUploadId,
  }) async {
    try {
      final request = AddVendingMachinePhotoRequestDto(
        requestId: requestId,
        machineId: machineId,
        temporaryPhotoUploadId: temporaryPhotoUploadId,
      );

      final rawResponse = await _source.addVendingMachinePhoto(request.toMap());

      final response = AddVendingMachinePhotoResponseDto.fromMap(rawResponse);

      final responseMachineId = VendingMachineId.tryParse(response.machineId);

      if (responseMachineId == null || responseMachineId != machineId) {
        return const AppResult<MachinePhotoFinalizationResult>.failure(
          ValidationFailure(field: 'machineId'),
        );
      }

      return AppResult<MachinePhotoFinalizationResult>.success(
        MachinePhotoFinalizationResult(
          machineId: responseMachineId,
          photoId: response.photoId,
          added: response.added,
          primaryPhotoChanged: response.primaryPhotoChanged,
        ),
      );
    } on Object catch (error) {
      return AppResult<MachinePhotoFinalizationResult>.failure(
        FailureMapper.map(error),
      );
    }
  }
}
