import '../../../../core/errors/app_failure.dart';
import '../../../../core/errors/failure_mapper.dart';
import '../../../../core/result/app_result.dart';
import '../../../vending_machine/domain/value_objects/vending_machine_id.dart';
import '../../domain/models/machine_report_draft.dart';
import '../../domain/models/machine_report_result.dart';
import '../../domain/repositories/machine_report_repository.dart';
import '../dtos/submit_machine_report_request_dto.dart';
import '../dtos/submit_machine_report_response_dto.dart';
import '../sources/machine_report_data_source.dart';

final class MachineReportRepositoryImpl implements MachineReportRepository {
  const MachineReportRepositoryImpl(this._source);

  final MachineReportDataSource _source;

  @override
  Future<AppResult<MachineReportResult>> submitReport({
    required String requestId,
    required MachineReportDraft draft,
  }) async {
    try {
      final request = SubmitMachineReportRequestDto(
        requestId: requestId,
        draft: draft,
      );

      final rawResponse = await _source.submitMachineReport(request.toMap());

      final response = SubmitMachineReportResponseDto.fromMap(rawResponse);

      final machineId = VendingMachineId.tryParse(response.machineId);

      if (machineId == null || machineId != draft.machineId) {
        return const AppResult<MachineReportResult>.failure(
          ValidationFailure(field: 'machineId'),
        );
      }

      return AppResult<MachineReportResult>.success(
        MachineReportResult(machineId: machineId, reportId: response.reportId),
      );
    } on Object catch (error) {
      return AppResult<MachineReportResult>.failure(FailureMapper.map(error));
    }
  }
}
