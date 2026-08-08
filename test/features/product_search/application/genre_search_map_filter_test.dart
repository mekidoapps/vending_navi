import 'package:flutter_test/flutter_test.dart';
import 'package:vending_app/features/product_master/domain/entities/product_genre.dart';
import 'package:vending_app/features/product_master/domain/value_objects/master_id.dart';
import 'package:vending_app/features/product_search/application/genre_machine_search_state.dart';
import 'package:vending_app/features/product_search/application/genre_search_map_filter.dart';
import 'package:vending_app/features/product_search/domain/entities/machine_product_index_entry.dart';
import 'package:vending_app/features/vending_machine/domain/entities/vending_machine.dart';
import 'package:vending_app/features/vending_machine/domain/entities/vending_machine_enums.dart';
import 'package:vending_app/features/vending_machine/domain/entities/vending_machine_product.dart';
import 'package:vending_app/features/vending_machine/domain/value_objects/geo_coordinate.dart';
import 'package:vending_app/features/vending_machine/domain/value_objects/vending_machine_id.dart';

void main() {
  test('v2はGenre検索結果indexのmachineIdだけ表示する', () {
    final state = GenreMachineSearchState(
      genre: ProductGenre.coffee,
      hasSearched: true,
      productIds: <ProductId>{ProductId.parse('suntory_boss_black')},
      entries: <MachineProductIndexEntry>[_entry('machine_2')],
    );

    final visible = GenreSearchMapFilter.visibleMachines(
      machines: <VendingMachine>[_machine('machine_1'), _machine('machine_2')],
      selectedGenre: ProductGenre.coffee,
      searchState: state,
    );

    expect(visible.map((machine) => machine.id.value), <String>['machine_2']);
  });

  test('legacyはGenreに属する解決済みProduct IDで合流する', () {
    final bossId = ProductId.parse('suntory_boss_black');

    final visible = GenreSearchMapFilter.visibleMachines(
      machines: <VendingMachine>[
        _machine(
          'legacy_match',
          schemaVersion: 1,
          products: <VendingMachineProduct>[
            VendingMachineProduct(
              productId: bossId,
              evidenceType: ProductEvidenceType.manualConfirmed,
              availability: ProductAvailability.available,
            ),
          ],
        ),
        _machine(
          'legacy_other',
          schemaVersion: 1,
          products: <VendingMachineProduct>[
            VendingMachineProduct(
              productId: ProductId.parse('suntory_tennensui'),
              evidenceType: ProductEvidenceType.manualConfirmed,
              availability: ProductAvailability.available,
            ),
          ],
        ),
      ],
      selectedGenre: ProductGenre.coffee,
      searchState: GenreMachineSearchState(
        genre: ProductGenre.coffee,
        hasSearched: true,
        productIds: <ProductId>{bossId},
      ),
    );

    expect(visible.map((machine) => machine.id.value), <String>[
      'legacy_match',
    ]);
  });

  test('Genre検索中は通常Markerを誤表示しない', () {
    final visible = GenreSearchMapFilter.visibleMachines(
      machines: <VendingMachine>[_machine('machine_1')],
      selectedGenre: ProductGenre.coffee,
      searchState: const GenreMachineSearchState(
        genre: ProductGenre.coffee,
        isLoading: true,
      ),
    );

    expect(visible, isEmpty);
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

MachineProductIndexEntry _entry(String machineId) {
  return MachineProductIndexEntry(
    machineId: VendingMachineId.parse(machineId),
    productId: ProductId.parse('suntory_boss_black'),
    genres: const <ProductGenre>[ProductGenre.coffee],
    location: GeoCoordinate(latitude: 35.68, longitude: 139.76),
    geohash: 'xn76',
    evidenceType: ProductEvidenceType.manualConfirmed,
    availability: ProductAvailability.available,
    isActive: true,
    machineStatus: VendingMachineStatus.active,
    machineUpdatedAt: DateTime.utc(2026, 8, 9),
    updatedAt: DateTime.utc(2026, 8, 9),
  );
}
