import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/app_failure.dart';
import '../domain/models/machine_product_update_draft.dart';
import '../domain/models/machine_product_update_operation.dart';
import 'machine_photo_update_submit_state.dart';
import 'providers/machine_photo_update_submit_providers.dart';
import 'providers/machine_product_update_providers.dart';

final machinePhotoUpdateSubmitControllerProvider =
    NotifierProvider<
      MachinePhotoUpdateSubmitController,
      MachinePhotoUpdateSubmitState
    >(
      MachinePhotoUpdateSubmitController.new,
      name: 'machinePhotoUpdateSubmitControllerProvider',
    );

final class MachinePhotoUpdateSubmitController
    extends Notifier<MachinePhotoUpdateSubmitState> {
  @override
  MachinePhotoUpdateSubmitState build() {
    return MachinePhotoUpdateSubmitState.initial();
  }

  void reset() {
    if (state.isSubmitting) {
      return;
    }

    state = MachinePhotoUpdateSubmitState.initial();
  }

  Future<bool> submit(MachineProductUpdateDraft draft) async {
    if (state.isSubmitting) {
      return false;
    }

    final uploadId = draft.temporaryPhotoUploadId?.trim();

    if (uploadId == null || uploadId.isEmpty) {
      state = MachinePhotoUpdateSubmitState(
        draft: draft,
        failure: const ValidationFailure(field: 'temporaryPhotoUploadId'),
      );
      return false;
    }

    if (!_sameDraft(state.draft, draft)) {
      state = MachinePhotoUpdateSubmitState(draft: draft);
    }

    if (draft.operations.isNotEmpty && !state.productCompleted) {
      final requestId =
          state.productRequestId ??
          ref.read(machineProductUpdateRequestIdGeneratorProvider).next();

      state = state.copyWith(
        productRequestId: requestId,
        stage: MachinePhotoUpdateSubmitStage.updatingProducts,
        clearFailure: true,
        clearResult: true,
      );

      final result = await ref
          .read(machineProductUpdateRepositoryProvider)
          .updateProducts(requestId: requestId, draft: draft);

      final failure = result.failureOrNull;

      if (failure != null) {
        state = state.copyWith(
          stage: MachinePhotoUpdateSubmitStage.idle,
          failure: failure,
          clearResult: true,
        );
        return false;
      }

      if (result.valueOrNull == null) {
        state = state.copyWith(
          stage: MachinePhotoUpdateSubmitStage.idle,
          failure: const UnknownFailure(),
          clearResult: true,
        );
        return false;
      }

      state = state.copyWith(
        stage: MachinePhotoUpdateSubmitStage.idle,
        productCompleted: true,
        clearFailure: true,
      );
    }

    if (!state.photoCompleted) {
      final requestId =
          state.photoRequestId ??
          ref.read(machinePhotoFinalizationRequestIdGeneratorProvider).next();

      state = state.copyWith(
        photoRequestId: requestId,
        stage: MachinePhotoUpdateSubmitStage.finalizingPhoto,
        clearFailure: true,
        clearResult: true,
      );

      final result = await ref
          .read(machinePhotoFinalizationRepositoryProvider)
          .addPhoto(
            requestId: requestId,
            machineId: draft.machineId,
            temporaryPhotoUploadId: uploadId,
          );

      final failure = result.failureOrNull;

      if (failure != null) {
        state = state.copyWith(
          stage: MachinePhotoUpdateSubmitStage.idle,
          failure: failure,
          clearResult: true,
        );
        return false;
      }

      final value = result.valueOrNull;

      if (value == null) {
        state = state.copyWith(
          stage: MachinePhotoUpdateSubmitStage.idle,
          failure: const UnknownFailure(),
          clearResult: true,
        );
        return false;
      }

      state = state.copyWith(
        stage: MachinePhotoUpdateSubmitStage.completed,
        photoCompleted: true,
        result: value,
        clearFailure: true,
      );
    }

    return state.isCompleted;
  }

  static bool _sameDraft(
    MachineProductUpdateDraft? left,
    MachineProductUpdateDraft right,
  ) {
    if (left == null ||
        left.machineId != right.machineId ||
        left.temporaryPhotoUploadId != right.temporaryPhotoUploadId ||
        left.operations.length != right.operations.length) {
      return false;
    }

    for (var index = 0; index < left.operations.length; index++) {
      if (!_sameOperation(left.operations[index], right.operations[index])) {
        return false;
      }
    }

    return true;
  }

  static bool _sameOperation(
    MachineProductUpdateOperation left,
    MachineProductUpdateOperation right,
  ) {
    return left.type == right.type &&
        left.productId == right.productId &&
        left.source == right.source &&
        left.soldOut == right.soldOut;
  }
}
