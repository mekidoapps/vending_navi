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
    } on PlatformException catch (error) {
      if (error.code == 'camera_access_denied' ||
          error.code == 'camera_access_denied_without_prompt') {
        throw const RegistrationPhotoException(
          code: RegistrationPhotoErrorCode.cameraPermissionDenied,
          userMessage: 'カメラの使用が許可されていません。端末の設定でカメラを許可したあと、もう一度撮影してください。',
        );
      }
      if (error.code == 'camera_access_restricted') {
        throw const RegistrationPhotoException(
          code: RegistrationPhotoErrorCode.cameraRestricted,
          userMessage: '端末の制限によりカメラを使用できません。スクリーンタイムや管理者の設定をご確認ください。',
        );
      }
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
