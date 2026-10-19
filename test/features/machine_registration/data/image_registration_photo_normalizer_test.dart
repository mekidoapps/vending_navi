import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:vending_app/features/machine_registration/data/services/image_registration_photo_normalizer.dart';
import 'package:vending_app/features/machine_registration/domain/services/registration_photo_exception.dart';

void main() {
  test('camera EXIF and GPS are removed after orientation is applied', () {
    final source = img.Image(width: 60, height: 40);
    source.exif.imageIfd.orientation = 6;
    source.exif.imageIfd[0x010f] = img.IfdValueAscii('synthetic-camera-model');
    source.exif.gpsIfd[1] = img.IfdValueAscii('N');
    source.exif.gpsIfd[3] = img.IfdValueAscii('E');
    final input = img.encodeJpg(source);
    final before = img.decodeJpg(input)!;
    // The JPEG decoder can bake orientation before returning the image.
    expect(before.width, 40);
    expect(before.height, 60);
    expect(before.exif.imageIfd[0x010f], isNotNull);
    expect(before.exif.gpsIfd.isEmpty, isFalse);

    final normalized = normalizeRegistrationPhotoBytes(input);
    final after = img.decodeJpg(normalized.bytes)!;
    expect(normalized.width, 40);
    expect(normalized.height, 60);
    expect(after.exif.gpsIfd.isEmpty, isTrue);
    expect(after.exif.imageIfd[0x010f], isNull);
    expect(after.exif.imageIfd.orientation, isNull);
    expect(after.exif.exifIfd.isEmpty, isTrue);
  });

  test('normalizes to JPEG quality pipeline with max long side 2048', () {
    final source = img.Image(width: 3000, height: 1500);
    source.clear(img.ColorRgb8(24, 120, 210));
    final sourceBytes = img.encodePng(source);

    final normalized = normalizeRegistrationPhotoBytes(sourceBytes);

    expect(normalized.width, 2048);
    expect(normalized.height, 1024);
    expect(normalized.sizeBytes, lessThanOrEqualTo(registrationPhotoMaxBytes));
    expect(normalized.bytes[0], 0xff);
    expect(normalized.bytes[1], 0xd8);
    expect(normalized.bytes[normalized.bytes.length - 2], 0xff);
    expect(normalized.bytes[normalized.bytes.length - 1], 0xd9);

    final decoded = img.decodeJpg(normalized.bytes);
    expect(decoded, isNotNull);
    expect(decoded!.width, 2048);
    expect(decoded.height, 1024);
  });

  test('does not upscale a small image', () {
    final source = img.Image(width: 640, height: 480);
    source.clear(img.ColorRgb8(90, 60, 30));

    final normalized = normalizeRegistrationPhotoBytes(img.encodePng(source));

    expect(normalized.width, 640);
    expect(normalized.height, 480);
  });

  test('rejects undecodable bytes safely', () {
    expect(
      () => normalizeRegistrationPhotoBytes(
        Uint8List.fromList(<int>[1, 2, 3, 4]),
      ),
      throwsA(
        isA<RegistrationPhotoException>().having(
          (error) => error.code,
          'code',
          RegistrationPhotoErrorCode.decodeFailed,
        ),
      ),
    );
  });
}
