import 'dart:typed_data';

import '../models/temporary_registration_photo_upload.dart';

abstract interface class TemporaryRegistrationPhotoUploader {
  Future<TemporaryRegistrationPhotoUpload> upload({
    required String uploadId,
    required Uint8List jpegBytes,
  });
}
