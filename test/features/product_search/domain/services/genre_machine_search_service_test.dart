import 'package:flutter_test/flutter_test.dart';
import 'package:vending_app/core/errors/app_failure.dart';
import 'package:vending_app/core/result/app_result.dart';
import 'package:vending_app/features/home_map/domain/value_objects/map_viewport_bounds.dart';
import 'package:vending_app/features/product_master/data/fixtures/product_master_fixture.dart';
import 'package:vending_app/features/product_master/domain/entities/product.dart';
import 'package:vending_app/features/product_master/domain/entities/product_genre.dart';
import 'package:vending_app/features/product_master/domain/repositories/product_repository.dart';
import 'package:vending_app/features/product_master/domain/value_objects/master_id.dart';
import 'package:vending_app/features/product_search/domain/entities/machine_product_index_entry.dart';
import 'package:vending_app/features/product_search/domain/repositories/machine_product_index_repository.dart';
import 'package:vending_app/features/product_search/domain/services/genre_machine_search_service.dart';
import 'package:vending_app/features/vending_machine/domain/entities/vending_machine_enums.dart';
import 'package:vending_app/features/vending_machine/domain/value_objects/geo_coordinate.dart';
import 'package:vending_app/features/vending_machine/domain/value_objects/vending_machine_id.dart';

void main() {
  test('Genreに属するProduct ID群だけindex検索する', () async {
    final indexRepository = _RecordingIndexRepository();

    final service = GenreMachineSearchService(
      productRepository: _FixtureProductRepository(),
      machineProductIndexRepository: indexRepository,
    );

    final result = await service.search(
      genre: ProductGenre.coffee,
      viewport: _viewport(),
    );

    expect(result.failureOrNull, isNull);

    final expectedCoffeeIds = ProductMasterFixture.products
        .where(
          (product) =>
              product.isSelectable &&
              product.genres.contains(ProductGenre.coffee),
        )
        .map((product) => product.id.value)
        .toSet();

    expect(indexRepository.requestedProductIds, expectedCoffeeIds);
    expect(
      result.valueOrNull!.productIds.map((id) => id.value).toSet(),
      expectedCoffeeIds,
    );
  });

  test('複数Productで同一machineならconfirmed entryを優先して1件にする', () async {
    final products = _coffeeProducts();
    expect(products.length, greaterThanOrEqualTo(2));

    final service = GenreMachineSearchService(
      productRepository: _StaticProductRepository(products.take(2).toList()),
      machineProductIndexRepository: _DuplicateMachineIndexRepository(
        confirmedProductId: products[1].id,
      ),
    );

    final result = await service.search(
      genre: ProductGenre.coffee,
      viewport: _viewport(),
    );

    expect(result.failureOrNull, isNull);
    expect(result.valueOrNull!.entries, hasLength(1));
    expect(result.valueOrNull!.entries.single.isConfirmed, isTrue);
  });

  test('いずれかのindex検索がFailureなら不完全結果を成功扱いしない', () async {
    final products = _coffeeProducts();
    expect(products.length, greaterThanOrEqualTo(2));

    final service = GenreMachineSearchService(
      productRepository: _StaticProductRepository(products.take(2).toList()),
      machineProductIndexRepository: _FailingIndexRepository(
        failingProductId: products[1].id,
      ),
    );

    final result = await service.search(
      genre: ProductGenre.coffee,
      viewport: _viewport(),
    );

    expect(result.failureOrNull, isA<NetworkFailure>());
  });
}

List<Product> _coffeeProducts() {
  return ProductMasterFixture.products
      .where(
        (product) =>
            product.isSelectable &&
            product.genres.contains(ProductGenre.coffee),
      )
      .toList(growable: false);
}

MapViewportBounds _viewport() {
  return MapViewportBounds(south: 35.6, west: 139.6, north: 35.8, east: 139.9);
}

final class _FixtureProductRepository implements ProductRepository {
  @override
  Future<AppResult<Product>> getProduct(ProductId id) async {
    for (final product in ProductMasterFixture.products) {
      if (product.id == id) {
        return AppResult<Product>.success(product);
      }
    }
    return const AppResult<Product>.failure(NotFoundFailure());
  }

  @override
  Future<AppResult<List<Product>>> getProducts({bool activeOnly = true}) async {
    return AppResult<List<Product>>.success(
      ProductMasterFixture.products
          .where((product) => !activeOnly || product.isActive)
          .toList(growable: false),
    );
  }
}

final class _StaticProductRepository implements ProductRepository {
  _StaticProductRepository(this.products);

  final List<Product> products;

  @override
  Future<AppResult<Product>> getProduct(ProductId id) async {
    for (final product in products) {
      if (product.id == id) {
        return AppResult<Product>.success(product);
      }
    }
    return const AppResult<Product>.failure(NotFoundFailure());
  }

  @override
  Future<AppResult<List<Product>>> getProducts({bool activeOnly = true}) async {
    return AppResult<List<Product>>.success(products);
  }
}

final class _RecordingIndexRepository implements MachineProductIndexRepository {
  final Set<String> requestedProductIds = <String>{};

  @override
  Future<AppResult<List<MachineProductIndexEntry>>> findByProductInViewport({
    required ProductId productId,
    required MapViewportBounds viewport,
  }) async {
    requestedProductIds.add(productId.value);
    return const AppResult<List<MachineProductIndexEntry>>.success(
      <MachineProductIndexEntry>[],
    );
  }
}

final class _DuplicateMachineIndexRepository
    implements MachineProductIndexRepository {
  _DuplicateMachineIndexRepository({required this.confirmedProductId});

  final ProductId confirmedProductId;

  @override
  Future<AppResult<List<MachineProductIndexEntry>>> findByProductInViewport({
    required ProductId productId,
    required MapViewportBounds viewport,
  }) async {
    return AppResult<List<MachineProductIndexEntry>>.success(
      <MachineProductIndexEntry>[
        _entry(
          productId: productId,
          evidenceType: productId == confirmedProductId
              ? ProductEvidenceType.photoConfirmed
              : ProductEvidenceType.manufacturerInferred,
        ),
      ],
    );
  }
}

final class _FailingIndexRepository implements MachineProductIndexRepository {
  _FailingIndexRepository({required this.failingProductId});

  final ProductId failingProductId;

  @override
  Future<AppResult<List<MachineProductIndexEntry>>> findByProductInViewport({
    required ProductId productId,
    required MapViewportBounds viewport,
  }) async {
    if (productId == failingProductId) {
      return const AppResult<List<MachineProductIndexEntry>>.failure(
        NetworkFailure(),
      );
    }

    return AppResult<List<MachineProductIndexEntry>>.success(
      <MachineProductIndexEntry>[
        _entry(
          productId: productId,
          evidenceType: ProductEvidenceType.manualConfirmed,
        ),
      ],
    );
  }
}

MachineProductIndexEntry _entry({
  required ProductId productId,
  required ProductEvidenceType evidenceType,
}) {
  return MachineProductIndexEntry(
    machineId: VendingMachineId.parse('machine_coffee'),
    productId: productId,
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
