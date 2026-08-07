import '../../../../core/result/app_result.dart';
import '../entities/vending_machine.dart';
import '../models/vending_machine_read_batch.dart';
import '../value_objects/vending_machine_id.dart';

abstract interface class VendingMachineRepository {
  Future<AppResult<VendingMachine>> getMachine(VendingMachineId id);

  /// Migration/compatibility snapshot used while v1 and v2 coexist.
  ///
  /// Home map must not use this as its final nearby-query API. P3-05 adds the
  /// geographic query after the search range policy is fixed.
  Future<AppResult<VendingMachineReadBatch>> getCompatibilitySnapshot();
}
