import 'dart:typed_data';

import '../models/normalized_registration_photo.dart';

abstract interface class RegistrationPhotoNormalizer {
  Future<NormalizedRegistrationPhoto> normalize(Uint8List sourceBytes);
}
