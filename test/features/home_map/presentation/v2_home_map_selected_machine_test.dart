import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vending_app/core/result/app_result.dart';
import 'package:vending_app/features/home_map/application/providers/vending_machine_map_providers.dart';
import 'package:vending_app/features/home_map/application/vending_machine_map_controller.dart';
import 'package:vending_app/features/home_map/domain/repositories/vending_machine_map_repository.dart';
import 'package:vending_app/features/home_map/domain/value_objects/map_viewport_bounds.dart';
import 'package:vending_app/features/home_map/presentation/v2_home_map_screen.dart';
import 'package:vending_app/features/location/application/providers/location_service_provider.dart';
import 'package:vending_app/features/location/domain/entities/app_location_permission.dart';
import 'package:vending_app/features/location/domain/entities/current_location.dart';
import 'package:vending_app/features/location/domain/services/location_service.dart';
import 'package:vending_app/features/product_master/domain/value_objects/master_id.dart';
import 'package:vending_app/features/vending_machine/application/providers/vending_machine_detail_providers.dart';
import 'package:vending_app/features/vending_machine/domain/entities/vending_machine.dart';
import 'package:vending_app/features/vending_machine/domain/entities/vending_machine_enums.dart';
import 'package:vending_app/features/vending_machine/domain/entities/vending_machine_product.dart';
import 'package:vending_app/features/vending_machine/domain/value_objects/geo_coordinate.dart';
import 'package:vending_app/features/vending_machine/domain/value_objects/vending_machine_id.dart';

void main() {
  testWidgets('選択中自販機を固定カードで表示し詳細callbackを呼ぶ', (WidgetTester tester) async {
    final machine = _machine();
    final container = ProviderContainer(
      overrides: [
        locationServiceProvider.overrideWithValue(_FakeLocationService()),
        vendingMachineMapRepositoryProvider.overrideWithValue(
          _FakeMapRepository(machine),
        ),
        manufacturerDisplayNameProvider(
          machine.manufacturerId,
        ).overrideWithValue(const AsyncValue<String>.data('サントリー')),
      ],
    );
    addTearDown(container.dispose);

    final mapController = container.read(
      vendingMachineMapControllerProvider.notifier,
    );

    await mapController.loadViewport(
      MapViewportBounds(south: 35.6, west: 139.6, north: 35.8, east: 139.9),
    );
    mapController.selectMachine(machine.id);

    VendingMachine? opened;

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          home: V2HomeMapScreen(
            autoLocate: false,
            mapBuilder: (_) =>
                const ColoredBox(key: Key('fakeMap'), color: Colors.white),
            onMachineDetailPressed: (value) => opened = value,
          ),
        ),
      ),
    );

    await tester.pump();
    await tester.pump();

    expect(find.text('駅前の自販機'), findsOneWidget);
    expect(find.text('サントリー'), findsOneWidget);
    expect(find.text('確認済み'), findsOneWidget);
    expect(find.text('詳細を見る'), findsOneWidget);

    await tester.tap(find.byKey(const Key('selectedMachineDetailButton')));
    await tester.pump();

    expect(opened?.id, machine.id);
  });
}

VendingMachine _machine() {
  return VendingMachine(
    id: VendingMachineId.parse('machine_selected'),
    schemaVersion: 2,
    name: '駅前の自販機',
    manufacturerId: ManufacturerId.parse('suntory'),
    manufacturerStatus: ManufacturerStatus.confirmed,
    location: GeoCoordinate(latitude: 35.68, longitude: 139.76),
    geohash: 'xn76',
    placeDescription: '駅東口',
    installationType: InstallationType.outdoor,
    status: VendingMachineStatus.active,
    dataLevel: VendingMachineDataLevel.productsConfirmed,
    createdBy: 'test',
    products: <VendingMachineProduct>[
      VendingMachineProduct(
        productId: ProductId.parse('suntory_boss_black'),
        evidenceType: ProductEvidenceType.manualConfirmed,
        availability: ProductAvailability.available,
      ),
    ],
  );
}

final class _FakeMapRepository implements VendingMachineMapRepository {
  _FakeMapRepository(this.machine);

  final VendingMachine machine;

  @override
  Future<AppResult<List<VendingMachine>>> getMachinesInViewport(
    MapViewportBounds bounds,
  ) async {
    return AppResult<List<VendingMachine>>.success(<VendingMachine>[machine]);
  }
}

final class _FakeLocationService implements LocationService {
  @override
  Future<AppLocationPermission> checkPermission() async {
    return AppLocationPermission.whileInUse;
  }

  @override
  Future<AppResult<CurrentLocation>> getCurrentLocation() async {
    return AppResult<CurrentLocation>.success(
      CurrentLocation(
        latitude: 35.68,
        longitude: 139.76,
        accuracyMeters: 10,
        capturedAt: DateTime.utc(2026, 8, 7),
      ),
    );
  }

  @override
  Future<bool> isLocationServiceEnabled() async => true;

  @override
  Future<bool> openAppSettings() async => true;

  @override
  Future<bool> openLocationSettings() async => true;

  @override
  Future<AppLocationPermission> requestPermission() async {
    return AppLocationPermission.whileInUse;
  }
}
