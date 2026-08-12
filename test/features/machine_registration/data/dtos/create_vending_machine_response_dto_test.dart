import 'package:flutter_test/flutter_test.dart';
import 'package:vending_app/features/machine_registration/data/dtos/create_vending_machine_response_dto.dart';

void main() {
  test('createVendingMachine responseをparseする', () {
    final dto = CreateVendingMachineResponseDto.fromMap(<String, Object?>{
      'machineId': 'machine_001',
      'created': true,
      'duplicateCandidates': <Object?>[],
    });

    expect(dto.machineId, 'machine_001');
    expect(dto.created, isTrue);
  });

  test('machineId欠損は拒否する', () {
    expect(
      () => CreateVendingMachineResponseDto.fromMap(<String, Object?>{
        'created': true,
      }),
      throwsFormatException,
    );
  });
}
