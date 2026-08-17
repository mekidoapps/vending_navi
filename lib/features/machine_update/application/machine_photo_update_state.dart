import 'dart:typed_data';

import '../../product_master/domain/entities/product.dart';

enum MachinePhotoUpdateStage {
  idle,
  capturing,
  normalizing,
  uploading,
  recognizing,
  ready,
  failed,
}

final class MachinePhotoUpdateState {
  const MachinePhotoUpdateState({
    this.stage = MachinePhotoUpdateStage.idle,
    this.previewBytes,
    this.uploadId,
    this.products = const <Product>[],
    this.aiProductCandidateIds = const <String>[],
    this.selectedProductIds = const <String>{},
    this.unresolvedLabels = const <String>[],
    this.failureMessage,
  });

  final MachinePhotoUpdateStage stage;
  final Uint8List? previewBytes;
  final String? uploadId;

  /// Active Product Master records available to the candidate screen.
  final List<Product> products;

  /// Product IDs actually returned by the recognition service and still
  /// present in the active Product Master.
  final List<String> aiProductCandidateIds;

  /// User-confirmed selection. Initially equal to AI candidates.
  final Set<String> selectedProductIds;

  /// Labels seen by AI but intentionally not mapped to a Product Master ID.
  final List<String> unresolvedLabels;

  final String? failureMessage;

  bool get isBusy =>
      stage == MachinePhotoUpdateStage.capturing ||
      stage == MachinePhotoUpdateStage.normalizing ||
      stage == MachinePhotoUpdateStage.uploading ||
      stage == MachinePhotoUpdateStage.recognizing;

  bool get canRetryRecognition =>
      uploadId != null && uploadId!.trim().isNotEmpty && !isBusy;

  MachinePhotoUpdateState copyWith({
    MachinePhotoUpdateStage? stage,
    Uint8List? previewBytes,
    bool clearPreviewBytes = false,
    String? uploadId,
    bool clearUploadId = false,
    List<Product>? products,
    List<String>? aiProductCandidateIds,
    Set<String>? selectedProductIds,
    List<String>? unresolvedLabels,
    String? failureMessage,
    bool clearFailureMessage = false,
  }) {
    return MachinePhotoUpdateState(
      stage: stage ?? this.stage,
      previewBytes: clearPreviewBytes
          ? null
          : (previewBytes ?? this.previewBytes),
      uploadId: clearUploadId ? null : (uploadId ?? this.uploadId),
      products: products ?? this.products,
      aiProductCandidateIds:
          aiProductCandidateIds ?? this.aiProductCandidateIds,
      selectedProductIds: selectedProductIds ?? this.selectedProductIds,
      unresolvedLabels: unresolvedLabels ?? this.unresolvedLabels,
      failureMessage: clearFailureMessage
          ? null
          : (failureMessage ?? this.failureMessage),
    );
  }
}
