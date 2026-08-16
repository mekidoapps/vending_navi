import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;

import '../../domain/models/normalized_registration_photo.dart';
import '../../domain/services/registration_photo_exception.dart';
import '../../domain/services/registration_photo_normalizer.dart';

const int registrationPhotoMaxLongSide = 2048;
const int registrationPhotoJpegQuality = 85;
const int registrationPhotoMaxBytes = 5 * 1024 * 1024;
const int _registrationPhotoMinLongSideFallback = 768;

final class ImageRegistrationPhotoNormalizer
    implements RegistrationPhotoNormalizer {
  const ImageRegistrationPhotoNormalizer();

  @override
  Future<NormalizedRegistrationPhoto> normalize(Uint8List sourceBytes) async {
    final result = await compute(
      _normalizeRegistrationPhotoWorker,
      sourceBytes,
    );
    return NormalizedRegistrationPhoto(
      bytes: result.bytes,
      width: result.width,
      height: result.height,
    );
  }
}

NormalizedRegistrationPhoto normalizeRegistrationPhotoBytes(
  Uint8List sourceBytes,
) {
  if (sourceBytes.isEmpty) {
    throw const RegistrationPhotoException(
      code: RegistrationPhotoErrorCode.decodeFailed,
      userMessage: '写真を読み込めませんでした。もう一度撮影してください。',
    );
  }

  img.Image? decoded;
  try {
    decoded = img.decodeImage(sourceBytes);
  } catch (_) {
    throw const RegistrationPhotoException(
      code: RegistrationPhotoErrorCode.decodeFailed,
      userMessage: '写真を読み込めませんでした。もう一度撮影してください。',
    );
  }

  if (decoded == null || decoded.width <= 0 || decoded.height <= 0) {
    throw const RegistrationPhotoException(
      code: RegistrationPhotoErrorCode.decodeFailed,
      userMessage: '写真を読み込めませんでした。もう一度撮影してください。',
    );
  }

  // Apply EXIF orientation before removing metadata.
  var working = img.bakeOrientation(decoded);
  working = _resizeToMaxLongSide(working, registrationPhotoMaxLongSide);

  // Rebuild from RGB pixels so camera EXIF/GPS metadata is not carried into
  // the normalized JPEG uploaded for recognition.
  working = _withoutMetadata(working);

  var encoded = img.encodeJpg(working, quality: registrationPhotoJpegQuality);

  while (encoded.lengthInBytes > registrationPhotoMaxBytes) {
    final currentLongSide = math.max(working.width, working.height);
    if (currentLongSide <= _registrationPhotoMinLongSideFallback) {
      break;
    }

    final targetLongSide = math.max(
      _registrationPhotoMinLongSideFallback,
      (currentLongSide * 0.85).floor(),
    );
    working = _resizeToMaxLongSide(working, targetLongSide);
    encoded = img.encodeJpg(working, quality: registrationPhotoJpegQuality);
  }

  if (encoded.isEmpty || encoded.lengthInBytes > registrationPhotoMaxBytes) {
    throw const RegistrationPhotoException(
      code: RegistrationPhotoErrorCode.tooLarge,
      userMessage: '写真のサイズを小さくできませんでした。少し離れて、もう一度撮影してください。',
    );
  }

  return NormalizedRegistrationPhoto(
    bytes: encoded,
    width: working.width,
    height: working.height,
  );
}

NormalizedRegistrationPhoto _normalizeRegistrationPhotoWorker(
  Uint8List sourceBytes,
) {
  return normalizeRegistrationPhotoBytes(sourceBytes);
}

img.Image _resizeToMaxLongSide(img.Image source, int maxLongSide) {
  final longSide = math.max(source.width, source.height);
  if (longSide <= maxLongSide) {
    return source;
  }

  if (source.width >= source.height) {
    return img.copyResize(
      source,
      width: maxLongSide,
      interpolation: img.Interpolation.linear,
    );
  }

  return img.copyResize(
    source,
    height: maxLongSide,
    interpolation: img.Interpolation.linear,
  );
}

img.Image _withoutMetadata(img.Image source) {
  final rgb = source.getBytes(order: img.ChannelOrder.rgb);
  return img.Image.fromBytes(
    width: source.width,
    height: source.height,
    bytes: rgb.buffer,
    numChannels: 3,
    order: img.ChannelOrder.rgb,
  );
}
