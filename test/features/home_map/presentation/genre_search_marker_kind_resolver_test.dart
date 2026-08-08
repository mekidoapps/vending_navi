import 'package:flutter_test/flutter_test.dart';
import 'package:vending_app/features/home_map/presentation/genre_search_marker_kind_resolver.dart';
import 'package:vending_app/features/home_map/presentation/vending_machine_marker_kind.dart';
import 'package:vending_app/features/product_master/domain/entities/product_genre.dart';
import 'package:vending_app/features/product_master/domain/value_objects/master_id.dart';
import 'package:vending_app/features/product_search/application/genre_machine_search_state.dart';
import 'package:vending_app/features/product_search/domain/entities/machine_product_index_entry.dart';
import 'package:vending_app/features/vending_machine/domain/entities/vending_machine.dart';
import 'package:vending_app/features/vending_machine/domain/entities/vending_machine_enums.dart';
import 'package:vending_app/features/vending_machine/domain/value_objects/geo_coordinate.dart';
import 'package:vending_app/features/vending_machine/domain/value_objects/vending_machine_id.dart';

void main() {
  test('Genre検索結果がconfirmedならconfirmed Markerにする', () {
    final machine = _machine();

    expect(
      GenreSearchMarkerKindResolver.resolve(
        machine: machine,
        selectedMachineId: null,
        selectedGenre: ProductGenre.coffee,
        searchState: GenreMachineSearchState(
          genre: ProductGenre.coffee,
          hasSearched: true,
          entries: <MachineProductIndexEntry>[
            _entry(ProductEvidenceType.photoConfirmed),
          ],
        ),
      ),
      VendingMachineMarkerKind.confirmedProducts,
    );
  });

  test('Genre検索結果がinferredならinferred Markerにする', () {
    final machine = _machine();

    expect(
      GenreSearchMarkerKindResolver.resolve(
        machine: machine,
        selectedMachineId: null,
        selectedGenre: ProductGenre.coffee,
        searchState: GenreMachineSearchState(
          genre: ProductGenre.coffee,
          hasSearched: true,
          entries: <MachineProductIndexEntry>[
            _entry(ProductEvidenceType.manufacturerInferred),
          ],
        ),
      ),
      VendingMachineMarkerKind.inferredProducts,
    );
  });
}

VendingMachine _machine() {
  return VendingMachine(
    id: VendingMachineId.parse('machine_coffee'),
    schemaVersion: 2,
    name: 'コーヒー自販機',
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
    machineId: VendingMachineId.parse('machine_coffee'),
    productId: ProductId.parse('suntory_boss_black'),
    genres: const <ProductGenre>[ProductGenre.coffee],
    location: GeoCoordinate(latitude: 35.68, longitude: 139.76),
    geohash: 'xn76',
    evidenceType: evidenceType,
    availability: ProductAvailability.available,
    isActive: true,
    machineStatus: VendingMachineStatus.active,
    machineUpdatedAt: DateTime.utc(2026, 8, 9),
    updatedAt: DateTime.utc(2026, 8, 9),
  );
}
