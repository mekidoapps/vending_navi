import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/app_failure.dart';
import '../domain/models/machine_report_draft.dart';
import 'machine_report_state.dart';
import 'providers/machine_report_providers.dart';

final machineReportControllerProvider =
    NotifierProvider<MachineReportController, MachineReportState>(
      MachineReportController.new,
      name: 'machineReportControllerProvider',
    );

final class MachineReportController extends Notifier<MachineReportState> {
  @override
  MachineReportState build() {
    return MachineReportState.initial();
  }

  void begin(MachineReportDraft draft) {
    if (state.isSubmitting) {
      return;
    }

    state = MachineReportState(draft: draft);
  }

  /// Replacing a draft represents a new report and therefore drops the
  /// previous requestId.
  void replaceDraft(MachineReportDraft draft) {
    if (state.isSubmitting) {
      return;
    }

    state = MachineReportState(draft: draft);
  }

  void clearFailure() {
    state = state.copyWith(clearFailure: true);
  }

  void reset() {
    if (state.isSubmitting) {
      return;
    }

    state = MachineReportState.initial();
  }

  Future<bool> submit() async {
    if (state.isSubmitting) {
      return false;
    }

    final draft = state.draft;

    if (draft == null) {
      state = state.copyWith(
        failure: const ValidationFailure(field: 'report'),
        clearResult: true,
      );
      return false;
    }

    final requestId =
        state.requestId ??
        ref.read(machineReportRequestIdGeneratorProvider).next();

    state = state.copyWith(
      requestId: requestId,
      isSubmitting: true,
      clearFailure: true,
      clearResult: true,
    );

    final result = await ref
        .read(machineReportRepositoryProvider)
        .submitReport(requestId: requestId, draft: draft);

    final failure = result.failureOrNull;

    if (failure != null) {
      state = state.copyWith(
        isSubmitting: false,
        failure: failure,
        clearResult: true,
      );
      return false;
    }

    final value = result.valueOrNull;

    if (value == null) {
      state = state.copyWith(
        isSubmitting: false,
        failure: const UnknownFailure(),
        clearResult: true,
      );
      return false;
    }

    state = state.copyWith(
      isSubmitting: false,
      result: value,
      clearFailure: true,
    );

    return true;
  }
}
