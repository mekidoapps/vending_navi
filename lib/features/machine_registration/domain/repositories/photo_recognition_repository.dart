import '../../../../core/result/app_result.dart';
import '../entities/photo_recognition_result.dart';

abstract interface class PhotoRecognitionRepository {
  Future<AppResult<PhotoRecognitionResult>> recognize({
    required String recognitionRequestId,
    required String uploadId,
  });
}
