import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vending_app/core/result/app_result.dart';
import 'package:vending_app/features/home_map/application/providers/vending_machine_map_providers.dart';
import 'package:vending_app/features/home_map/domain/repositories/vending_machine_map_repository.dart';
import 'package:vending_app/features/home_map/domain/value_objects/map_viewport_bounds.dart';
import 'package:vending_app/features/machine_registration/application/machine_registration_controller.dart';
import 'package:vending_app/features/machine_registration/application/machine_registration_state.dart';
import 'package:vending_app/features/machine_registration/application/registration_duplicate_candidates_controller.dart';
import 'package:vending_app/features/vending_machine/domain/entities/vending_machine.dart';
import 'package:vending_app/features/vending_machine/domain/value_objects/geo_coordinate.dart';

void main() {
  test('draft位置がない場合はvalidation failure', () async {
    final container = ProviderContainer(
      overrides: [
        vendingMachineMapRepositoryProvider.overrideWithValue(
          _FakeMapRepository(),
        ),
      ],
    );
    addTearDown(container.dispose);

    await container
        .read(registrationDuplicateCandidatesControllerProvider.notifier)
        .load();

    final state = container.read(
      registrationDuplicateCandidatesControllerProvider,
    );
    expect(state.hasLoaded, isTrue);
    expect(state.failure?.code, 'validation.invalid');
  });

  test('候補確認後に登録method stepへ進む', () async {
    final container = ProviderContainer(
      overrides: [
        vendingMachineMapRepositoryProvider.overrideWithValue(
          _FakeMapRepository(),
        ),
      ],
    );
    addTearDown(container.dispose);

    final registration = container.read(
      machineRegistrationControllerProvider.notifier,
    );
    registration.setLocation(GeoCoordinate(latitude: 35.68, longitude: 139.76));
    expect(registration.continueFromPosition(), isTrue);

    await container
        .read(registrationDuplicateCandidatesControllerProvider.notifier)
        .load();

    container
        .read(registrationDuplicateCandidatesControllerProvider.notifier)
        .continueWithNewMachine();

    expect(
      container.read(machineRegistrationControllerProvider).step,
      MachineRegistrationStep.method,
    );
  });
}

final class _FakeMapRepository implements VendingMachineMapRepository {
  @override
  Future<AppResult<List<VendingMachine>>> getMachinesInViewport(
    MapViewportBounds bounds,
  ) async {
    return const AppResult<List<VendingMachine>>.success(<VendingMachine>[]);
  }
}
