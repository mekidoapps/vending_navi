import 'package:flutter_test/flutter_test.dart';

import '../../../../../lib/features/machine_update/data/dtos/update_vending_machine_products_request_dto.dart';
import '../../../../../lib/features/machine_update/domain/models/machine_product_update_draft.dart';
import '../../../../../lib/features/machine_update/domain/models/machine_product_update_operation.dart';
import '../../../../../lib/features/vending_machine/domain/value_objects/vending_machine_id.dart';

void main() {
  test('serializes all four backend operation contracts', () {
    final machineId = VendingMachineId.tryParse('machine-001');
    expect(machineId, isNotNull);

    final dto = UpdateVendingMachineProductsRequestDto(
      requestId: '123e4567-e89b-42d3-a456-426614174000',
      draft: MachineProductUpdateDraft(
        machineId: machineId!,
        operations: const <MachineProductUpdateOperation>[
          MachineProductUpdateOperation.addConfirmed(
            productId: 'asahi_calpis',
            source: MachineProductUpdateSource.manual,
          ),
          MachineProductUpdateOperation.deactivate(
            productId: 'asahi_wonda_black',
          ),
          MachineProductUpdateOperation.setSoldOut(
            productId: 'suntory_boss_black',
            soldOut: true,
          ),
          MachineProductUpdateOperation.confirmInferred(
            productId: 'coca_cola_aquarius',
          ),
        ],
      ),
    );

    expect(dto.toMap(), <String, Object?>{
      'requestId': '123e4567-e89b-42d3-a456-426614174000',
      'machineId': 'machine-001',
      'operations': <Map<String, Object?>>[
        <String, Object?>{
          'type': 'addConfirmed',
          'productId': 'asahi_calpis',
          'source': 'manual',
        },
        <String, Object?>{
          'type': 'deactivate',
          'productId': 'asahi_wonda_black',
        },
        <String, Object?>{
          'type': 'setSoldOut',
          'productId': 'suntory_boss_black',
          'soldOut': true,
        },
        <String, Object?>{
          'type': 'confirmInferred',
          'productId': 'coca_cola_aquarius',
        },
      ],
      'temporaryPhotoUploadId': null,
    });
  });

  test('serializes photo source and upload ID', () {
    final machineId = VendingMachineId.tryParse('machine-001')!;

    final map = UpdateVendingMachineProductsRequestDto(
      requestId: '123e4567-e89b-42d3-a456-426614174000',
      draft: MachineProductUpdateDraft(
        machineId: machineId,
        temporaryPhotoUploadId: 'f47ac10b-58cc-4372-a567-0e02b2c3d479',
        operations: const <MachineProductUpdateOperation>[
          MachineProductUpdateOperation.addConfirmed(
            productId: 'asahi_calpis',
            source: MachineProductUpdateSource.photo,
          ),
        ],
      ),
    ).toMap();

    final operations = map['operations']! as List<Object?>;
    final operation = operations.single as Map<String, Object?>;

    expect(operation['source'], 'photo');
    expect(
      map['temporaryPhotoUploadId'],
      'f47ac10b-58cc-4372-a567-0e02b2c3d479',
    );
  });
}
