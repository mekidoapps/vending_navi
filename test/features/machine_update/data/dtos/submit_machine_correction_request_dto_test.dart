import 'package:flutter_test/flutter_test.dart';

import '../../../../../lib/features/machine_update/data/dtos/submit_machine_correction_request_dto.dart';
import '../../../../../lib/features/machine_update/domain/models/machine_correction_draft.dart';
import '../../../../../lib/features/machine_update/domain/models/machine_correction_field.dart';
import '../../../../../lib/features/product_master/domain/value_objects/master_id.dart';
import '../../../../../lib/features/vending_machine/domain/entities/vending_machine_enums.dart';
import '../../../../../lib/features/vending_machine/domain/value_objects/geo_coordinate.dart';
import '../../../../../lib/features/vending_machine/domain/value_objects/vending_machine_id.dart';

void main() {
  test('serializes only changed correction fields', () {
    final dto = SubmitMachineCorrectionRequestDto(
      requestId: '123e4567-e89b-42d3-a456-426614174000',
      draft: MachineCorrectionDraft(
        machineId: VendingMachineId.tryParse('machine-001')!,
        name: const MachineCorrectionField<String>.changed(' 新しい名前 '),
        installationType:
            const MachineCorrectionField<InstallationType>.changed(
              InstallationType.indoor,
            ),
        message: ' 補足 ',
      ),
    );

    expect(dto.toMap(), <String, Object?>{
      'requestId': '123e4567-e89b-42d3-a456-426614174000',
      'machineId': 'machine-001',
      'changes': <String, Object?>{
        'name': '新しい名前',
        'installationType': 'indoor',
      },
      'message': '補足',
    });
  });

  test('changed null explicitly clears nullable fields', () {
    final dto = SubmitMachineCorrectionRequestDto(
      requestId: '123e4567-e89b-42d3-a456-426614174000',
      draft: MachineCorrectionDraft(
        machineId: VendingMachineId.tryParse('machine-001')!,
        manufacturerId: const MachineCorrectionField<ManufacturerId>.changed(
          null,
        ),
        placeDescription: const MachineCorrectionField<String>.changed(null),
      ),
    );

    final map = dto.toMap();
    final changes = map['changes']! as Map<String, Object?>;

    expect(changes.containsKey('manufacturerId'), isTrue);
    expect(changes['manufacturerId'], isNull);
    expect(changes.containsKey('placeDescription'), isTrue);
    expect(changes['placeDescription'], isNull);
  });

  test('serializes manufacturer and location values', () {
    final dto = SubmitMachineCorrectionRequestDto(
      requestId: '123e4567-e89b-42d3-a456-426614174000',
      draft: MachineCorrectionDraft(
        machineId: VendingMachineId.tryParse('machine-001')!,
        manufacturerId: MachineCorrectionField<ManufacturerId>.changed(
          ManufacturerId.tryParse('suntory')!,
        ),
        location: MachineCorrectionField<GeoCoordinate>.changed(
          GeoCoordinate(latitude: 35.1, longitude: 139.2),
        ),
      ),
    );

    final changes = dto.toMap()['changes']! as Map<String, Object?>;

    expect(changes['manufacturerId'], 'suntory');
    expect(changes['location'], <String, Object?>{
      'latitude': 35.1,
      'longitude': 139.2,
    });
  });

  test('unchanged draft is rejected before callable serialization', () {
    final dto = SubmitMachineCorrectionRequestDto(
      requestId: '123e4567-e89b-42d3-a456-426614174000',
      draft: MachineCorrectionDraft(
        machineId: VendingMachineId.tryParse('machine-001')!,
      ),
    );

    expect(dto.toMap, throwsFormatException);
  });
}
