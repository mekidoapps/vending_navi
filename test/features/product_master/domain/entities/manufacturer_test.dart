import 'package:flutter_test/flutter_test.dart';
import 'package:vending_app/features/product_master/domain/entities/manufacturer.dart';
import 'package:vending_app/features/product_master/domain/value_objects/master_id.dart';

void main() {
  test('正式名・短縮名・キーワードを検索語として扱う', () {
    final manufacturer = Manufacturer(
      id: ManufacturerId.parse('coca_cola'),
      name: 'コカ・コーラ ボトラーズジャパン',
      displayShortName: 'コカ・コーラ',
      searchKeywords: const <String>['coca-cola', ' コカコーラ '],
      presetProductIds: <ProductId>[ProductId.parse('coca_cola_ayataka')],
      createdAt: DateTime.utc(2026, 8, 1),
      updatedAt: DateTime.utc(2026, 8, 6),
    );

    expect(manufacturer.isSelectable, isTrue);
    expect(manufacturer.searchTerms, <String>{
      'コカ・コーラ ボトラーズジャパン',
      'コカ・コーラ',
      'coca-cola',
      'コカコーラ',
    });
  });

  test('無効メーカーは選択候補として扱わない', () {
    final manufacturer = Manufacturer(
      id: ManufacturerId.parse('inactive_brand'),
      name: '無効メーカー',
      displayShortName: '無効',
      isActive: false,
      createdAt: DateTime.utc(2026, 8, 1),
      updatedAt: DateTime.utc(2026, 8, 6),
    );

    expect(manufacturer.isSelectable, isFalse);
  });
}
