import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vending_app/core/result/app_result.dart';
import 'package:vending_app/features/machine_registration/application/machine_registration_controller.dart';
import 'package:vending_app/features/machine_registration/application/machine_registration_state.dart';
import 'package:vending_app/features/machine_registration/application/providers/machine_registration_providers.dart';
import 'package:vending_app/features/machine_registration/domain/entities/machine_registration_draft.dart';
import 'package:vending_app/features/machine_registration/domain/entities/machine_registration_result.dart';
import 'package:vending_app/features/machine_registration/domain/repositories/machine_registration_repository.dart';
import 'package:vending_app/features/machine_registration/domain/services/registration_request_id_generator.dart';
import 'package:vending_app/features/product_master/domain/value_objects/master_id.dart';
import 'package:vending_app/features/vending_machine/domain/value_objects/geo_coordinate.dart';
import 'package:vending_app/features/vending_machine/domain/value_objects/vending_machine_id.dart';

void main() {
  test('位置→方法→メーカー→submitでdraftを保持して完了する', () async {
    final repository = _FakeRepository();
    final container = ProviderContainer(
      overrides: [
        machineRegistrationRepositoryProvider.overrideWithValue(repository),
        registrationRequestIdGeneratorProvider.overrideWithValue(
          RegistrationRequestIdGenerator(random: Random(7)),
        ),
      ],
    );
    addTearDown(container.dispose);

    final controller = container.read(
      machineRegistrationControllerProvider.notifier,
    );

    final initialRequestId = container
        .read(machineRegistrationControllerProvider)
        .draft
        .requestId;

    controller.setLocation(GeoCoordinate(latitude: 35.68, longitude: 139.76));
    expect(controller.continueFromPosition(), isTrue);
    expect(
      container.read(machineRegistrationControllerProvider).step,
      MachineRegistrationStep.duplicateCheck,
    );

    controller.continueAfterDuplicateCheck();
    controller.chooseManufacturerMethod();
    controller.selectManufacturer(ManufacturerId.parse('coca_cola'));

    final success = await controller.submit();

    final state = container.read(machineRegistrationControllerProvider);
    expect(success, isTrue);
    expect(state.step, MachineRegistrationStep.completed);
    expect(state.createdMachineId?.value, 'machine_created');
    expect(repository.lastDraft?.requestId, initialRequestId);
    expect(repository.lastDraft?.manufacturerId?.value, 'coca_cola');
  });

  test('locationOnlyはメーカーなしでsubmit可能', () async {
    final repository = _FakeRepository();
    final container = ProviderContainer(
      overrides: [
        machineRegistrationRepositoryProvider.overrideWithValue(repository),
        registrationRequestIdGeneratorProvider.overrideWithValue(
          RegistrationRequestIdGenerator(random: Random(11)),
        ),
      ],
    );
    addTearDown(container.dispose);

    final controller = container.read(
      machineRegistrationControllerProvider.notifier,
    );

    controller.setLocation(GeoCoordinate(latitude: 35.68, longitude: 139.76));
    controller.continueFromPosition();
    controller.continueAfterDuplicateCheck();
    controller.chooseLocationOnly();

    expect(await controller.submit(), isTrue);
    expect(repository.lastDraft?.manufacturerId, isNull);
    expect(repository.lastDraft?.confirmedProductIds, isEmpty);
  });

  test('resetすると新しいrequestIdになる', () {
    final container = ProviderContainer(
      overrides: [
        machineRegistrationRepositoryProvider.overrideWithValue(
          _FakeRepository(),
        ),
        registrationRequestIdGeneratorProvider.overrideWithValue(
          RegistrationRequestIdGenerator(random: Random(19)),
        ),
      ],
    );
    addTearDown(container.dispose);

    final controller = container.read(
      machineRegistrationControllerProvider.notifier,
    );
    final before = container
        .read(machineRegistrationControllerProvider)
        .draft
        .requestId;

    controller.reset();

    final after = container
        .read(machineRegistrationControllerProvider)
        .draft
        .requestId;

    expect(after, isNot(before));
    expect(
      container.read(machineRegistrationControllerProvider).step,
      MachineRegistrationStep.position,
    );
  });
}

final class _FakeRepository implements MachineRegistrationRepository {
  MachineRegistrationDraft? lastDraft;

  @override
  Future<AppResult<MachineRegistrationResult>> createVendingMachine(
    MachineRegistrationDraft draft,
  ) async {
    lastDraft = draft;
    return AppResult<MachineRegistrationResult>.success(
      MachineRegistrationResult(
        machineId: VendingMachineId.parse('machine_created'),
        created: true,
      ),
    );
  }
}
