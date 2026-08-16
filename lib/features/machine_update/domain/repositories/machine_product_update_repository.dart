import '../../../../core/result/app_result.dart';
import '../models/machine_product_update_draft.dart';
import '../models/machine_product_update_result.dart';

abstract interface class MachineProductUpdateRepository {
  Future<AppResult<MachineProductUpdateResult>> updateProducts({
    required String requestId,
    required MachineProductUpdateDraft draft,
  });
}
