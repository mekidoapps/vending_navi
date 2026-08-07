import 'package:flutter_test/flutter_test.dart';
import 'package:vending_app/features/product_master/data/legacy/legacy_master_resolution.dart';
import 'package:vending_app/features/product_master/data/legacy/legacy_vending_machine_compatibility_mapper.dart';
import 'package:vending_app/features/product_master/domain/entities/manufacturer.dart';
import 'package:vending_app/features/product_master/domain/entities/product.dart';
import 'package:vending_app/features/product_master/domain/entities/product_genre.dart';
import 'package:vending_app/features/product_master/domain/value_objects/master_id.dart';

void main() {
  final manufacturer = Manufacturer(
    id: ManufacturerId.parse('coca_cola'),
    name: 'コカ・コーラ',
    displayShortName: 'コカ・コーラ',
    createdAt: DateTime.utc(2026),
    updatedAt: DateTime.utc(2026),
  );
  final product = Product(
    id: ProductId.parse('coca_cola_ayataka'),
    name: '綾鷹',
    manufacturerId: manufacturer.id,
    genres: const <ProductGenre>[ProductGenre.greenTea],
    createdAt: DateTime.utc(2026),
    updatedAt: DateTime.utc(2026),
  );

  test('変換可能商品と未解決商品を同じ自販機内で保持する', () {
    final result = LegacyVendingMachineCompatibilityMapper.fromDocumentData(
      documentId: 'legacy-machine-1',
      data: <String, dynamic>{
        'manufacturer': 'コカ・コーラ',
        'latitude': 35.6,
        'longitude': 140.1,
        'drinks': <String>['綾鷹', 'マスタ外の商品'],
      },
      products: <Product>[product],
      manufacturers: <Manufacturer>[manufacturer],
    );

    expect(result.isSuccess, isTrue);
    final machine = result.valueOrNull!;
    expect(machine.manufacturer.manufacturerId?.value, 'coca_cola');
    expect(machine.products, hasLength(2));
    expect(machine.products.first.productId?.value, 'coca_cola_ayataka');
    expect(machine.products.last.kind, LegacyProductResolutionKind.unresolved);
    expect(machine.products.last.rawName, 'マスタ外の商品');
    expect(machine.unresolvedProductCount, 1);
    expect(machine.hasUsableLocation, isTrue);
  });

  test('位置とTimestampが欠損してもクラッシュせず読み込み成功する', () {
    final result = LegacyVendingMachineCompatibilityMapper.fromDocumentData(
      documentId: 'legacy-machine-2',
      data: <String, dynamic>{
        'name': '駅前',
        'drinks': <Object?>['綾鷹'],
      },
      products: <Product>[product],
      manufacturers: <Manufacturer>[manufacturer],
    );

    expect(result.isSuccess, isTrue);
    final machine = result.valueOrNull!;
    expect(machine.latitude, isNull);
    expect(machine.longitude, isNull);
    expect(machine.createdAt, isNull);
    expect(machine.hasUsableLocation, isFalse);
  });

  test('空documentIdだけはValidationFailureにする', () {
    final result = LegacyVendingMachineCompatibilityMapper.fromDocumentData(
      documentId: '   ',
      data: const <String, dynamic>{},
      products: <Product>[product],
      manufacturers: <Manufacturer>[manufacturer],
    );

    expect(result.isFailure, isTrue);
    expect(result.failureOrNull?.code, 'validation.invalid');
  });
}
