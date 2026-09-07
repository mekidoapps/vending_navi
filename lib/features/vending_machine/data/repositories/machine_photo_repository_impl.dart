import '../../../../core/errors/failure_mapper.dart';
import '../../../../core/result/app_result.dart';
import '../../domain/entities/public_machine_photo.dart';
import '../../domain/repositories/machine_photo_repository.dart';
import '../../domain/value_objects/vending_machine_id.dart';
import '../sources/firestore_machine_photo_source.dart';
import '../sources/vending_machine_document.dart';

final class MachinePhotoRepositoryImpl implements MachinePhotoRepository {
  MachinePhotoRepositoryImpl(this._source);

  final FirestoreMachinePhotoSource _source;

  @override
  Future<AppResult<List<PublicMachinePhoto>>> getActivePhotos(
    VendingMachineId machineId,
  ) async {
    try {
      final documents = await _source.fetchActive(machineId.value);
      final photos = mapActivePublicMachinePhotos(documents);
      return AppResult<List<PublicMachinePhoto>>.success(
        List<PublicMachinePhoto>.unmodifiable(photos),
      );
    } on Object catch (error) {
      return AppResult<List<PublicMachinePhoto>>.failure(FailureMapper.map(error));
    }
  }
}

List<PublicMachinePhoto> mapActivePublicMachinePhotos(
  Iterable<VendingMachineDocument> documents,
) {
  final photos = <PublicMachinePhoto>[];
  for (final document in documents) {
    final photo = PublicMachinePhoto.fromDocument(document.id, document.data);
    if (photo != null && photo.status == 'active') photos.add(photo);
  }
  return List<PublicMachinePhoto>.unmodifiable(photos);
}
