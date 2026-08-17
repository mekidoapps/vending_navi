import '../../../../core/errors/app_failure.dart';
import '../../../../core/errors/failure_mapper.dart';
import '../../../../core/result/app_result.dart';
import '../../../vending_machine/domain/value_objects/vending_machine_id.dart';
import '../../domain/models/machine_correction_draft.dart';
import '../../domain/models/machine_correction_result.dart';
import '../../domain/repositories/machine_correction_repository.dart';
import '../dtos/submit_machine_correction_request_dto.dart';
import '../dtos/submit_machine_correction_response_dto.dart';
import '../sources/machine_correction_data_source.dart';

final class MachineCorrectionRepositoryImpl
    implements MachineCorrectionRepository {
  const MachineCorrectionRepositoryImpl(this._source);

  final MachineCorrectionDataSource _source;

  @override
  Future<AppResult<MachineCorrectionResult>> submitCorrection({
    required String requestId,
    required MachineCorrectionDraft draft,
  }) async {
    try {
      final request = SubmitMachineCorrectionRequestDto(
        requestId: requestId,
        draft: draft,
      );

      final rawResponse = await _source.submitMachineCorrection(
        request.toMap(),
      );

      final response = SubmitMachineCorrectionResponseDto.fromMap(rawResponse);

      final machineId = VendingMachineId.tryParse(response.machineId);

      if (machineId == null || machineId != draft.machineId) {
        return const AppResult<MachineCorrectionResult>.failure(
          ValidationFailure(field: 'machineId'),
        );
      }

      return AppResult<MachineCorrectionResult>.success(
        MachineCorrectionResult(
          machineId: machineId,
          correctionId: response.correctionId,
        ),
      );
    } on Object catch (error) {
      return AppResult<MachineCorrectionResult>.failure(
        FailureMapper.map(error),
      );
    }
  }
}
