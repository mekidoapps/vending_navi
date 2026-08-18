import '../../../../core/result/app_result.dart';
import '../models/machine_report_draft.dart';
import '../models/machine_report_result.dart';

abstract interface class MachineReportRepository {
  Future<AppResult<MachineReportResult>> submitReport({
    required String requestId,
    required MachineReportDraft draft,
  });
}
