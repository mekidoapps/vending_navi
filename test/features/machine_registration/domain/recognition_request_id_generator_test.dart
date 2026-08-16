import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:vending_app/features/machine_registration/domain/services/recognition_request_id_generator.dart';

void main() {
  test('generates RFC 4122 UUID v4 recognition request ID', () {
    final generator = RecognitionRequestIdGenerator(random: Random(13));

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
}
