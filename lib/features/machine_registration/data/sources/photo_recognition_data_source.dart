abstract interface class PhotoRecognitionDataSource {
  Future<Map<String, Object?>> recognize({
    required String recognitionRequestId,
    required String uploadId,
  });
}
