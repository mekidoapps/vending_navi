import 'package:flutter_test/flutter_test.dart';
import 'package:vending_app/features/home_map/presentation/genre_search_marker_kind_resolver.dart';
import 'package:vending_app/features/home_map/presentation/product_search_marker_kind_resolver.dart';
import 'package:vending_app/features/home_map/presentation/vending_machine_map_block_filter.dart';
import 'package:vending_app/features/home_map/presentation/vending_machine_marker_kind.dart';
import 'package:vending_app/features/product_master/data/fixtures/product_master_fixture.dart';
import 'package:vending_app/features/product_master/domain/entities/product.dart';
import 'package:vending_app/features/product_master/domain/entities/product_genre.dart';
import 'package:vending_app/features/product_master/domain/value_objects/master_id.dart';
import 'package:vending_app/features/product_search/application/genre_machine_search_state.dart';
import 'package:vending_app/features/product_search/application/product_machine_search_state.dart';
import 'package:vending_app/features/product_search/domain/entities/machine_product_index_entry.dart';
import 'package:vending_app/features/vending_machine/domain/entities/vending_machine.dart';
import 'package:vending_app/features/vending_machine/domain/entities/vending_machine_enums.dart';
import 'package:vending_app/features/vending_machine/domain/value_objects/geo_coordinate.dart';
import 'package:vending_app/features/vending_machine/domain/value_objects/vending_machine_id.dart';

void main() {
  final coffee = ProductMasterFixture.products.firstWhere(
    (product) => product.id.value == 'suntory_boss_black',
  );
  final tea = ProductMasterFixture.products.firstWhere(
    (product) => product.id.value == 'coca_cola_georgia_black',
  );
  final machines = <VendingMachine>[
    _machine('machine_a'),
    _machine('machine_b'),
    _machine('machine_c'),
  ];

  group('map machine blocking', () {
    test(
      'excludes only blocked machines and preserves nonblocked candidates',
      () {
        expect(
          _visible(
            machines: machines,
            blockedMachineIds: <String>{'machine_b'},
          ).map((machine) => machine.id.value),
          <String>['machine_a', 'machine_c'],
        );
      },
    );

    test(
      'returns all machines for an empty block state and none when all block',
      () {
        expect(
          _visible(machines: machines).map((machine) => machine.id.value),
          <String>['machine_a', 'machine_b', 'machine_c'],
        );
        expect(
          _visible(
            machines: machines,
            blockedMachineIds: <String>{'machine_a', 'machine_b', 'machine_c'},
          ),
          isEmpty,
        );
      },
    );
  });

  group('product search blocking', () {
    final state = ProductMachineSearchState(
      productId: coffee.id,
      hasSearched: true,
      entries: <MachineProductIndexEntry>[
        _entry('machine_a', coffee.id, ProductEvidenceType.photoConfirmed),
        _entry(
          'machine_b',
          coffee.id,
          ProductEvidenceType.manufacturerInferred,
        ),
      ],
    );

    test(
      'excludes blocked machines but preserves other product candidates',
      () {
        expect(
          _visible(
            machines: machines,
            selectedProduct: coffee,
            productSearchState: state,
            blockedMachineIds: <String>{'machine_a'},
          ).map((machine) => machine.id.value),
          <String>['machine_b'],
        );
      },
    );

    test(
      'excludes all target candidates when the selected product is blocked',
      () {
        expect(
          _visible(
            machines: machines,
            selectedProduct: coffee,
            productSearchState: state,
            blockedProductIds: <String>{coffee.id.value},
          ),
          isEmpty,
        );
      },
    );

    test('does not remove a product search for an unrelated product block', () {
      expect(
        _visible(
          machines: machines,
          selectedProduct: coffee,
          productSearchState: state,
          blockedProductIds: <String>{tea.id.value},
        ).map((machine) => machine.id.value),
        <String>['machine_a', 'machine_b'],
      );
    });
  });

  group('genre search blocking', () {
    final state = GenreMachineSearchState(
      genre: ProductGenre.coffee,
      productIds: <ProductId>{coffee.id, tea.id},
      hasSearched: true,
      entries: <MachineProductIndexEntry>[
        _entry('machine_a', coffee.id, ProductEvidenceType.photoConfirmed),
        _entry('machine_a', tea.id, ProductEvidenceType.manufacturerInferred),
        _entry(
          'machine_b',
          coffee.id,
          ProductEvidenceType.manufacturerInferred,
        ),
      ],
    );

    test('keeps a machine when another qualified product remains', () {
      expect(
        _visible(
          machines: machines,
          selectedGenre: ProductGenre.coffee,
          genreSearchState: state,
          blockedProductIds: <String>{coffee.id.value},
        ).map((machine) => machine.id.value),
        <String>['machine_a'],
      );
    });

    test('excludes a machine when every qualified product is blocked', () {
      expect(
        _visible(
          machines: machines,
          selectedGenre: ProductGenre.coffee,
          genreSearchState: state,
          blockedProductIds: <String>{coffee.id.value, tea.id.value},
        ),
        isEmpty,
      );
    });

    test('does not alter genre candidates for unrelated product blocks', () {
      expect(
        _visible(
          machines: machines,
          selectedGenre: ProductGenre.coffee,
          genreSearchState: state,
          blockedProductIds: <String>{'unrelated_product'},
        ).map((machine) => machine.id.value),
        <String>['machine_a', 'machine_b'],
      );
    });
  });

  group('marker candidates', () {
    test(
      'preserves confirmed and inferred marker kinds for nonblocked results',
      () {
        final state = ProductMachineSearchState(
          productId: coffee.id,
          hasSearched: true,
          entries: <MachineProductIndexEntry>[
            _entry('machine_a', coffee.id, ProductEvidenceType.photoConfirmed),
            _entry(
              'machine_b',
              coffee.id,
              ProductEvidenceType.manufacturerInferred,
            ),
          ],
        );
        final candidates = _visible(
          machines: machines,
          selectedProduct: coffee,
          productSearchState: state,
        );

        expect(
          ProductSearchMarkerKindResolver.resolve(
            machine: candidates.first,
            selectedMachineId: null,
            selectedProduct: coffee,
            searchState: state,
          ),
          VendingMachineMarkerKind.confirmedProducts,
        );
        expect(
          ProductSearchMarkerKindResolver.resolve(
            machine: candidates.last,
            selectedMachineId: null,
            selectedProduct: coffee,
            searchState: state,
          ),
          VendingMachineMarkerKind.inferredProducts,
        );
      },
    );

    test(
      'does not generate candidates for blocked confirmed or inferred products',
      () {
        final state = ProductMachineSearchState(
          productId: coffee.id,
          hasSearched: true,
          entries: <MachineProductIndexEntry>[
            _entry('machine_a', coffee.id, ProductEvidenceType.photoConfirmed),
            _entry(
              'machine_b',
              coffee.id,
              ProductEvidenceType.manufacturerInferred,
            ),
          ],
        );

        expect(
          _visible(
            machines: machines,
            selectedProduct: coffee,
            productSearchState: state,
            blockedProductIds: <String>{coffee.id.value},
          ),
          isEmpty,
        );
      },
    );

    test(
      'keeps a genre marker candidate when an unblocked qualified product remains',
      () {
        final state = GenreMachineSearchState(
          genre: ProductGenre.coffee,
          productIds: <ProductId>{coffee.id, tea.id},
          hasSearched: true,
          entries: <MachineProductIndexEntry>[
            _entry('machine_a', coffee.id, ProductEvidenceType.photoConfirmed),
            _entry(
              'machine_a',
              tea.id,
              ProductEvidenceType.manufacturerInferred,
            ),
          ],
        );
        final candidate = _visible(
          machines: machines,
          selectedGenre: ProductGenre.coffee,
          genreSearchState: state,
          blockedProductIds: <String>{coffee.id.value},
        ).single;

        expect(candidate.id.value, 'machine_a');
        expect(
          GenreSearchMarkerKindResolver.resolve(
            machine: candidate,
            selectedMachineId: null,
            selectedGenre: ProductGenre.coffee,
            searchState: state,
            blockedProductIds: <String>{coffee.id.value},
          ),
          VendingMachineMarkerKind.inferredProducts,
        );
      },
    );
  });
}

