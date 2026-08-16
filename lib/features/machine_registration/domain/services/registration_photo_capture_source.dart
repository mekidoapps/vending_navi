import 'dart:typed_data';

abstract interface class RegistrationPhotoCaptureSource {
  Future<Uint8List?> capture();
}
