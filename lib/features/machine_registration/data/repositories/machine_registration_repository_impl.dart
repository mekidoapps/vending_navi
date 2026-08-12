import '../../../../core/errors/app_failure.dart';
import '../../../../core/errors/failure_mapper.dart';
import '../../../../core/result/app_result.dart';
import '../../../vending_machine/domain/value_objects/vending_machine_id.dart';
import '../../domain/entities/machine_registration_draft.dart';
import '../../domain/entities/machine_registration_result.dart';
import '../../domain/repositories/machine_registration_repository.dart';
import '../dtos/create_vending_machine_request_dto.dart';
import '../dtos/create_vending_machine_response_dto.dart';
import '../sources/machine_registration_data_source.dart';

final class MachineRegistrationRepositoryImpl
    implements MachineRegistrationRepository {
  const MachineRegistrationRepositoryImpl(this._source);

  final MachineRegistrationDataSource _source;

  @override
  Future<AppResult<MachineRegistrationResult>> createVendingMachine(
    MachineRegistrationDraft draft,
  ) async {
    try {
      final request = CreateVendingMachineRequestDto.fromDraft(draft);
      final rawResponse = await _source.createVendingMachine(request.toMap());
      final response = CreateVendingMachineResponseDto.fromMap(rawResponse);
      final machineId = VendingMachineId.tryParse(response.machineId);

      if (machineId == null) {
        return const AppResult<MachineRegistrationResult>.failure(
          ValidationFailure(field: 'machineId'),
        );
      }

      return AppResult<MachineRegistrationResult>.success(
        MachineRegistrationResult(
          machineId: machineId,
          created: response.created,
        ),
      );
    } on Object catch (error) {
      return AppResult<MachineRegistrationResult>.failure(
        FailureMapper.map(error),
      );
    }
  }
}
