import '../../../core/errors/app_failure.dart';
import '../domain/models/machine_report_draft.dart';
import '../domain/models/machine_report_result.dart';

final class MachineReportState {
  const MachineReportState({
    this.draft,
    this.requestId,
    this.isSubmitting = false,
    this.failure,
    this.result,
  });

  factory MachineReportState.initial() {
    return const MachineReportState();
  }

  final MachineReportDraft? draft;

  /// Retained after a failed submission so retry uses the same backend
  /// idempotency requestId.
  final String? requestId;

  final bool isSubmitting;
  final AppFailure? failure;
  final MachineReportResult? result;

  MachineReportState copyWith({
    MachineReportDraft? draft,
    bool replaceDraft = false,
    String? requestId,
    bool clearRequestId = false,
    bool? isSubmitting,
    AppFailure? failure,
    bool clearFailure = false,
    MachineReportResult? result,
    bool clearResult = false,
  }) {
    return MachineReportState(
      draft: replaceDraft ? draft : this.draft,
      requestId: clearRequestId ? null : requestId ?? this.requestId,
      isSubmitting: isSubmitting ?? this.isSubmitting,
      failure: clearFailure ? null : failure ?? this.failure,
      result: clearResult ? null : result ?? this.result,
    );
  }
}
