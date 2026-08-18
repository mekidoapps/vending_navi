import 'package:flutter_test/flutter_test.dart';

import '../../../../lib/features/machine_update/application/machine_correction_draft_builder.dart';
import '../../../../lib/features/product_master/domain/value_objects/master_id.dart';
import '../../../../lib/features/vending_machine/domain/entities/vending_machine_enums.dart';
import '../../../../lib/features/vending_machine/domain/value_objects/geo_coordinate.dart';
import '../../../../lib/features/vending_machine/domain/value_objects/vending_machine_id.dart';

void main() {
  final machineId = VendingMachineId.tryParse('machine-001')!;
  final manufacturerId = ManufacturerId.tryParse('suntory')!;
  final location = GeoCoordinate(latitude: 35.1, longitude: 139.2);

  test('unchanged values produce an empty correction draft', () {
    final draft = MachineCorrectionDraftBuilder.build(
      machineId: machineId,
      currentName: '駅前の自販機',
      currentManufacturerId: manufacturerId,
      currentLocation: location,
      currentPlaceDescription: '駅東口',
      currentInstallationType: InstallationType.outdoor,
      proposedName: ' 駅前の自販機 ',
      proposedManufacturerId: manufacturerId,
      proposedLocation: GeoCoordinate(latitude: 35.1, longitude: 139.2),
      proposedPlaceDescription: ' 駅東口 ',
      proposedInstallationType: InstallationType.outdoor,
    );

    expect(draft.hasChanges, isFalse);
  });

  test('nullable fields distinguish clear from unchanged', () {
    final draft = MachineCorrectionDraftBuilder.build(
      machineId: machineId,
      currentName: '駅前の自販機',
      currentManufacturerId: manufacturerId,
      currentLocation: location,
      currentPlaceDescription: '駅東口',
      currentInstallationType: InstallationType.outdoor,
      proposedName: '駅前の自販機',
      proposedManufacturerId: null,
      proposedLocation: location,
      proposedPlaceDescription: '   ',
      proposedInstallationType: InstallationType.outdoor,
    );

    expect(draft.manufacturerId.isChanged, isTrue);
    expect(draft.manufacturerId.value, isNull);

    expect(draft.placeDescription.isChanged, isTrue);
    expect(draft.placeDescription.value, isNull);
  });

  test('only changed non-null fields are marked as changed', () {
    final nextLocation = GeoCoordinate(latitude: 35.2, longitude: 139.3);

    final draft = MachineCorrectionDraftBuilder.build(
      machineId: machineId,
      currentName: '駅前の自販機',
      currentManufacturerId: manufacturerId,
      currentLocation: location,
      currentPlaceDescription: null,
      currentInstallationType: InstallationType.outdoor,
      proposedName: '新しい名前',
      proposedManufacturerId: manufacturerId,
      proposedLocation: nextLocation,
      proposedPlaceDescription: null,
      proposedInstallationType: InstallationType.indoor,
    );

    expect(draft.name.isChanged, isTrue);
    expect(draft.name.value, '新しい名前');

    expect(draft.manufacturerId.isChanged, isFalse);

    expect(draft.location.isChanged, isTrue);
    expect(draft.location.value, nextLocation);

    expect(draft.placeDescription.isChanged, isFalse);

    expect(draft.installationType.isChanged, isTrue);
    expect(draft.installationType.value, InstallationType.indoor);
  });
}
