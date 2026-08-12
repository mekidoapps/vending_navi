import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:vending_app/features/machine_registration/domain/services/registration_request_id_generator.dart';

void main() {
  test('UUID v4形式のrequestIdを生成する', () {
    final generator = RegistrationRequestIdGenerator(random: Random(42));

    final value = generator.generate();

    expect(
      value,
      matches(
        RegExp(
          r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-'
          r'[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
        ),
      ),
    );
  });
}
