import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vending_app/core/errors/app_failure.dart';
import 'package:vending_app/core/result/app_result.dart';
import 'package:vending_app/features/home_map/application/providers/vending_machine_map_providers.dart';
import 'package:vending_app/features/home_map/application/vending_machine_map_controller.dart';
import 'package:vending_app/features/home_map/domain/repositories/vending_machine_map_repository.dart';
import 'package:vending_app/features/home_map/domain/value_objects/map_viewport_bounds.dart';
import 'package:vending_app/features/vending_machine/domain/entities/vending_machine.dart';
import 'package:vending_app/features/vending_machine/domain/entities/vending_machine_enums.dart';
import 'package:vending_app/features/vending_machine/domain/value_objects/geo_coordinate.dart';
import 'package:vending_app/features/vending_machine/domain/value_objects/vending_machine_id.dart';

void main() {
  test('viewport読込後に自販機を保持し選択できる', () async {
    final machine = _machine('machine_1');
    final repository = _FakeMapRepository(
      AppResult<List<VendingMachine>>.success(<VendingMachine>[machine]),
    );
    final container = ProviderContainer(
      overrides: [
        vendingMachineMapRepositoryProvider.overrideWithValue(repository),
      ],
    );
    addTearDown(container.dispose);

    final controller = container.read(
      vendingMachineMapControllerProvider.notifier,
    );

    await controller.loadViewport(_bounds());
    controller.selectMachine(machine.id);

    final state = container.read(vendingMachineMapControllerProvider);
    expect(state.hasLoaded, isTrue);
    expect(state.machines, hasLength(1));
    expect(state.selectedMachine?.id, machine.id);
  });

  test('選択中自販機がviewport外へ消えたら選択を解除する', () async {
    final machine = _machine('machine_1');
    final repository = _SequenceMapRepository(<AppResult<List<VendingMachine>>>[
      AppResult<List<VendingMachine>>.success(<VendingMachine>[machine]),
      const AppResult<List<VendingMachine>>.success(<VendingMachine>[]),
    ]);
    final container = ProviderContainer(
      overrides: [
        vendingMachineMapRepositoryProvider.overrideWithValue(repository),
      ],
    );
    addTearDown(container.dispose);

    final controller = container.read(
      vendingMachineMapControllerProvider.notifier,
    );

    await controller.loadViewport(_bounds());
    controller.selectMachine(machine.id);

    await controller.loadViewport(
      MapViewportBounds(south: 34, west: 135, north: 35, east: 136),
    );

    final state = container.read(vendingMachineMapControllerProvider);
    expect(state.selectedMachineId, isNull);
    expect(state.isEmpty, isTrue);
  });

  test('Repository Failureを保持してretry可能にする', () async {
    final repository = _FakeMapRepository(
      const AppResult<List<VendingMachine>>.failure(NetworkFailure()),
    );
    final container = ProviderContainer(
      overrides: [
        vendingMachineMapRepositoryProvider.overrideWithValue(repository),
      ],
    );
    addTearDown(container.dispose);

    await container
        .read(vendingMachineMapControllerProvider.notifier)
        .loadViewport(_bounds());

    final state = container.read(vendingMachineMapControllerProvider);
    expect(state.failure, isA<NetworkFailure>());
    expect(state.hasLoaded, isTrue);
    expect(state.isLoading, isFalse);
  });
}

MapViewportBounds _bounds() {
  return MapViewportBounds(south: 35.6, west: 139.6, north: 35.8, east: 139.9);
}

VendingMachine _machine(String id) {
  return VendingMachine(
    id: VendingMachineId.parse(id),
    schemaVersion: 2,
    name: '自販機',
    manufacturerStatus: ManufacturerStatus.unknown,
    location: GeoCoordinate(latitude: 35.68, longitude: 139.76),
    geohash: 'xn76',
    installationType: InstallationType.outdoor,
    status: VendingMachineStatus.active,
    dataLevel: VendingMachineDataLevel.locationOnly,
    createdBy: 'test',
  );
}

final class _FakeMapRepository implements VendingMachineMapRepository {
  _FakeMapRepository(this.result);

  final AppResult<List<VendingMachine>> result;

  @override
  Future<AppResult<List<VendingMachine>>> getMachinesInViewport(
    MapViewportBounds bounds,
  ) async {
    return result;
  }
}

final class _SequenceMapRepository implements VendingMachineMapRepository {
  _SequenceMapRepository(this.results);

  final List<AppResult<List<VendingMachine>>> results;
  var index = 0;

  @override
  Future<AppResult<List<VendingMachine>>> getMachinesInViewport(
    MapViewportBounds bounds,
  ) async {
    final current = results[index];
    if (index < results.length - 1) {
      index += 1;
    }
    return current;
  }
}
