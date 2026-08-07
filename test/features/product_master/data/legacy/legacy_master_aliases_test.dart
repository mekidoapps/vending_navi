import 'package:flutter_test/flutter_test.dart';
import 'package:vending_app/features/product_master/data/fixtures/product_master_fixture.dart';
import 'package:vending_app/features/product_master/data/legacy/legacy_master_aliases.dart';
import 'package:vending_app/features/product_master/data/legacy/legacy_master_resolution.dart';
import 'package:vending_app/features/product_master/data/legacy/legacy_master_resolver.dart';
import 'package:vending_app/features/product_master/data/legacy/legacy_product_candidate.dart';

void main() {
  test('旧メーカー表記を固定Manufacturer IDへ解決できる', () {
    final resolved = LegacyMasterResolver.resolveManufacturer(
      legacyName: 'コカコーラ',
      manufacturers: ProductMasterFixture.manufacturers,
      manualAliases: LegacyMasterAliases.manufacturerAliases,
    );

    expect(resolved.manufacturerId?.value, 'coca_cola');
    expect(resolved.kind, LegacyManufacturerResolutionKind.manualAlias);
  });

  test('メーカー付き曖昧商品名を手動aliasで解決できる', () {
    final manufacturer = LegacyMasterResolver.resolveManufacturer(
      legacyName: 'サントリー',
      manufacturers: ProductMasterFixture.manufacturers,
      manualAliases: LegacyMasterAliases.manufacturerAliases,
    );

    final resolved = LegacyMasterResolver.resolveProduct(
      candidate: const LegacyProductCandidate(
        rawName: '天然水',
        source: LegacyProductSource.products,
      ),
      products: ProductMasterFixture.products,
      manufacturer: manufacturer,
      manualAliases: LegacyMasterAliases.productAliases,
    );

    expect(resolved.productId?.value, 'suntory_tennensui');
  });

  test('その他は正式メーカーへ変換しない', () {
    final resolved = LegacyMasterResolver.resolveManufacturer(
      legacyName: 'その他',
      manufacturers: ProductMasterFixture.manufacturers,
      manualAliases: LegacyMasterAliases.manufacturerAliases,
    );

    expect(resolved.manufacturerId, isNull);
    expect(resolved.kind, LegacyManufacturerResolutionKind.unresolved);
  });

  test('曖昧なBOSS単独表記はブラックへ自動変換しない', () {
    final manufacturer = LegacyMasterResolver.resolveManufacturer(
      legacyName: 'サントリー',
      manufacturers: ProductMasterFixture.manufacturers,
      manualAliases: LegacyMasterAliases.manufacturerAliases,
    );

    final resolved = LegacyMasterResolver.resolveProduct(
      candidate: const LegacyProductCandidate(
        rawName: 'BOSS',
        source: LegacyProductSource.products,
      ),
      products: ProductMasterFixture.products,
      manufacturer: manufacturer,
      manualAliases: LegacyMasterAliases.productAliases,
    );

    expect(resolved.productId, isNull);
    expect(resolved.kind, LegacyProductResolutionKind.unresolved);
  });
}
