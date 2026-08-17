import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../machine_registration/application/providers/machine_registration_providers.dart';
import '../../machine_registration/domain/entities/photo_recognition_result.dart';
import '../../machine_registration/domain/services/registration_photo_exception.dart';
import '../../product_master/application/providers/product_master_providers.dart';
import '../../product_master/domain/entities/product.dart';
import 'machine_photo_update_state.dart';

final machinePhotoUpdateControllerProvider =
    NotifierProvider<MachinePhotoUpdateController, MachinePhotoUpdateState>(
      MachinePhotoUpdateController.new,
      name: 'machinePhotoUpdateControllerProvider',
    );

final class MachinePhotoUpdateController
    extends Notifier<MachinePhotoUpdateState> {
  @override
  MachinePhotoUpdateState build() {
    return const MachinePhotoUpdateState();
  }

  /// Captures a new image and carries it through the complete reusable
  /// Phase 7 pipeline:
  ///
  /// camera -> normalize -> temporary Storage -> recognition -> Product Master
  ///
  /// No public vending-machine data is modified here.
  Future<bool> captureAndRecognize() async {
    if (state.isBusy) {
      return false;
    }

    state = const MachinePhotoUpdateState(
      stage: MachinePhotoUpdateStage.capturing,
    );

    try {
      final sourceBytes = await ref
          .read(registrationPhotoCaptureSourceProvider)
          .capture();

      if (sourceBytes == null) {
        state = const MachinePhotoUpdateState();
        return false;
      }

      state = const MachinePhotoUpdateState(
        stage: MachinePhotoUpdateStage.normalizing,
      );

      final normalized = await ref
          .read(registrationPhotoNormalizerProvider)
          .normalize(sourceBytes);

      final uploadId = ref.read(photoUploadIdGeneratorProvider).generate();

      state = MachinePhotoUpdateState(
        stage: MachinePhotoUpdateStage.uploading,
        previewBytes: normalized.bytes,
      );

      final upload = await ref
          .read(temporaryRegistrationPhotoUploaderProvider)
          .upload(uploadId: uploadId, jpegBytes: normalized.bytes);

      state = MachinePhotoUpdateState(
        stage: MachinePhotoUpdateStage.recognizing,
        previewBytes: normalized.bytes,
        uploadId: upload.uploadId,
      );

      return await _recognize(
        uploadId: upload.uploadId,
        previewBytes: normalized.bytes,
      );
    } on RegistrationPhotoException catch (error) {
      state = MachinePhotoUpdateState(
        stage: MachinePhotoUpdateStage.failed,
        previewBytes: state.previewBytes,
        uploadId: state.uploadId,
        failureMessage: error.userMessage,
      );
      return false;
    } catch (_) {
      state = MachinePhotoUpdateState(
        stage: MachinePhotoUpdateStage.failed,
        previewBytes: state.previewBytes,
        uploadId: state.uploadId,
        failureMessage: '写真を準備できませんでした。もう一度お試しください。',
      );
      return false;
    }
  }

  /// Re-runs AI recognition against the exact same temporary upload.
  /// This intentionally does not capture or upload another image.
  Future<bool> reanalyze() async {
    if (state.isBusy) {
      return false;
    }

    final uploadId = state.uploadId;
    final previewBytes = state.previewBytes;

    if (uploadId == null || uploadId.trim().isEmpty || previewBytes == null) {
      return false;
    }

    return await _recognize(uploadId: uploadId, previewBytes: previewBytes);
  }

  Future<bool> _recognize({
    required String uploadId,
    required Uint8List previewBytes,
  }) async {
    final recognitionRequestId = ref
        .read(recognitionRequestIdGeneratorProvider)
        .generate();

    state = MachinePhotoUpdateState(
      stage: MachinePhotoUpdateStage.recognizing,
      previewBytes: previewBytes,
      uploadId: uploadId,
    );

    final recognitionResult = await ref
        .read(photoRecognitionRepositoryProvider)
        .recognize(
          recognitionRequestId: recognitionRequestId,
          uploadId: uploadId,
        );

    if (recognitionResult.failureOrNull != null) {
      state = MachinePhotoUpdateState(
        stage: MachinePhotoUpdateStage.failed,
        previewBytes: previewBytes,
        uploadId: uploadId,
        failureMessage: '写真を認識できませんでした。もう一度お試しください。',
      );
      return false;
    }

    final recognition = recognitionResult.valueOrNull;

    if (recognition == null ||
        recognition.status == PhotoRecognitionStatus.failed) {
      state = MachinePhotoUpdateState(
        stage: MachinePhotoUpdateStage.failed,
        previewBytes: previewBytes,
        uploadId: uploadId,
        failureMessage: '写真から商品候補を見つけられませんでした。撮り直すか、もう一度お試しください。',
      );
      return false;
    }

    final productResult = await ref
        .read(productRepositoryProvider)
        .getProducts(activeOnly: true);

    if (productResult.failureOrNull != null) {
      state = MachinePhotoUpdateState(
        stage: MachinePhotoUpdateStage.failed,
        previewBytes: previewBytes,
        uploadId: uploadId,
        failureMessage: '候補の商品情報を読み込めませんでした。もう一度お試しください。',
      );
      return false;
    }

    final products = (productResult.valueOrNull ?? const <Product>[])
        .where((product) => product.isSelectable)
        .toList(growable: false);

    final validProductIds = products.map((product) => product.id.value).toSet();

    final aiProductCandidateIds = recognition.productCandidateIds
        .map((productId) => productId.value)
        .where(validProductIds.contains)
        .toSet()
        .toList(growable: false);

    state = MachinePhotoUpdateState(
      stage: MachinePhotoUpdateStage.ready,
      previewBytes: previewBytes,
      uploadId: uploadId,
      products: List<Product>.unmodifiable(products),
      aiProductCandidateIds: List<String>.unmodifiable(aiProductCandidateIds),
      selectedProductIds: Set<String>.unmodifiable(aiProductCandidateIds),
      unresolvedLabels: List<String>.unmodifiable(recognition.unresolvedLabels),
    );

    return true;
  }

  void replaceSelectedProducts(Set<String> productIds) {
    if (state.stage != MachinePhotoUpdateStage.ready) {
      return;
    }

    final validIds = state.products.map((product) => product.id.value).toSet();

    final normalized = productIds
        .map((productId) => productId.trim())
        .where(validIds.contains)
        .toSet();

    state = state.copyWith(
      selectedProductIds: Set<String>.unmodifiable(normalized),
    );
  }

  void reset() {
    if (state.isBusy) {
      return;
    }

    state = const MachinePhotoUpdateState();
  }
}
