import '../../../../core/errors/failure_mapper.dart';
import '../../../../core/result/app_result.dart';
import '../../domain/entities/photo_recognition_result.dart';
import '../../domain/repositories/photo_recognition_repository.dart';
import '../dtos/photo_recognition_response_dto.dart';
import '../sources/photo_recognition_data_source.dart';

final class PhotoRecognitionRepositoryImpl
    implements PhotoRecognitionRepository {
  PhotoRecognitionRepositoryImpl(this._source);

  final PhotoRecognitionDataSource _source;

  @override
  Future<AppResult<PhotoRecognitionResult>> recognize({
    required String recognitionRequestId,
    required String uploadId,
  }) async {
    try {
      final map = await _source.recognize(
        recognitionRequestId: recognitionRequestId,
        uploadId: uploadId,
      );
      final dto = PhotoRecognitionResponseDto.fromMap(map);
      return AppResult<PhotoRecognitionResult>.success(dto.toDomain());
    } on Object catch (error) {
      return AppResult<PhotoRecognitionResult>.failure(
        FailureMapper.map(error),
      );
    }
  }
}
