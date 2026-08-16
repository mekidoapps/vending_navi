import '../../../core/errors/app_failure.dart';
import '../domain/models/machine_product_update_draft.dart';
import '../domain/models/machine_product_update_result.dart';

final class MachineProductUpdateState {
  const MachineProductUpdateState({
    this.draft,
    this.requestId,
    this.isSubmitting = false,
    this.failure,
    this.result,
  });

  factory MachineProductUpdateState.initial() {
    return const MachineProductUpdateState();
  }

  final MachineProductUpdateDraft? draft;

  /// Generated only when submission starts.
  ///
  /// It is intentionally retained after a failed submission so retrying the
  /// same edit uses the backend idempotency contract. Replacing the draft
  /// clears it because that represents a different update request.
  final String? requestId;

  final bool isSubmitting;
  final AppFailure? failure;
  final MachineProductUpdateResult? result;

  bool get hasChanges => draft?.operations.isNotEmpty == true;

  MachineProductUpdateState copyWith({
    MachineProductUpdateDraft? draft,
    bool replaceDraft = false,
    String? requestId,
    bool clearRequestId = false,
    bool? isSubmitting,
    AppFailure? failure,
    bool clearFailure = false,
    MachineProductUpdateResult? result,
    bool clearResult = false,
  }) {
    return MachineProductUpdateState(
      draft: replaceDraft ? draft : this.draft,
      requestId: clearRequestId ? null : requestId ?? this.requestId,
      isSubmitting: isSubmitting ?? this.isSubmitting,
      failure: clearFailure ? null : failure ?? this.failure,
      result: clearResult ? null : result ?? this.result,
    );
  }
}
