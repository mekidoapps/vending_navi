import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/services/registration_photo_exception.dart';
import 'providers/machine_registration_providers.dart';
import 'registration_photo_state.dart';

final registrationPhotoControllerProvider =
    NotifierProvider<RegistrationPhotoController, RegistrationPhotoState>(
      RegistrationPhotoController.new,
      name: 'registrationPhotoControllerProvider',
    );

final class RegistrationPhotoController
    extends Notifier<RegistrationPhotoState> {
  @override
  RegistrationPhotoState build() => const RegistrationPhotoState();

  Future<String?> captureNormalizeAndUpload() async {
    if (state.isBusy) {
      return null;
    }

    state = const RegistrationPhotoState(
      stage: RegistrationPhotoStage.capturing,
    );

    try {
      final sourceBytes = await ref
          .read(registrationPhotoCaptureSourceProvider)
          .capture();

      if (sourceBytes == null) {
        state = const RegistrationPhotoState();
        return null;
      }

      state = const RegistrationPhotoState(
        stage: RegistrationPhotoStage.normalizing,
      );

      final normalized = await ref
          .read(registrationPhotoNormalizerProvider)
          .normalize(sourceBytes);

      final uploadId = ref.read(photoUploadIdGeneratorProvider).generate();

      state = RegistrationPhotoState(
        stage: RegistrationPhotoStage.uploading,
        previewBytes: normalized.bytes,
      );

      final upload = await ref
          .read(temporaryRegistrationPhotoUploaderProvider)
          .upload(uploadId: uploadId, jpegBytes: normalized.bytes);

      state = RegistrationPhotoState(
        stage: RegistrationPhotoStage.ready,
        previewBytes: normalized.bytes,
        uploadId: upload.uploadId,
      );
      return upload.uploadId;
    } on RegistrationPhotoException catch (error) {
      state = RegistrationPhotoState(
        stage: RegistrationPhotoStage.failed,
        failureMessage: error.userMessage,
      );
      return null;
    } catch (_) {
      state = const RegistrationPhotoState(
        stage: RegistrationPhotoStage.failed,
        failureMessage: '写真を準備できませんでした。もう一度お試しください。',
      );
      return null;
    }
  }

  void reset() {
    if (state.isBusy) {
      return;
    }
    state = const RegistrationPhotoState();
  }
}
