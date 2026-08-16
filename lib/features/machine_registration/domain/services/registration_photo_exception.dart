enum RegistrationPhotoErrorCode {
  captureFailed,
  decodeFailed,
  tooLarge,
  authenticationRequired,
  uploadFailed,
}

final class RegistrationPhotoException implements Exception {
  const RegistrationPhotoException({
    required this.code,
    required this.userMessage,
  });

  final RegistrationPhotoErrorCode code;
  final String userMessage;

  @override
  String toString() => 'RegistrationPhotoException(${code.name})';
}