List<VendingMachine> _visible({
  required List<VendingMachine> machines,
  Product? selectedProduct,
  ProductGenre? selectedGenre,
  ProductMachineSearchState productSearchState =
      const ProductMachineSearchState(),
  GenreMachineSearchState genreSearchState = const GenreMachineSearchState(),
  Set<String> blockedMachineIds = const <String>{},
  Set<String> blockedProductIds = const <String>{},
}) => VendingMachineMapBlockFilter.visibleMachines(
  machines: machines,
  selectedProduct: selectedProduct,
  selectedGenre: selectedGenre,
  productSearchState: productSearchState,
  genreSearchState: genreSearchState,
  blockedMachineIds: blockedMachineIds,
  blockedProductIds: blockedProductIds,
);

VendingMachine _machine(String id) => VendingMachine(
  id: VendingMachineId.parse(id),
  schemaVersion: 2,
  name: id,
  manufacturerStatus: ManufacturerStatus.unknown,
  location: GeoCoordinate(latitude: 35.68, longitude: 139.76),
  geohash: 'xn76',
  installationType: InstallationType.outdoor,
  status: VendingMachineStatus.active,
  dataLevel: VendingMachineDataLevel.productsConfirmed,
  createdBy: 'test',
);

MachineProductIndexEntry _entry(
  String machineId,
  ProductId productId,
  ProductEvidenceType evidenceType,
) => MachineProductIndexEntry(
  machineId: VendingMachineId.parse(machineId),
  productId: productId,
  genres: const <ProductGenre>[ProductGenre.coffee],
  location: GeoCoordinate(latitude: 35.68, longitude: 139.76),
  geohash: 'xn76',
  evidenceType: evidenceType,
  availability: ProductAvailability.available,
  isActive: true,
  machineStatus: VendingMachineStatus.active,
  machineUpdatedAt: DateTime.utc(2026, 9, 7),
  updatedAt: DateTime.utc(2026, 9, 7),
);
