import '../../../core/errors/app_failure.dart';
import '../domain/models/machine_photo_finalization_result.dart';
import '../domain/models/machine_product_update_draft.dart';

enum MachinePhotoUpdateSubmitStage {
  idle,
  updatingProducts,
  finalizingPhoto,
  completed,
}

final class MachinePhotoUpdateSubmitState {
  const MachinePhotoUpdateSubmitState({
    this.draft,
    this.productRequestId,
    this.photoRequestId,
    this.stage = MachinePhotoUpdateSubmitStage.idle,
    this.productCompleted = false,
    this.photoCompleted = false,
    this.failure,
    this.result,
  });

  factory MachinePhotoUpdateSubmitState.initial() {
    return const MachinePhotoUpdateSubmitState();
  }

  final MachineProductUpdateDraft? draft;
  final String? productRequestId;
  final String? photoRequestId;
  final MachinePhotoUpdateSubmitStage stage;

  /// True after updateVendingMachineProducts completed successfully.
  ///
  /// This remains true when formal photo saving fails so retrying does not
  /// submit the product update again.
  final bool productCompleted;

  final bool photoCompleted;
  final AppFailure? failure;
  final MachinePhotoFinalizationResult? result;

  bool get isSubmitting =>
      stage == MachinePhotoUpdateSubmitStage.updatingProducts ||
      stage == MachinePhotoUpdateSubmitStage.finalizingPhoto;

  bool get isCompleted =>
      stage == MachinePhotoUpdateSubmitStage.completed && photoCompleted;

  MachinePhotoUpdateSubmitState copyWith({
    MachineProductUpdateDraft? draft,
    bool replaceDraft = false,
    String? productRequestId,
    bool clearProductRequestId = false,
    String? photoRequestId,
    bool clearPhotoRequestId = false,
    MachinePhotoUpdateSubmitStage? stage,
    bool? productCompleted,
    bool? photoCompleted,
    AppFailure? failure,
    bool clearFailure = false,
    MachinePhotoFinalizationResult? result,
    bool clearResult = false,
  }) {
    return MachinePhotoUpdateSubmitState(
      draft: replaceDraft ? draft : this.draft,
      productRequestId: clearProductRequestId
          ? null
          : productRequestId ?? this.productRequestId,
      photoRequestId: clearPhotoRequestId
          ? null
          : photoRequestId ?? this.photoRequestId,
      stage: stage ?? this.stage,
      productCompleted: productCompleted ?? this.productCompleted,
      photoCompleted: photoCompleted ?? this.photoCompleted,
      failure: clearFailure ? null : failure ?? this.failure,
      result: clearResult ? null : result ?? this.result,
    );
  }
}
