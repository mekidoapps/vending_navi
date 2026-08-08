import 'package:flutter_test/flutter_test.dart';
import 'package:vending_app/features/product_master/data/fixtures/product_master_fixture.dart';
import 'package:vending_app/features/product_master/domain/value_objects/master_id.dart';
import 'package:vending_app/features/product_search/application/product_machine_search_state.dart';
import 'package:vending_app/features/product_search/application/product_search_map_filter.dart';
import 'package:vending_app/features/product_search/domain/entities/machine_product_index_entry.dart';
import 'package:vending_app/features/vending_machine/domain/entities/vending_machine.dart';
import 'package:vending_app/features/vending_machine/domain/entities/vending_machine_enums.dart';
import 'package:vending_app/features/vending_machine/domain/entities/vending_machine_product.dart';
import 'package:vending_app/features/vending_machine/domain/value_objects/geo_coordinate.dart';
import 'package:vending_app/features/vending_machine/domain/value_objects/vending_machine_id.dart';

void main() {
  final boss = ProductMasterFixture.products.firstWhere(
    (product) => product.id.value == 'suntory_boss_black',
  );

  test('未検索時は全自販機を返す', () {
    final machines = <VendingMachine>[
      _machine('v2_1'),
      _machine('legacy_1', schemaVersion: 1),
    ];

    expect(
      ProductSearchMapFilter.visibleMachines(
        machines: machines,
        selectedProduct: null,
        searchState: const ProductMachineSearchState(),
      ),
      hasLength(2),
    );
  });

  test('v2はindexのmachineIdだけ表示する', () {
    final machines = <VendingMachine>[_machine('v2_1'), _machine('v2_2')];

    final visible = ProductSearchMapFilter.visibleMachines(
      machines: machines,
      selectedProduct: boss,
      searchState: ProductMachineSearchState(
        productId: boss.id,
        hasSearched: true,
        entries: <MachineProductIndexEntry>[_indexEntry('v2_2', boss.id)],
      ),
    );

    expect(visible.map((machine) => machine.id.value), <String>['v2_2']);
  });

  test('legacyは互換変換済みProduct IDで検索結果へ合流する', () {
    final legacyMatch = _machine(
      'legacy_match',
      schemaVersion: 1,
      products: <VendingMachineProduct>[
        VendingMachineProduct(
          productId: boss.id,
          evidenceType: ProductEvidenceType.manualConfirmed,
          availability: ProductAvailability.available,
        ),
      ],
    );

    final legacyOther = _machine(
      'legacy_other',
      schemaVersion: 1,
      products: <VendingMachineProduct>[
        VendingMachineProduct(
          productId: ProductId.parse('suntory_tennensui'),
          evidenceType: ProductEvidenceType.manualConfirmed,
          availability: ProductAvailability.available,
        ),
      ],
    );

    final visible = ProductSearchMapFilter.visibleMachines(
      machines: <VendingMachine>[legacyMatch, legacyOther],
      selectedProduct: boss,
      searchState: ProductMachineSearchState(
        productId: boss.id,
        hasSearched: true,
      ),
    );

    expect(visible.map((machine) => machine.id.value), <String>[
      'legacy_match',
    ]);
  });

  test('検索中・Failure時は通常Markerを誤表示しない', () {
    final machines = <VendingMachine>[_machine('v2_1')];

    expect(
      ProductSearchMapFilter.visibleMachines(
        machines: machines,
        selectedProduct: boss,
        searchState: ProductMachineSearchState(
          productId: boss.id,
          isLoading: true,
        ),
      ),
      isEmpty,
    );
  });
}

VendingMachine _machine(
  String id, {
  int schemaVersion = 2,
  List<VendingMachineProduct> products = const [],
}) {
  return VendingMachine(
    id: VendingMachineId.parse(id),
    schemaVersion: schemaVersion,
    name: id,
    manufacturerStatus: ManufacturerStatus.unknown,
    location: GeoCoordinate(latitude: 35.68, longitude: 139.76),
    geohash: schemaVersion >= 2 ? 'xn76' : null,
    installationType: InstallationType.outdoor,
    status: VendingMachineStatus.active,
    dataLevel: schemaVersion >= 2 ? VendingMachineDataLevel.locationOnly : null,
    createdBy: schemaVersion >= 2 ? 'test' : null,
    products: products,
  );
}

MachineProductIndexEntry _indexEntry(String machineId, ProductId productId) {
  return MachineProductIndexEntry(
    machineId: VendingMachineId.parse(machineId),
    productId: productId,
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
