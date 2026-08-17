import '../../../core/errors/app_failure.dart';
import '../domain/models/machine_correction_draft.dart';
import '../domain/models/machine_correction_result.dart';

final class MachineCorrectionState {
  const MachineCorrectionState({
    this.draft,
    this.requestId,
    this.isSubmitting = false,
    this.failure,
    this.result,
  });

  factory MachineCorrectionState.initial() {
    return const MachineCorrectionState();
  }

  final MachineCorrectionDraft? draft;

  /// Retained after a failed attempt so retry uses the same backend
  /// idempotency requestId.
  final String? requestId;

  final bool isSubmitting;
  final AppFailure? failure;
  final MachineCorrectionResult? result;

  bool get hasChanges => draft?.hasChanges == true;

  MachineCorrectionState copyWith({
    MachineCorrectionDraft? draft,
    bool replaceDraft = false,
    String? requestId,
    bool clearRequestId = false,
    bool? isSubmitting,
    AppFailure? failure,
    bool clearFailure = false,
    MachineCorrectionResult? result,
    bool clearResult = false,
  }) {
    return MachineCorrectionState(
      draft: replaceDraft ? draft : this.draft,
      requestId: clearRequestId ? null : requestId ?? this.requestId,
      isSubmitting: isSubmitting ?? this.isSubmitting,
      failure: clearFailure ? null : failure ?? this.failure,
      result: clearResult ? null : result ?? this.result,
    );
  }
}
