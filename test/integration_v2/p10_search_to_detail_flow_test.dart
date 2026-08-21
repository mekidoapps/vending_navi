import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vending_app/app/router/app_router.dart';
import 'package:vending_app/app/router/entry_mode.dart';
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
import 'package:vending_app/features/product_master/data/fixtures/product_master_fixture.dart';
import 'package:vending_app/features/product_master/domain/value_objects/master_id.dart';
import 'package:vending_app/features/product_search/application/product_machine_search_controller.dart';
import 'package:vending_app/features/product_search/application/product_search_selection_controller.dart';
import 'package:vending_app/features/product_search/application/providers/machine_product_index_providers.dart';
import 'package:vending_app/features/product_search/domain/entities/machine_product_index_entry.dart';
import 'package:vending_app/features/product_search/domain/repositories/machine_product_index_repository.dart';
import 'package:vending_app/features/vending_machine/application/providers/vending_machine_detail_providers.dart';
import 'package:vending_app/features/vending_machine/domain/entities/vending_machine.dart';
import 'package:vending_app/features/vending_machine/domain/entities/vending_machine_enums.dart';
import 'package:vending_app/features/vending_machine/domain/value_objects/geo_coordinate.dart';
import 'package:vending_app/features/vending_machine/domain/value_objects/vending_machine_id.dart';

void main() {
  testWidgets(
    'P10-I01 商品検索から固定カードを経由して詳細へ検索状態を引き継ぐ',
    (WidgetTester tester) async {
      final machine = _machine();
      final boss = ProductMasterFixture.products.firstWhere(
        (product) => product.id.value == 'suntory_boss_black',
      );
      final viewport = MapViewportBounds(
        south: 35.6,
        west: 139.6,
        north: 35.8,
        east: 139.9,
      );

      final container = ProviderContainer(
        overrides: [
          locationServiceProvider.overrideWithValue(_FakeLocationService()),
          vendingMachineMapRepositoryProvider.overrideWithValue(
            _FakeMapRepository(machine),
          ),
          machineProductIndexRepositoryProvider.overrideWithValue(
            _FakeIndexRepository(machine.id, boss.id),
          ),
          manufacturerDisplayNameProvider(
            machine.manufacturerId,
          ).overrideWithValue(
            const AsyncValue<String>.data('サントリー'),
          ),
        ],
      );
      addTearDown(container.dispose);

      await container
          .read(vendingMachineMapControllerProvider.notifier)
          .loadViewport(viewport);

      container
          .read(productSearchSelectionControllerProvider.notifier)
          .select(boss);

      await container
          .read(productMachineSearchControllerProvider.notifier)
          .search(
            productId: boss.id,
            viewport: viewport,
          );

      container
          .read(vendingMachineMapControllerProvider.notifier)
          .selectMachine(machine.id);

      final router = createAppRouter(
        entryMode: AppEntryMode.v2,
        v2Builder: (_) => V2HomeMapScreen(
          autoLocate: false,
          mapBuilder: (_) => const ColoredBox(
            key: Key('p10FakeMap'),
            color: Colors.white,
          ),
        ),
        machineDetailBuilder: (_, machineId) {
          return Consumer(
            builder: (context, ref, _) {
              final selected = ref.watch(
                productSearchSelectionControllerProvider,
              );

              return Scaffold(
                key: const Key('p10MachineDetail'),
                body: Text(
                  'detail:${machineId.value}:'
                  '${selected?.id.value ?? 'none'}',
                ),
              );
            },
          );
        },
      );
      addTearDown(router.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp.router(
            routerConfig: router,
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(
        find.byKey(const Key('selectedMachineSearchMatch')),
        findsOneWidget,
      );

      expect(
        find.byKey(const Key('selectedMachineDetailButton')),
        findsOneWidget,
      );

      final matchLabel = find.byKey(
        const Key('selectedMachineSearchMatchLabel'),
      );

      expect(matchLabel, findsOneWidget);
      expect(
        tester.widget<Text>(matchLabel).data,
        'BOSS ブラック',
      );

      await tester.tap(
        find.byKey(const Key('selectedMachineDetailButton')),
      );
      await tester.pumpAndSettle();

      expect(
        find.byKey(const Key('p10MachineDetail')),
        findsOneWidget,
      );

      expect(
        find.text(
          'detail:machine_p10_search:suntory_boss_black',
        ),
        findsOneWidget,
      );

      expect(
        container
            .read(productSearchSelectionControllerProvider)
            ?.id
            .value,
        'suntory_boss_black',
      );
    },
  );
}

VendingMachine _machine() {
  return VendingMachine(
    id: VendingMachineId.parse('machine_p10_search'),
    schemaVersion: 2,
    name: 'P10検索対象自販機',
    manufacturerId: ManufacturerId.parse('suntory'),
    manufacturerStatus: ManufacturerStatus.confirmed,
    location: GeoCoordinate(
      latitude: 35.68,
      longitude: 139.76,
    ),
    geohash: 'xn76',
    installationType: InstallationType.outdoor,
    status: VendingMachineStatus.active,
    dataLevel: VendingMachineDataLevel.productsConfirmed,
    createdBy: 'test',
  );
}

final class _FakeMapRepository
    implements VendingMachineMapRepository {
  _FakeMapRepository(this.machine);

  final VendingMachine machine;

  @override
  Future<AppResult<List<VendingMachine>>> getMachinesInViewport(
    MapViewportBounds bounds,
  ) async {
    return AppResult<List<VendingMachine>>.success(
      <VendingMachine>[machine],
    );
  }
}

final class _FakeIndexRepository
    implements MachineProductIndexRepository {
  _FakeIndexRepository(
    this.machineId,
    this.expectedProductId,
  );

  final VendingMachineId machineId;
  final ProductId expectedProductId;

  @override
  Future<AppResult<List<MachineProductIndexEntry>>>
  findByProductInViewport({
    required ProductId productId,
    required MapViewportBounds viewport,
  }) async {
    if (productId != expectedProductId) {
      return const AppResult<List<MachineProductIndexEntry>>
          .success(<MachineProductIndexEntry>[]);
    }

    return AppResult<List<MachineProductIndexEntry>>.success(
      <MachineProductIndexEntry>[
        MachineProductIndexEntry(
          machineId: machineId,
          productId: expectedProductId,
          genres: const [],
          location: GeoCoordinate(
            latitude: 35.68,
            longitude: 139.76,
          ),
          geohash: 'xn76',
          evidenceType:
              ProductEvidenceType.manualConfirmed,
          availability: ProductAvailability.available,
          isActive: true,
          machineStatus: VendingMachineStatus.active,
          machineUpdatedAt: DateTime.utc(2026, 8, 21),
          updatedAt: DateTime.utc(2026, 8, 21),
        ),
      ],
    );
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
        capturedAt: DateTime.utc(2026, 8, 21),
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
