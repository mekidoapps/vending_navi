import 'dart:typed_data';

enum RegistrationPhotoStage {
  idle,
  capturing,
  normalizing,
  uploading,
  ready,
  failed,
}

final class RegistrationPhotoState {
  const RegistrationPhotoState({
    this.stage = RegistrationPhotoStage.idle,
    this.previewBytes,
    this.uploadId,
    this.failureMessage,
  });

  final RegistrationPhotoStage stage;
  final Uint8List? previewBytes;
  final String? uploadId;
  final String? failureMessage;

  bool get isBusy =>
      stage == RegistrationPhotoStage.capturing ||
      stage == RegistrationPhotoStage.normalizing ||
      stage == RegistrationPhotoStage.uploading;

  RegistrationPhotoState copyWith({
    RegistrationPhotoStage? stage,
    Uint8List? previewBytes,
    bool clearPreviewBytes = false,
    String? uploadId,
    bool clearUploadId = false,
    String? failureMessage,
    bool clearFailureMessage = false,
  }) {
    return RegistrationPhotoState(
      stage: stage ?? this.stage,
      previewBytes: clearPreviewBytes
          ? null
          : (previewBytes ?? this.previewBytes),
      uploadId: clearUploadId ? null : (uploadId ?? this.uploadId),
      failureMessage: clearFailureMessage
          ? null
          : (failureMessage ?? this.failureMessage),
    );
  }
}
