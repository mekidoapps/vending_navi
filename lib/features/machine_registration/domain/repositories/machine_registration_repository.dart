import '../../../../core/result/app_result.dart';
import '../entities/machine_registration_draft.dart';
import '../entities/machine_registration_result.dart';

abstract interface class MachineRegistrationRepository {
  Future<AppResult<MachineRegistrationResult>> createVendingMachine(
    MachineRegistrationDraft draft,
  );
}
