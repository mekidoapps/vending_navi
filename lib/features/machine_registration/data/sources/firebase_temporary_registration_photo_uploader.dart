import 'dart:typed_data';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';

import '../../domain/models/temporary_registration_photo_upload.dart';
import '../../domain/services/registration_photo_exception.dart';
import '../../domain/services/temporary_registration_photo_uploader.dart';

final class FirebaseTemporaryRegistrationPhotoUploader
    implements TemporaryRegistrationPhotoUploader {
  FirebaseTemporaryRegistrationPhotoUploader({
    required FirebaseAuth auth,
    required FirebaseStorage storage,
  }) : _auth = auth,
       _storage = storage;

  final FirebaseAuth _auth;
  final FirebaseStorage _storage;

  @override
  Future<TemporaryRegistrationPhotoUpload> upload({
    required String uploadId,
    required Uint8List jpegBytes,
  }) async {
    final uid = _auth.currentUser?.uid.trim() ?? '';
    if (uid.isEmpty) {
      throw const RegistrationPhotoException(
        code: RegistrationPhotoErrorCode.authenticationRequired,
        userMessage: '写真から登録するにはログインが必要です。',
      );
    }

    final normalizedUploadId = uploadId.trim();
    if (normalizedUploadId.isEmpty || jpegBytes.isEmpty) {
      throw const RegistrationPhotoException(
        code: RegistrationPhotoErrorCode.uploadFailed,
        userMessage: '写真をアップロードできませんでした。もう一度お試しください。',
      );
    }

    final objectPath = 'machine_uploads/$uid/$normalizedUploadId/original.jpg';

    try {
      await _storage
          .ref(objectPath)
          .putData(jpegBytes, SettableMetadata(contentType: 'image/jpeg'));
      return TemporaryRegistrationPhotoUpload(
        uploadId: normalizedUploadId,
        objectPath: objectPath,
      );
    } on FirebaseException catch (error) {
      if (error.code == 'unauthorized') {
        throw const RegistrationPhotoException(
          code: RegistrationPhotoErrorCode.uploadFailed,
          userMessage: '写真をアップロードする権限を確認できませんでした。ログイン状態を確認してください。',
        );
      }
      throw const RegistrationPhotoException(
        code: RegistrationPhotoErrorCode.uploadFailed,
        userMessage: '写真をアップロードできませんでした。通信状態を確認して、もう一度お試しください。',
      );
    } catch (_) {
      throw const RegistrationPhotoException(
        code: RegistrationPhotoErrorCode.uploadFailed,
        userMessage: '写真をアップロードできませんでした。もう一度お試しください。',
      );
    }
  }
}
