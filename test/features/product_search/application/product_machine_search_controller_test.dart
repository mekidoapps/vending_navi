import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vending_app/core/errors/app_failure.dart';
import 'package:vending_app/core/result/app_result.dart';
import 'package:vending_app/features/home_map/domain/value_objects/map_viewport_bounds.dart';
import 'package:vending_app/features/product_master/domain/value_objects/master_id.dart';
import 'package:vending_app/features/product_search/application/product_machine_search_controller.dart';
import 'package:vending_app/features/product_search/application/providers/machine_product_index_providers.dart';
import 'package:vending_app/features/product_search/domain/entities/machine_product_index_entry.dart';
import 'package:vending_app/features/product_search/domain/repositories/machine_product_index_repository.dart';
import 'package:vending_app/features/vending_machine/domain/entities/vending_machine_enums.dart';
import 'package:vending_app/features/vending_machine/domain/value_objects/geo_coordinate.dart';
import 'package:vending_app/features/vending_machine/domain/value_objects/vending_machine_id.dart';

void main() {
  test('Product IDとviewportでindexを検索して結果を保持する', () async {
    final entry = _entry('machine_1');
    final container = ProviderContainer(
      overrides: [
        machineProductIndexRepositoryProvider.overrideWithValue(
          _FakeIndexRepository(
            AppResult<List<MachineProductIndexEntry>>.success(
              <MachineProductIndexEntry>[entry],
            ),
          ),
        ),
      ],
    );
    addTearDown(container.dispose);

    await container
        .read(productMachineSearchControllerProvider.notifier)
        .search(
          productId: ProductId.parse('suntory_boss_black'),
          viewport: _viewport(),
        );

    final state = container.read(productMachineSearchControllerProvider);

    expect(state.failure, isNull);
    expect(state.hasSearched, isTrue);
    expect(state.isLoading, isFalse);
    expect(state.entries.single.machineId.value, 'machine_1');
  });

  test('同一条件の再検索を省略しforceなら再実行する', () async {
    final repository = _CountingIndexRepository();
    final container = ProviderContainer(
      overrides: [
        machineProductIndexRepositoryProvider.overrideWithValue(repository),
      ],
    );
    addTearDown(container.dispose);

    final controller = container.read(
      productMachineSearchControllerProvider.notifier,
    );

    await controller.search(
      productId: ProductId.parse('suntory_boss_black'),
      viewport: _viewport(),
    );
    await controller.search(
      productId: ProductId.parse('suntory_boss_black'),
      viewport: _viewport(),
    );
    await controller.search(
      productId: ProductId.parse('suntory_boss_black'),
      viewport: _viewport(),
      force: true,
    );

    expect(repository.calls, 2);
  });

  test('古い非同期結果で最新Product検索を上書きしない', () async {
    final repository = _DeferredIndexRepository();
    final container = ProviderContainer(
      overrides: [
        machineProductIndexRepositoryProvider.overrideWithValue(repository),
      ],
    );
    addTearDown(container.dispose);

    final controller = container.read(
      productMachineSearchControllerProvider.notifier,
    );

    final first = controller.search(
      productId: ProductId.parse('suntory_boss_black'),
      viewport: _viewport(),
    );
    final second = controller.search(
      productId: ProductId.parse('suntory_tennensui'),
      viewport: _viewport(),
    );

    repository.complete('suntory_tennensui', <MachineProductIndexEntry>[
      _entry('machine_water', productId: 'suntory_tennensui'),
    ]);
    await second;

    repository.complete('suntory_boss_black', <MachineProductIndexEntry>[
      _entry('machine_boss'),
    ]);
    await first;

    final state = container.read(productMachineSearchControllerProvider);
    expect(state.productId?.value, 'suntory_tennensui');
    expect(state.entries.single.machineId.value, 'machine_water');
  });

  test('Repository Failureを保持する', () async {
    final container = ProviderContainer(
      overrides: [
        machineProductIndexRepositoryProvider.overrideWithValue(
          _FakeIndexRepository(
            const AppResult<List<MachineProductIndexEntry>>.failure(
              NetworkFailure(),
            ),
          ),
        ),
      ],
    );
    addTearDown(container.dispose);

    await container
        .read(productMachineSearchControllerProvider.notifier)
        .search(
          productId: ProductId.parse('suntory_boss_black'),
          viewport: _viewport(),
        );

    expect(
      container.read(productMachineSearchControllerProvider).failure,
      isA<NetworkFailure>(),
    );
  });
}

MapViewportBounds _viewport() {
  return MapViewportBounds(south: 35.6, west: 139.6, north: 35.8, east: 139.9);
}

MachineProductIndexEntry _entry(
  String machineId, {
  String productId = 'suntory_boss_black',
}) {
  return MachineProductIndexEntry(
    machineId: VendingMachineId.parse(machineId),
    productId: ProductId.parse(productId),
    genres: const [],
    location: GeoCoordinate(latitude: 35.68, longitude: 139.76),
    geohash: 'xn76',
    evidenceType: ProductEvidenceType.manualConfirmed,
    availability: ProductAvailability.available,
    isActive: true,
    machineStatus: VendingMachineStatus.active,
    machineUpdatedAt: DateTime.utc(2026, 8, 7),
    updatedAt: DateTime.utc(2026, 8, 7),
  );
}

final class _FakeIndexRepository implements MachineProductIndexRepository {
  _FakeIndexRepository(this.result);

  final AppResult<List<MachineProductIndexEntry>> result;

  @override
  Future<AppResult<List<MachineProductIndexEntry>>> findByProductInViewport({
    required ProductId productId,
    required MapViewportBounds viewport,
  }) async {
    return result;
  }
}

final class _CountingIndexRepository implements MachineProductIndexRepository {
  int calls = 0;

  @override
  Future<AppResult<List<MachineProductIndexEntry>>> findByProductInViewport({
    required ProductId productId,
    required MapViewportBounds viewport,
  }) async {
    calls += 1;
    return const AppResult<List<MachineProductIndexEntry>>.success(
      <MachineProductIndexEntry>[],
    );
  }
}

final class _DeferredIndexRepository implements MachineProductIndexRepository {
  final Map<String, Completer<AppResult<List<MachineProductIndexEntry>>>>
  _pending = {};

  @override
  Future<AppResult<List<MachineProductIndexEntry>>> findByProductInViewport({
    required ProductId productId,
    required MapViewportBounds viewport,
  }) {
    return _pending
        .putIfAbsent(
          productId.value,
          Completer<AppResult<List<MachineProductIndexEntry>>>.new,
        )
        .future;
  }

  void complete(String productId, List<MachineProductIndexEntry> entries) {
    _pending[productId]!.complete(
      AppResult<List<MachineProductIndexEntry>>.success(entries),
    );
  }
}
