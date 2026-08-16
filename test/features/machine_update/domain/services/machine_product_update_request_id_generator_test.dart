import 'package:flutter_test/flutter_test.dart';

import '../../../../../lib/features/machine_update/domain/services/machine_product_update_request_id_generator.dart';

void main() {
  test('generates RFC 4122 UUID v4 values', () {
    final generator = SecureMachineProductUpdateRequestIdGenerator();

    final first = generator.next();
    final second = generator.next();

    final pattern = RegExp(
      r'^[0-9a-f]{8}-'
      r'[0-9a-f]{4}-'
      r'4[0-9a-f]{3}-'
      r'[89ab][0-9a-f]{3}-'
      r'[0-9a-f]{12}$',
    );

    expect(first, matches(pattern));
    expect(second, matches(pattern));
    expect(second, isNot(first));
  });
}
