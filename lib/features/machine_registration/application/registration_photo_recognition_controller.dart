import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../product_master/application/providers/product_master_providers.dart';
import '../../product_master/domain/entities/manufacturer.dart';
import '../../product_master/domain/entities/product.dart';
import '../domain/entities/photo_recognition_result.dart';
import 'providers/machine_registration_providers.dart';
import 'registration_photo_recognition_state.dart';

final registrationPhotoRecognitionControllerProvider =
    NotifierProvider<
      RegistrationPhotoRecognitionController,
      RegistrationPhotoRecognitionState
    >(
      RegistrationPhotoRecognitionController.new,
      name: 'registrationPhotoRecognitionControllerProvider',
    );

final class RegistrationPhotoRecognitionController
    extends Notifier<RegistrationPhotoRecognitionState> {
  @override
  RegistrationPhotoRecognitionState build() {
    return const RegistrationPhotoRecognitionState();
  }

  Future<void> recognize(String uploadId) async {
    final normalizedUploadId = uploadId.trim();
    if (normalizedUploadId.isEmpty || state.isLoading) {
      return;
    }

    final requestId = ref
        .read(recognitionRequestIdGeneratorProvider)
        .generate();

    await _runRecognition(
      uploadId: normalizedUploadId,
      recognitionRequestId: requestId,
    );
  }

  Future<void> reanalyze() async {
    final uploadId = state.uploadId;
    if (uploadId == null || uploadId.trim().isEmpty || state.isLoading) {
      return;
    }

    final requestId = ref
        .read(recognitionRequestIdGeneratorProvider)
        .generate();

    await _runRecognition(uploadId: uploadId, recognitionRequestId: requestId);
  }

  Future<void> _runRecognition({
    required String uploadId,
    required String recognitionRequestId,
  }) async {
    state = RegistrationPhotoRecognitionState(
      stage: RegistrationPhotoRecognitionStage.loading,
      uploadId: uploadId,
      recognitionRequestId: recognitionRequestId,
    );

    final recognitionResult = await ref
        .read(photoRecognitionRepositoryProvider)
        .recognize(
          recognitionRequestId: recognitionRequestId,
          uploadId: uploadId,
        );

    if (recognitionResult.failureOrNull != null) {
      state = RegistrationPhotoRecognitionState(
        stage: RegistrationPhotoRecognitionStage.failed,
        uploadId: uploadId,
        recognitionRequestId: recognitionRequestId,
        failureMessage: '写真を認識できませんでした。別の登録方法を使うこともできます。',
      );
      return;
    }

    final recognition = recognitionResult.valueOrNull;
    if (recognition == null ||
        recognition.status == PhotoRecognitionStatus.failed) {
      state = RegistrationPhotoRecognitionState(
        stage: RegistrationPhotoRecognitionStage.failed,
        uploadId: uploadId,
        recognitionRequestId: recognitionRequestId,
        failureMessage: '写真から候補を見つけられませんでした。撮り直すか、別の登録方法を選べます。',
      );
      return;
    }

    final manufacturerResult = await ref
        .read(manufacturerRepositoryProvider)
        .getManufacturers(activeOnly: true);
    final productResult = await ref
        .read(productRepositoryProvider)
        .getProducts(activeOnly: true);

    if (manufacturerResult.failureOrNull != null ||
        productResult.failureOrNull != null) {
      state = RegistrationPhotoRecognitionState(
        stage: RegistrationPhotoRecognitionStage.failed,
        uploadId: uploadId,
        recognitionRequestId: recognitionRequestId,
        failureMessage: '候補の商品情報を読み込めませんでした。もう一度お試しください。',
      );
      return;
    }

    final manufacturers =
        (manufacturerResult.valueOrNull ?? const <Manufacturer>[])
            .where((item) => item.isActive)
            .toList(growable: false);
    final products = (productResult.valueOrNull ?? const <Product>[])
        .where((item) => item.isActive)
        .toList(growable: false);

    final manufacturerIds = manufacturers.map((item) => item.id.value).toSet();
    final productIds = products.map((item) => item.id.value).toSet();

    final aiManufacturerCandidateIds = recognition.manufacturerCandidateIds
        .map((item) => item.value)
        .where(manufacturerIds.contains)
        .toList(growable: false);
    final aiProductCandidateIds = recognition.productCandidateIds
        .map((item) => item.value)
        .where(productIds.contains)
        .toList(growable: false);

    state = RegistrationPhotoRecognitionState(
      stage: RegistrationPhotoRecognitionStage.ready,
      uploadId: uploadId,
      recognitionRequestId: recognitionRequestId,
      manufacturers: List<Manufacturer>.unmodifiable(manufacturers),
      products: List<Product>.unmodifiable(products),
      aiManufacturerCandidateIds: List<String>.unmodifiable(
        aiManufacturerCandidateIds,
      ),
      aiProductCandidateIds: List<String>.unmodifiable(aiProductCandidateIds),
      selectedManufacturerId: aiManufacturerCandidateIds.isEmpty
          ? null
          : aiManufacturerCandidateIds.first,
      selectedProductIds: Set<String>.unmodifiable(aiProductCandidateIds),
      unresolvedLabels: List<String>.unmodifiable(recognition.unresolvedLabels),
    );
  }

  void selectManufacturer(String? manufacturerId) {
    final normalized = manufacturerId?.trim() ?? '';
    if (normalized.isEmpty) {
      state = state.copyWith(clearSelectedManufacturerId: true);
      return;
    }

    final exists = state.manufacturers.any(
      (manufacturer) => manufacturer.id.value == normalized,
    );
    if (!exists) {
      return;
    }

    state = state.copyWith(selectedManufacturerId: normalized);
  }

  void replaceSelectedProducts(Set<String> productIds) {
    final validIds = state.products.map((product) => product.id.value).toSet();

    final normalized = productIds
        .map((value) => value.trim())
        .where(validIds.contains)
        .toSet();

    state = state.copyWith(
      selectedProductIds: Set<String>.unmodifiable(normalized),
    );
  }

  void reset() {
    state = const RegistrationPhotoRecognitionState();
  }
}
