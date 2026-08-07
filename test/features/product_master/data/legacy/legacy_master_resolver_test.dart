import 'package:flutter_test/flutter_test.dart';
import 'package:vending_app/features/product_master/data/legacy/legacy_master_resolution.dart';
import 'package:vending_app/features/product_master/data/legacy/legacy_master_resolver.dart';
import 'package:vending_app/features/product_master/data/legacy/legacy_product_candidate.dart';
import 'package:vending_app/features/product_master/domain/entities/manufacturer.dart';
import 'package:vending_app/features/product_master/domain/entities/product.dart';
import 'package:vending_app/features/product_master/domain/entities/product_genre.dart';
import 'package:vending_app/features/product_master/domain/value_objects/master_id.dart';

void main() {
  final manufacturers = <Manufacturer>[
    _manufacturer('coca_cola', 'コカ・コーラ'),
    _manufacturer('suntory', 'サントリー'),
  ];
  final products = <Product>[
    _product('coca_cola_ayataka', '綾鷹', 'coca_cola'),
    _product('coca_cola_shared', '共通名', 'coca_cola'),
    _product('suntory_shared', '共通名', 'suntory'),
  ];

  group('LegacyMasterResolver manufacturer', () {
    test('表示名の正規化一致でManufacturer IDへ変換する', () {
      final result = LegacyMasterResolver.resolveManufacturer(
        legacyName: ' コカ・コーラ ',
        manufacturers: manufacturers,
      );

      expect(result.manufacturerId?.value, 'coca_cola');
      expect(result.kind, LegacyManufacturerResolutionKind.normalizedName);
    });

    test('不明は架空IDへ変換しない', () {
      final result = LegacyMasterResolver.resolveManufacturer(
        legacyName: '不明',
        manufacturers: manufacturers,
      );

      expect(result.manufacturerId, isNull);
      expect(result.kind, LegacyManufacturerResolutionKind.unresolved);
    });
  });

  group('LegacyMasterResolver product', () {
    final cocaCola = LegacyMasterResolver.resolveManufacturer(
      legacyName: 'コカ・コーラ',
      manufacturers: manufacturers,
    );

    test('Product ID完全一致を最優先する', () {
      final result = LegacyMasterResolver.resolveProduct(
        candidate: const LegacyProductCandidate(
          rawName: '旧表示名',
          explicitProductId: 'coca_cola_ayataka',
          source: LegacyProductSource.products,
        ),
        products: products,
        manufacturer: cocaCola,
      );

      expect(result.productId?.value, 'coca_cola_ayataka');
      expect(result.kind, LegacyProductResolutionKind.exactId);
    });

    test('旧名称の正規化一致で一意の商品を解決する', () {
      final result = LegacyMasterResolver.resolveProduct(
        candidate: const LegacyProductCandidate(
          rawName: ' あやたか ',
          source: LegacyProductSource.drinks,
        ),
        products: <Product>[_product('coca_cola_ayataka', 'アヤタカ', 'coca_cola')],
        manufacturer: cocaCola,
      );

      expect(result.productId?.value, 'coca_cola_ayataka');
      expect(result.kind, LegacyProductResolutionKind.normalizedName);
    });

    test('同名商品はメーカーと組み合わせて解決する', () {
      final result = LegacyMasterResolver.resolveProduct(
        candidate: const LegacyProductCandidate(
          rawName: '共通名',
          source: LegacyProductSource.products,
        ),
        products: products,
        manufacturer: cocaCola,
      );

      expect(result.productId?.value, 'coca_cola_shared');
      expect(result.kind, LegacyProductResolutionKind.manufacturerAndName);
    });

    test('手動対応表を最後の確定候補として使う', () {
      final result = LegacyMasterResolver.resolveProduct(
        candidate: const LegacyProductCandidate(
          rawName: '旧・綾鷹500',
          source: LegacyProductSource.drinkSlots,
        ),
        products: products,
        manufacturer: cocaCola,
        manualAliases: <String, ProductId>{
          '旧・綾鷹500': ProductId.parse('coca_cola_ayataka'),
        },
      );

      expect(result.productId?.value, 'coca_cola_ayataka');
      expect(result.kind, LegacyProductResolutionKind.manualAlias);
    });

    test('対応不能商品はrawNameを保持して未解決にする', () {
      final result = LegacyMasterResolver.resolveProduct(
        candidate: const LegacyProductCandidate(
          rawName: 'マスタ外の商品',
          source: LegacyProductSource.drinks,
        ),
        products: products,
        manufacturer: cocaCola,
      );

      expect(result.productId, isNull);
      expect(result.rawName, 'マスタ外の商品');
      expect(result.kind, LegacyProductResolutionKind.unresolved);
    });
  });
}

Manufacturer _manufacturer(String id, String name) {
  return Manufacturer(
    id: ManufacturerId.parse(id),
    name: name,
    displayShortName: name,
    createdAt: DateTime.utc(2026),
    updatedAt: DateTime.utc(2026),
  );
}

Product _product(String id, String name, String manufacturerId) {
  return Product(
    id: ProductId.parse(id),
    name: name,
    manufacturerId: ManufacturerId.parse(manufacturerId),
    genres: const <ProductGenre>[ProductGenre.other],
    createdAt: DateTime.utc(2026),
    updatedAt: DateTime.utc(2026),
  );
}
