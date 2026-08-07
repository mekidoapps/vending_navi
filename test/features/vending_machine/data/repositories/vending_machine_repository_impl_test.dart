import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vending_app/core/errors/app_failure.dart';
import 'package:vending_app/core/result/app_result.dart';
import 'package:vending_app/features/product_master/data/fixtures/product_master_fixture.dart';
import 'package:vending_app/features/product_master/domain/entities/manufacturer.dart';
import 'package:vending_app/features/product_master/domain/entities/product.dart';
import 'package:vending_app/features/product_master/domain/repositories/manufacturer_repository.dart';
import 'package:vending_app/features/product_master/domain/repositories/product_repository.dart';
import 'package:vending_app/features/product_master/domain/value_objects/master_id.dart';
import 'package:vending_app/features/vending_machine/data/repositories/vending_machine_repository_impl.dart';
import 'package:vending_app/features/vending_machine/data/sources/vending_machine_document.dart';
import 'package:vending_app/features/vending_machine/data/sources/vending_machine_document_source.dart';
import 'package:vending_app/features/vending_machine/domain/entities/vending_machine_enums.dart';
import 'package:vending_app/features/vending_machine/domain/value_objects/vending_machine_id.dart';

void main() {
  group('VendingMachineRepositoryImpl', () {
    test('schemaVersion=2はrootとproductsサブコレクションを結合する', () async {
      final source = _FakeMachineSource(
        machines: <VendingMachineDocument>[_v2MachineDocument()],
        products: <String, List<VendingMachineDocument>>{
          'machine_v2': <VendingMachineDocument>[_v2ProductDocument()],
        },
      );
      final repository = _repository(source);

      final result = await repository.getMachine(
        VendingMachineId.parse('machine_v2'),
      );

      expect(result.failureOrNull, isNull);
      expect(result.valueOrNull?.schemaVersion, 2);
      expect(result.valueOrNull?.products, hasLength(1));
      expect(
        result.valueOrNull?.products.single.evidenceType,
        ProductEvidenceType.manualConfirmed,
      );
    });

    test('v1文書は旧互換Mapperを通して同じDomainへ変換する', () async {
      final source = _FakeMachineSource(
        machines: <VendingMachineDocument>[_legacyMachineDocument()],
      );
      final repository = _repository(source);

      final result = await repository.getMachine(
        VendingMachineId.parse('machine_legacy'),
      );

      expect(result.failureOrNull, isNull);

      final machine = result.valueOrNull;
      expect(machine?.isLegacy, isTrue);
      expect(machine?.manufacturerId?.value, 'suntory');
      expect(machine?.products, hasLength(1));
      expect(machine?.products.single.productId.value, 'suntory_boss_black');
      expect(source.productFetchCount, 0);
    });

    test('互換snapshotは位置なしlegacyだけを除外し件数を返す', () async {
      final source = _FakeMachineSource(
        machines: <VendingMachineDocument>[
          _v2MachineDocument(),
          _legacyMachineDocument(),
          const VendingMachineDocument(
            id: 'legacy_without_location',
            data: <String, dynamic>{
              'name': '位置なし',
              'manufacturer': 'サントリー',
              'products': <Object>[],
            },
          ),
        ],
        products: <String, List<VendingMachineDocument>>{
          'machine_v2': <VendingMachineDocument>[_v2ProductDocument()],
        },
      );
      final repository = _repository(source);

      final result = await repository.getCompatibilitySnapshot();

      expect(result.failureOrNull, isNull);
      expect(result.valueOrNull?.machines, hasLength(2));
      expect(result.valueOrNull?.skippedLegacyWithoutLocation, 1);
      expect(result.valueOrNull?.unresolvedLegacyProductCount, 1);
    });

    test('v2商品文書が壊れている場合は黙って除外せずFailureにする', () async {
      final source = _FakeMachineSource(
        machines: <VendingMachineDocument>[_v2MachineDocument()],
        products: <String, List<VendingMachineDocument>>{
          'machine_v2': <VendingMachineDocument>[
            const VendingMachineDocument(
              id: 'suntory_boss_black',
              data: <String, dynamic>{'productId': 'suntory_tennensui'},
            ),
          ],
        },
      );
      final repository = _repository(source);

      final result = await repository.getCompatibilitySnapshot();

      expect(result.failureOrNull, isA<ValidationFailure>());
    });
  });
}

VendingMachineRepositoryImpl _repository(_FakeMachineSource source) {
  return VendingMachineRepositoryImpl(
    source: source,
    productRepository: _FixtureProductRepository(),
    manufacturerRepository: _FixtureManufacturerRepository(),
  );
}

VendingMachineDocument _v2MachineDocument() {
  final time = DateTime.utc(2026, 8, 7);
  return VendingMachineDocument(
    id: 'machine_v2',
    data: <String, dynamic>{
      'schemaVersion': 2,
      'name': 'v2自販機',
      'manufacturerId': 'suntory',
      'manufacturerStatus': 'confirmed',
      'location': const GeoPoint(35.68, 139.76),
      'geohash': 'xn76',
      'placeDescription': '駅前',
      'installationType': 'outdoor',
      'status': 'active',
      'mergedIntoMachineId': null,
      'dataLevel': 'productsConfirmed',
      'primaryPhotoId': null,
      'createdBy': 'test_uid',
      'createdAt': Timestamp.fromDate(time),
      'updatedAt': Timestamp.fromDate(time),
      'lastProductUpdatedAt': Timestamp.fromDate(time),
    },
  );
}

VendingMachineDocument _v2ProductDocument() {
  final time = DateTime.utc(2026, 8, 7);
  return VendingMachineDocument(
    id: 'suntory_boss_black',
    data: <String, dynamic>{
      'productId': 'suntory_boss_black',
      'evidenceType': 'manual_confirmed',
      'availability': 'available',
      'isActive': true,
      'confirmedBy': 'test_uid',
      'confirmedAt': Timestamp.fromDate(time),
      'createdAt': Timestamp.fromDate(time),
      'updatedAt': Timestamp.fromDate(time),
    },
  );
}

VendingMachineDocument _legacyMachineDocument() {
  return const VendingMachineDocument(
    id: 'machine_legacy',
    data: <String, dynamic>{
      'name': '旧自販機',
      'manufacturer': 'サントリー',
      'lat': 35.67,
      'lng': 139.75,
      'products': <Object>[
        <String, Object>{'name': 'ボスブラック', 'isSoldOut': false},
        <String, Object>{'name': 'BOSS', 'isSoldOut': false},
      ],
      'locationName': '旧駅前',
    },
  );
}

final class _FakeMachineSource implements VendingMachineDocumentSource {
  _FakeMachineSource({
    required this.machines,
    this.products = const <String, List<VendingMachineDocument>>{},
  });

  final List<VendingMachineDocument> machines;
  final Map<String, List<VendingMachineDocument>> products;
  int productFetchCount = 0;

  @override
  Future<List<VendingMachineDocument>> fetchMachineDocuments() async {
    return machines;
  }

  @override
  Future<VendingMachineDocument?> fetchMachineDocument(String machineId) async {
    for (final machine in machines) {
      if (machine.id == machineId) {
        return machine;
      }
    }
    return null;
  }

  @override
  Future<List<VendingMachineDocument>> fetchProductDocuments(
    String machineId,
  ) async {
    productFetchCount += 1;
    return products[machineId] ?? const <VendingMachineDocument>[];
  }
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

final class _FixtureManufacturerRepository implements ManufacturerRepository {
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
