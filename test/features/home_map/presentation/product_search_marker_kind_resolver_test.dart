import 'package:flutter_test/flutter_test.dart';
import 'package:vending_app/features/home_map/presentation/product_search_marker_kind_resolver.dart';
import 'package:vending_app/features/home_map/presentation/vending_machine_marker_kind.dart';
import 'package:vending_app/features/product_master/data/fixtures/product_master_fixture.dart';
import 'package:vending_app/features/product_search/application/product_machine_search_state.dart';
import 'package:vending_app/features/product_search/domain/entities/machine_product_index_entry.dart';
import 'package:vending_app/features/vending_machine/domain/entities/vending_machine.dart';
import 'package:vending_app/features/vending_machine/domain/entities/vending_machine_enums.dart';
import 'package:vending_app/features/vending_machine/domain/value_objects/geo_coordinate.dart';
import 'package:vending_app/features/vending_machine/domain/value_objects/vending_machine_id.dart';

void main() {
  final boss = ProductMasterFixture.products.firstWhere(
    (product) => product.id.value == 'suntory_boss_black',
  );

  test('検索対象商品がconfirmedならconfirmed markerにする', () {
    final machine = _machine();

    expect(
      ProductSearchMarkerKindResolver.resolve(
        machine: machine,
        selectedMachineId: null,
        selectedProduct: boss,
        searchState: ProductMachineSearchState(
          productId: boss.id,
          hasSearched: true,
          entries: <MachineProductIndexEntry>[
            _entry(ProductEvidenceType.photoConfirmed),
          ],
        ),
      ),
      VendingMachineMarkerKind.confirmedProducts,
    );
  });

  test('検索対象商品がinferredなら他商品のconfirmedに影響されずinferredにする', () {
    final machine = _machine();

    expect(
      ProductSearchMarkerKindResolver.resolve(
        machine: machine,
        selectedMachineId: null,
        selectedProduct: boss,
        searchState: ProductMachineSearchState(
          productId: boss.id,
          hasSearched: true,
          entries: <MachineProductIndexEntry>[
            _entry(ProductEvidenceType.manufacturerInferred),
          ],
        ),
      ),
      VendingMachineMarkerKind.inferredProducts,
    );
  });

  test('選択中markerを最優先する', () {
    final machine = _machine();

    expect(
      ProductSearchMarkerKindResolver.resolve(
        machine: machine,
        selectedMachineId: machine.id,
        selectedProduct: boss,
        searchState: ProductMachineSearchState(
          productId: boss.id,
          hasSearched: true,
          entries: <MachineProductIndexEntry>[
            _entry(ProductEvidenceType.manufacturerInferred),
          ],
        ),
      ),
      VendingMachineMarkerKind.selected,
    );
  });
}

VendingMachine _machine() {
  return VendingMachine(
    id: VendingMachineId.parse('machine_search'),
    schemaVersion: 2,
    name: '検索用自販機',
    manufacturerStatus: ManufacturerStatus.unknown,
    location: GeoCoordinate(latitude: 35.68, longitude: 139.76),
    geohash: 'xn76',
    installationType: InstallationType.outdoor,
    status: VendingMachineStatus.active,
    dataLevel: VendingMachineDataLevel.productsConfirmed,
    createdBy: 'test',
  );
}

MachineProductIndexEntry _entry(ProductEvidenceType evidenceType) {
  return MachineProductIndexEntry(
    machineId: VendingMachineId.parse('machine_search'),
    productId: ProductMasterFixture.products
        .firstWhere((product) => product.id.value == 'suntory_boss_black')
        .id,
    genres: const [],
    location: GeoCoordinate(latitude: 35.68, longitude: 139.76),
    geohash: 'xn76',
    evidenceType: evidenceType,
    availability: ProductAvailability.available,
    isActive: true,
    machineStatus: VendingMachineStatus.active,
    machineUpdatedAt: DateTime.utc(2026, 8, 7),
    updatedAt: DateTime.utc(2026, 8, 7),
  );
}
