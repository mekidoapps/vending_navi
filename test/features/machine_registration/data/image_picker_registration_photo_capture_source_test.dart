import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mocktail/mocktail.dart';
import 'package:vending_app/features/machine_registration/data/sources/image_picker_registration_photo_capture_source.dart';
import 'package:vending_app/features/machine_registration/domain/services/registration_photo_exception.dart';

class _Picker extends Mock implements ImagePicker {}

void main() {
  for (final (platformCode, expected) in [
    ('camera_access_denied', RegistrationPhotoErrorCode.cameraPermissionDenied),
    (
      'camera_access_denied_without_prompt',
      RegistrationPhotoErrorCode.cameraPermissionDenied,
    ),
    ('camera_access_restricted', RegistrationPhotoErrorCode.cameraRestricted),
    ('camera_unavailable', RegistrationPhotoErrorCode.captureFailed),
  ]) {
    test(
      'classifies $platformCode without disclosing platform details',
      () async {
        final picker = _Picker();
        when(
          () => picker.pickImage(
            source: ImageSource.camera,
            preferredCameraDevice: CameraDevice.rear,
          ),
        ).thenThrow(
          PlatformException(
            code: platformCode,
            message: 'PRIVATE_PATH_OR_TOKEN',
          ),
        );
        final source = ImagePickerRegistrationPhotoCaptureSource(
          picker: picker,
        );
        await expectLater(
          source.capture(),
          throwsA(
            isA<RegistrationPhotoException>()
                .having((e) => e.code, 'code', expected)
                .having(
                  (e) => e.userMessage,
                  'redacted',
                  isNot(contains('PRIVATE_PATH_OR_TOKEN')),
                ),
          ),
        );
      },
    );
  }
  test('cancelling the camera is not a permissions failure', () async {
    final picker = _Picker();
    when(
      () => picker.pickImage(
        source: ImageSource.camera,
        preferredCameraDevice: CameraDevice.rear,
      ),
    ).thenAnswer((_) async => null);
    expect(
      await ImagePickerRegistrationPhotoCaptureSource(picker: picker).capture(),
      isNull,
    );
  });
}
