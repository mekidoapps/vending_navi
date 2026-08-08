import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vending_app/core/result/app_result.dart';
import 'package:vending_app/features/home_map/presentation/v2_home_map_screen.dart';
import 'package:vending_app/features/location/application/providers/location_service_provider.dart';
import 'package:vending_app/features/location/domain/entities/app_location_permission.dart';
import 'package:vending_app/features/location/domain/entities/current_location.dart';
import 'package:vending_app/features/location/domain/services/location_service.dart';
import 'package:vending_app/features/product_master/data/fixtures/product_master_fixture.dart';
import 'package:vending_app/features/product_search/application/product_machine_search_controller.dart';
import 'package:vending_app/features/product_search/application/product_search_selection_controller.dart';
import 'package:vending_app/features/product_search/application/providers/machine_product_index_providers.dart';
import 'package:vending_app/features/product_search/domain/entities/machine_product_index_entry.dart';
import 'package:vending_app/features/product_search/domain/repositories/machine_product_index_repository.dart';
import 'package:vending_app/features/home_map/domain/value_objects/map_viewport_bounds.dart';
import 'package:vending_app/features/product_master/domain/value_objects/master_id.dart';

void main() {
  testWidgets('商品検索0件時に範囲内0件案内を表示する', (WidgetTester tester) async {
    final boss = ProductMasterFixture.products.firstWhere(
      (product) => product.id.value == 'suntory_boss_black',
    );

    final container = ProviderContainer(
      overrides: [
        locationServiceProvider.overrideWithValue(_FakeLocationService()),
        machineProductIndexRepositoryProvider.overrideWithValue(
          _EmptyIndexRepository(),
        ),
      ],
    );
    addTearDown(container.dispose);

    container
        .read(productSearchSelectionControllerProvider.notifier)
        .select(boss);

    await container
        .read(productMachineSearchControllerProvider.notifier)
        .search(
          productId: boss.id,
          viewport: MapViewportBounds(
            south: 35.6,
            west: 139.6,
            north: 35.8,
            east: 139.9,
          ),
        );

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          home: V2HomeMapScreen(
            autoLocate: false,
            mapBuilder: (_) =>
                const ColoredBox(key: Key('fakeMap'), color: Colors.white),
          ),
        ),
      ),
    );

    await tester.pump();

    expect(find.byKey(const Key('productMachineSearchEmpty')), findsOneWidget);
    expect(find.text('この範囲では「BOSS ブラック」が見つかりませんでした'), findsOneWidget);
  });
}

final class _EmptyIndexRepository implements MachineProductIndexRepository {
  @override
  Future<AppResult<List<MachineProductIndexEntry>>> findByProductInViewport({
    required ProductId productId,
    required MapViewportBounds viewport,
  }) async {
    return const AppResult<List<MachineProductIndexEntry>>.success(
      <MachineProductIndexEntry>[],
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
