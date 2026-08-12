import 'package:flutter_test/flutter_test.dart';
import 'package:vending_app/core/result/app_result.dart';
import 'package:vending_app/features/home_map/domain/repositories/vending_machine_map_repository.dart';
import 'package:vending_app/features/home_map/domain/value_objects/map_viewport_bounds.dart';
import 'package:vending_app/features/machine_registration/domain/services/registration_duplicate_search_service.dart';
import 'package:vending_app/features/vending_machine/domain/entities/vending_machine.dart';
import 'package:vending_app/features/vending_machine/domain/entities/vending_machine_enums.dart';
import 'package:vending_app/features/vending_machine/domain/value_objects/geo_coordinate.dart';
import 'package:vending_app/features/vending_machine/domain/value_objects/vending_machine_id.dart';

void main() {
  test('30m以内だけを距離順で返す', () async {
    final center = GeoCoordinate(latitude: 35.68, longitude: 139.76);
    final repository = _FakeMapRepository(
      machines: <VendingMachine>[
        _machine(id: 'machine_far', latitude: 35.68040, longitude: 139.76),
        _machine(id: 'machine_near_2', latitude: 35.68015, longitude: 139.76),
        _machine(id: 'machine_near_1', latitude: 35.68005, longitude: 139.76),
      ],
    );

    final result = await RegistrationDuplicateSearchService(
      repository,
    ).search(center);

    expect(result.failureOrNull, isNull);
    expect(
      result.valueOrNull?.map((item) => item.machine.id.value).toList(),
      <String>['machine_near_1', 'machine_near_2'],
    );
  });

  test('距離計算は同一点で0m', () {
    final point = GeoCoordinate(latitude: 35.68, longitude: 139.76);

    expect(
      RegistrationDuplicateSearchService.distanceMeters(point, point),
      closeTo(0, 0.0001),
    );
  });
}

VendingMachine _machine({
  required String id,
  required double latitude,
  required double longitude,
}) {
  return VendingMachine(
    id: VendingMachineId.parse(id),
    schemaVersion: 2,
    name: id,
    manufacturerStatus: ManufacturerStatus.unknown,
    location: GeoCoordinate(latitude: latitude, longitude: longitude),
    geohash: 'xn76',
    installationType: InstallationType.unknown,
    status: VendingMachineStatus.active,
    dataLevel: VendingMachineDataLevel.locationOnly,
    createdBy: 'fixture_user',
  );
}

final class _FakeMapRepository implements VendingMachineMapRepository {
  _FakeMapRepository({required this.machines});

  final List<VendingMachine> machines;
  MapViewportBounds? lastBounds;

  @override
  Future<AppResult<List<VendingMachine>>> getMachinesInViewport(
    MapViewportBounds bounds,
  ) async {
    lastBounds = bounds;
    return AppResult<List<VendingMachine>>.success(machines);
  }
}
