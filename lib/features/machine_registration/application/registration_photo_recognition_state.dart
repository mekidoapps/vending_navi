import '../../product_master/domain/entities/manufacturer.dart';
import '../../product_master/domain/entities/product.dart';

enum RegistrationPhotoRecognitionStage { idle, loading, ready, failed }

final class RegistrationPhotoRecognitionState {
  const RegistrationPhotoRecognitionState({
    this.stage = RegistrationPhotoRecognitionStage.idle,
    this.uploadId,
    this.recognitionRequestId,
    this.manufacturers = const <Manufacturer>[],
    this.products = const <Product>[],
    this.aiManufacturerCandidateIds = const <String>[],
    this.aiProductCandidateIds = const <String>[],
    this.selectedManufacturerId,
    this.selectedProductIds = const <String>{},
    this.unresolvedLabels = const <String>[],
    this.failureMessage,
  });

  final RegistrationPhotoRecognitionStage stage;
  final String? uploadId;
  final String? recognitionRequestId;
  final List<Manufacturer> manufacturers;
  final List<Product> products;
  final List<String> aiManufacturerCandidateIds;
  final List<String> aiProductCandidateIds;
  final String? selectedManufacturerId;
  final Set<String> selectedProductIds;
  final List<String> unresolvedLabels;
  final String? failureMessage;

  bool get isLoading => stage == RegistrationPhotoRecognitionStage.loading;

  RegistrationPhotoRecognitionState copyWith({
    RegistrationPhotoRecognitionStage? stage,
    String? uploadId,
    String? recognitionRequestId,
    List<Manufacturer>? manufacturers,
    List<Product>? products,
    List<String>? aiManufacturerCandidateIds,
    List<String>? aiProductCandidateIds,
    String? selectedManufacturerId,
    bool clearSelectedManufacturerId = false,
    Set<String>? selectedProductIds,
    List<String>? unresolvedLabels,
    String? failureMessage,
    bool clearFailureMessage = false,
  }) {
    return RegistrationPhotoRecognitionState(
      stage: stage ?? this.stage,
      uploadId: uploadId ?? this.uploadId,
      recognitionRequestId: recognitionRequestId ?? this.recognitionRequestId,
      manufacturers: manufacturers ?? this.manufacturers,
      products: products ?? this.products,
      aiManufacturerCandidateIds:
          aiManufacturerCandidateIds ?? this.aiManufacturerCandidateIds,
      aiProductCandidateIds:
          aiProductCandidateIds ?? this.aiProductCandidateIds,
      selectedManufacturerId: clearSelectedManufacturerId
          ? null
          : (selectedManufacturerId ?? this.selectedManufacturerId),
      selectedProductIds: selectedProductIds ?? this.selectedProductIds,
      unresolvedLabels: unresolvedLabels ?? this.unresolvedLabels,
      failureMessage: clearFailureMessage
          ? null
          : (failureMessage ?? this.failureMessage),
    );
  }
}
