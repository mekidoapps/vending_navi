import '../../../../core/result/app_result.dart';
import '../models/machine_correction_draft.dart';
import '../models/machine_correction_result.dart';

abstract interface class MachineCorrectionRepository {
  Future<AppResult<MachineCorrectionResult>> submitCorrection({
    required String requestId,
    required MachineCorrectionDraft draft,
  });
}
