import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/app_failure.dart';
import '../domain/models/machine_correction_draft.dart';
import 'machine_correction_state.dart';
import 'providers/machine_correction_providers.dart';

final machineCorrectionControllerProvider =
    NotifierProvider<MachineCorrectionController, MachineCorrectionState>(
      MachineCorrectionController.new,
      name: 'machineCorrectionControllerProvider',
    );

final class MachineCorrectionController
    extends Notifier<MachineCorrectionState> {
  @override
  MachineCorrectionState build() {
    return MachineCorrectionState.initial();
  }

  void begin(MachineCorrectionDraft draft) {
    if (state.isSubmitting) {
      return;
    }

    state = MachineCorrectionState(draft: draft);
  }

  void replaceDraft(MachineCorrectionDraft draft) {
    if (state.isSubmitting) {
      return;
    }

    state = MachineCorrectionState(draft: draft);
  }

  void clearFailure() {
    state = state.copyWith(clearFailure: true);
  }

  void reset() {
    if (state.isSubmitting) {
      return;
    }

    state = MachineCorrectionState.initial();
  }

  Future<bool> submit() async {
    if (state.isSubmitting) {
      return false;
    }

    final draft = state.draft;

    if (draft == null || !draft.hasChanges) {
      state = state.copyWith(
        failure: const ValidationFailure(field: 'changes'),
        clearResult: true,
      );
      return false;
    }

    final requestId =
        state.requestId ??
        ref.read(machineCorrectionRequestIdGeneratorProvider).next();

    state = state.copyWith(
      requestId: requestId,
      isSubmitting: true,
      clearFailure: true,
      clearResult: true,
    );

    final result = await ref
        .read(machineCorrectionRepositoryProvider)
        .submitCorrection(requestId: requestId, draft: draft);

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
