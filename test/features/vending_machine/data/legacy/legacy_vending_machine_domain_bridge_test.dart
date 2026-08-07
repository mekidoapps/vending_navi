import 'package:flutter_test/flutter_test.dart';
import 'package:vending_app/features/product_master/data/legacy/legacy_mapped_vending_machine.dart';
import 'package:vending_app/features/product_master/data/legacy/legacy_master_resolution.dart';
import 'package:vending_app/features/product_master/data/legacy/legacy_product_candidate.dart';
import 'package:vending_app/features/product_master/domain/value_objects/master_id.dart';
import 'package:vending_app/features/vending_machine/data/legacy/legacy_vending_machine_domain_bridge.dart';
import 'package:vending_app/features/vending_machine/domain/entities/vending_machine_enums.dart';

void main() {
  test('解決済み旧商品をv2 Domain商品へまとめて変換する', () {
    final result = LegacyVendingMachineDomainBridge.toDomain(
      LegacyMappedVendingMachine(
        id: 'legacy_001',
        schemaVersion: 1,
        name: '旧自販機',
        manufacturer: LegacyResolvedManufacturer(
          rawName: 'サントリー',
          manufacturerId: ManufacturerId.parse('suntory'),
          kind: LegacyManufacturerResolutionKind.normalizedName,
        ),
        latitude: 35.68,
        longitude: 139.76,
        products: <LegacyResolvedProduct>[
          LegacyResolvedProduct(
            rawName: 'ボスブラック',
            productId: ProductId.parse('suntory_boss_black'),
            kind: LegacyProductResolutionKind.manualAlias,
            source: LegacyProductSource.products,
            tags: const <String>[],
            isSoldOut: true,
          ),
          LegacyResolvedProduct(
            rawName: 'BOSS ブラック',
            productId: ProductId.parse('suntory_boss_black'),
            kind: LegacyProductResolutionKind.normalizedName,
            source: LegacyProductSource.drinkSlots,
            tags: const <String>[],
            isSoldOut: false,
          ),
          const LegacyResolvedProduct(
            rawName: 'BOSS',
            productId: null,
            kind: LegacyProductResolutionKind.unresolved,
            source: LegacyProductSource.products,
            tags: <String>[],
            isSoldOut: false,
          ),
        ],
        createdAt: null,
        updatedAt: null,
        lastCheckedAt: null,
        address: '東京都',
        locationName: '駅前',
        imageUrl: null,
        note: null,
        tags: const <String>[],
        cashlessSupported: false,
      ),
    );

    expect(result.failureOrNull, isNull);
    expect(result.valueOrNull?.unresolvedProductCount, 1);

    final machine = result.valueOrNull?.machine;
    expect(machine?.schemaVersion, 1);
    expect(machine?.manufacturerStatus, ManufacturerStatus.confirmed);
    expect(machine?.dataLevel, VendingMachineDataLevel.productsConfirmed);
    expect(machine?.products, hasLength(1));
    expect(
      machine?.products.single.availability,
      ProductAvailability.available,
    );
    expect(
      machine?.products.single.evidenceType,
      ProductEvidenceType.manualConfirmed,
    );
    expect(machine?.placeDescription, '駅前');
  });

  test('位置を持たない旧文書はValidationFailureにする', () {
    final result = LegacyVendingMachineDomainBridge.toDomain(
      const LegacyMappedVendingMachine(
        id: 'legacy_002',
        schemaVersion: 1,
        name: '位置不明',
        manufacturer: LegacyResolvedManufacturer(
          rawName: null,
          manufacturerId: null,
          kind: LegacyManufacturerResolutionKind.unresolved,
        ),
        latitude: null,
        longitude: null,
        products: <LegacyResolvedProduct>[],
        createdAt: null,
        updatedAt: null,
        lastCheckedAt: null,
        address: null,
        locationName: null,
        imageUrl: null,
        note: null,
        tags: <String>[],
        cashlessSupported: false,
      ),
    );

    expect(result.failureOrNull?.code, 'validation.invalid');
  });
}
