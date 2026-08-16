import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';

import '../../domain/services/registration_photo_capture_source.dart';
import '../../domain/services/registration_photo_exception.dart';

final class ImagePickerRegistrationPhotoCaptureSource
    implements RegistrationPhotoCaptureSource {
  ImagePickerRegistrationPhotoCaptureSource({ImagePicker? picker})
    : _picker = picker ?? ImagePicker();

  final ImagePicker _picker;

  @override
  Future<Uint8List?> capture() async {
    try {
      final file = await _picker.pickImage(
        source: ImageSource.camera,
        preferredCameraDevice: CameraDevice.rear,
      );
      if (file == null) {
        return null;
      }

      final bytes = await file.readAsBytes();
      if (bytes.isEmpty) {
        throw const RegistrationPhotoException(
          code: RegistrationPhotoErrorCode.captureFailed,
          userMessage: '写真を読み込めませんでした。もう一度撮影してください。',
        );
      }
      return bytes;
    } on RegistrationPhotoException {
      rethrow;
    } on PlatformException {
      throw const RegistrationPhotoException(
        code: RegistrationPhotoErrorCode.captureFailed,
        userMessage: 'カメラを開けませんでした。端末の設定を確認して、もう一度お試しください。',
      );
    } catch (_) {
      throw const RegistrationPhotoException(
        code: RegistrationPhotoErrorCode.captureFailed,
        userMessage: '写真を取得できませんでした。もう一度お試しください。',
      );
    }
  }
}
