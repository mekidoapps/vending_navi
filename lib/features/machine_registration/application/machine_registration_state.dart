import '../../vending_machine/domain/value_objects/vending_machine_id.dart';
import '../../../core/errors/app_failure.dart';
import '../domain/entities/machine_registration_draft.dart';

enum MachineRegistrationStep {
  position,
  duplicateCheck,
  method,
  photoCapture,
  photoReady,
  manufacturer,
  confirm,
  submitting,
  completed,
}

final class MachineRegistrationState {
  const MachineRegistrationState({
    required this.draft,
    this.step = MachineRegistrationStep.position,
    this.failure,
    this.createdMachineId,
  });

  final MachineRegistrationDraft draft;
  final MachineRegistrationStep step;
  final AppFailure? failure;
  final VendingMachineId? createdMachineId;

  bool get isSubmitting => step == MachineRegistrationStep.submitting;

  MachineRegistrationState copyWith({
    MachineRegistrationDraft? draft,
    MachineRegistrationStep? step,
    AppFailure? failure,
    bool clearFailure = false,
    VendingMachineId? createdMachineId,
    bool clearCreatedMachineId = false,
  }) {
    return MachineRegistrationState(
      draft: draft ?? this.draft,
      step: step ?? this.step,
      failure: clearFailure ? null : (failure ?? this.failure),
      createdMachineId: clearCreatedMachineId
          ? null
          : (createdMachineId ?? this.createdMachineId),
    );
  }
}
