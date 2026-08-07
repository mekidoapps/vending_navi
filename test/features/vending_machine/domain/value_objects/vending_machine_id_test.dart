import 'package:flutter_test/flutter_test.dart';
import 'package:vending_app/features/vending_machine/domain/value_objects/vending_machine_id.dart';

void main() {
  group('VendingMachineId', () {
    test('Firestoreの通常ドキュメントIDを保持できる', () {
      final id = VendingMachineId.parse('AbC123xyz456');

      expect(id.value, 'AbC123xyz456');
    });

    test('空文字とスラッシュを含む値を拒否する', () {
      expect(VendingMachineId.tryParse(''), isNull);
      expect(VendingMachineId.tryParse('machines/123'), isNull);
    });
  });
}
