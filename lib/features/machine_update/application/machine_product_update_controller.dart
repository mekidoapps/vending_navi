import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/app_failure.dart';
import '../domain/models/machine_product_update_draft.dart';
import 'machine_product_update_state.dart';
import 'providers/machine_product_update_providers.dart';

final machineProductUpdateControllerProvider =
    NotifierProvider<MachineProductUpdateController, MachineProductUpdateState>(
      MachineProductUpdateController.new,
      name: 'machineProductUpdateControllerProvider',
    );

final class MachineProductUpdateController
    extends Notifier<MachineProductUpdateState> {
  @override
  MachineProductUpdateState build() {
    return MachineProductUpdateState.initial();
  }

  void begin(MachineProductUpdateDraft draft) {
    if (state.isSubmitting) {
      return;
    }

    state = MachineProductUpdateState(draft: draft);
  }

  void replaceDraft(MachineProductUpdateDraft draft) {
    if (state.isSubmitting) {
      return;
    }

    state = MachineProductUpdateState(draft: draft);
  }

  void clearFailure() {
    state = state.copyWith(clearFailure: true);
  }

  void reset() {
    if (state.isSubmitting) {
      return;
    }

    state = MachineProductUpdateState.initial();
  }

  Future<bool> submit() async {
    if (state.isSubmitting) {
      return false;
    }

    final draft = state.draft;

    if (draft == null || draft.operations.isEmpty) {
      state = state.copyWith(
        failure: const ValidationFailure(field: 'operations'),
        clearResult: true,
      );
      return false;
    }

    final requestId =
        state.requestId ??
        ref.read(machineProductUpdateRequestIdGeneratorProvider).next();

    state = state.copyWith(
      requestId: requestId,
      isSubmitting: true,
      clearFailure: true,
      clearResult: true,
    );

    final result = await ref
        .read(machineProductUpdateRepositoryProvider)
        .updateProducts(requestId: requestId, draft: draft);

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
