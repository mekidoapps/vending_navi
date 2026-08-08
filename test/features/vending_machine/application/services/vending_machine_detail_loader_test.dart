import 'package:flutter_test/flutter_test.dart';
import 'package:vending_app/core/errors/app_failure.dart';
import 'package:vending_app/core/result/app_result.dart';
import 'package:vending_app/features/product_master/data/fixtures/product_master_fixture.dart';
import 'package:vending_app/features/product_master/domain/entities/manufacturer.dart';
import 'package:vending_app/features/product_master/domain/entities/product.dart';
import 'package:vending_app/features/product_master/domain/entities/product_genre.dart';
import 'package:vending_app/features/product_master/domain/repositories/manufacturer_repository.dart';
import 'package:vending_app/features/product_master/domain/repositories/product_repository.dart';
import 'package:vending_app/features/product_master/domain/value_objects/master_id.dart';
import 'package:vending_app/features/vending_machine/application/services/vending_machine_detail_loader.dart';
import 'package:vending_app/features/vending_machine/domain/entities/vending_machine.dart';
import 'package:vending_app/features/vending_machine/domain/entities/vending_machine_enums.dart';
import 'package:vending_app/features/vending_machine/domain/entities/vending_machine_product.dart';
import 'package:vending_app/features/vending_machine/domain/models/vending_machine_read_batch.dart';
import 'package:vending_app/features/vending_machine/domain/repositories/vending_machine_repository.dart';
import 'package:vending_app/features/vending_machine/domain/value_objects/geo_coordinate.dart';
import 'package:vending_app/features/vending_machine/domain/value_objects/vending_machine_id.dart';

void main() {
  test('Product master名とメーカー短縮名を詳細データへ結合する', () async {
    final machine = _machine();
    final loader = VendingMachineDetailLoader(
      machineRepository: _MachineRepository(machine),
      productRepository: _ProductRepository(),
      manufacturerRepository: _ManufacturerRepository(),
    );

    final result = await loader.load(machine.id);

    expect(result.failureOrNull, isNull);
    expect(result.valueOrNull?.manufacturerName, 'サントリー');
    expect(result.valueOrNull?.products.first.productName, 'BOSS ブラック');
    expect(
      result.valueOrNull?.products.first.genres,
      contains(ProductGenre.coffee),
    );
    expect(result.valueOrNull?.products.first.isConfirmed, isTrue);
    expect(result.valueOrNull?.products.last.isInferred, isTrue);
  });

  test('Product master取得失敗でもProduct IDを表示名fallbackとして使う', () async {
    final machine = _machine();
    final loader = VendingMachineDetailLoader(
      machineRepository: _MachineRepository(machine),
      productRepository: _FailingProductRepository(),
      manufacturerRepository: _ManufacturerRepository(),
    );

    final result = await loader.load(machine.id);

    expect(result.failureOrNull, isNull);
    expect(
      result.valueOrNull?.products.first.productName,
      'suntory_boss_black',
    );
    expect(result.valueOrNull?.products.first.genres, isEmpty);
  });

  test('自販機取得Failureはそのまま返す', () async {
    final loader = VendingMachineDetailLoader(
      machineRepository: _FailingMachineRepository(),
      productRepository: _ProductRepository(),
      manufacturerRepository: _ManufacturerRepository(),
    );

    final result = await loader.load(VendingMachineId.parse('machine_missing'));

    expect(result.failureOrNull, isA<NotFoundFailure>());
  });
}

VendingMachine _machine() {
  return VendingMachine(
    id: VendingMachineId.parse('machine_detail'),
    schemaVersion: 2,
    name: '駅前の自販機',
    manufacturerId: ManufacturerId.parse('suntory'),
    manufacturerStatus: ManufacturerStatus.confirmed,
    location: GeoCoordinate(latitude: 35.681236, longitude: 139.767125),
    geohash: 'xn76ur',
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
      VendingMachineProduct(
        productId: ProductId.parse('suntory_tennensui'),
        evidenceType: ProductEvidenceType.manufacturerInferred,
        availability: ProductAvailability.unknown,
      ),
    ],
  );
}

final class _MachineRepository implements VendingMachineRepository {
  _MachineRepository(this.machine);

  final VendingMachine machine;

  @override
  Future<AppResult<VendingMachine>> getMachine(VendingMachineId id) async {
    return AppResult<VendingMachine>.success(machine);
  }

  @override
  Future<AppResult<VendingMachineReadBatch>> getCompatibilitySnapshot() async {
    return AppResult<VendingMachineReadBatch>.success(
      VendingMachineReadBatch(
        machines: <VendingMachine>[machine],
        skippedLegacyWithoutLocation: 0,
        unresolvedLegacyProductCount: 0,
      ),
    );
  }
}

final class _FailingMachineRepository implements VendingMachineRepository {
  @override
  Future<AppResult<VendingMachine>> getMachine(VendingMachineId id) async {
    return const AppResult<VendingMachine>.failure(NotFoundFailure());
  }

  @override
  Future<AppResult<VendingMachineReadBatch>> getCompatibilitySnapshot() async {
    return const AppResult<VendingMachineReadBatch>.failure(NotFoundFailure());
  }
}

final class _ProductRepository implements ProductRepository {
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

final class _FailingProductRepository implements ProductRepository {
  @override
  Future<AppResult<Product>> getProduct(ProductId id) async {
    return const AppResult<Product>.failure(NetworkFailure());
  }

  @override
  Future<AppResult<List<Product>>> getProducts({bool activeOnly = true}) async {
    return const AppResult<List<Product>>.failure(NetworkFailure());
  }
}

final class _ManufacturerRepository implements ManufacturerRepository {
  @override
  Future<AppResult<Manufacturer>> getManufacturer(ManufacturerId id) async {
    for (final manufacturer in ProductMasterFixture.manufacturers) {
      if (manufacturer.id == id) {
        return AppResult<Manufacturer>.success(manufacturer);
      }
    }
    return const AppResult<Manufacturer>.failure(NotFoundFailure());
  }

  @override
  Future<AppResult<List<Manufacturer>>> getManufacturers({
    bool activeOnly = true,
  }) async {
    return AppResult<List<Manufacturer>>.success(
      ProductMasterFixture.manufacturers
          .where((manufacturer) => !activeOnly || manufacturer.isActive)
          .toList(growable: false),
    );
  }
}
