import '../../../product_master/domain/value_objects/master_id.dart';

enum PhotoRecognitionStatus {
  completed,
  failed;

  static PhotoRecognitionStatus? tryParse(String value) {
    return switch (value.trim()) {
      'completed' => PhotoRecognitionStatus.completed,
      'failed' => PhotoRecognitionStatus.failed,
      _ => null,
    };
  }
}

final class PhotoRecognitionResult {
  const PhotoRecognitionResult({
    required this.manufacturerCandidateIds,
    required this.productCandidateIds,
    required this.unresolvedLabels,
    required this.status,
  });

  final List<ManufacturerId> manufacturerCandidateIds;
  final List<ProductId> productCandidateIds;
  final List<String> unresolvedLabels;
  final PhotoRecognitionStatus status;
}
