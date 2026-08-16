import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:vending_app/features/machine_registration/domain/services/photo_upload_id_generator.dart';

void main() {
  test('generates RFC 4122 UUID v4 format', () {
    final generator = PhotoUploadIdGenerator(random: Random(7));

    final value = generator.generate();

    expect(
      value,
      matches(
        RegExp(
          r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
        ),
      ),
    );
  });

  test('generates different upload IDs on consecutive calls', () {
    final generator = PhotoUploadIdGenerator(random: Random(11));

    expect(generator.generate(), isNot(generator.generate()));
  });
}
