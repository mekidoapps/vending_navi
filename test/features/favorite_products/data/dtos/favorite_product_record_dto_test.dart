import 'package:flutter_test/flutter_test.dart';
import 'package:vending_app/features/favorite_products/data/dtos/favorite_product_record_dto.dart';

void main() {
  test('document idとProduct IDが一致するrecordを読む', () {
    final dto = FavoriteProductRecordDto.fromFirestore(
      documentId: 'ayataka',
      data: const <String, dynamic>{'productId': 'ayataka', 'sortOrder': 2},
    );

    expect(dto.productId, 'ayataka');
    expect(dto.sortOrder, 2);
  });

  test('document idとProduct IDが違うrecordを拒否する', () {
    expect(
      () => FavoriteProductRecordDto.fromFirestore(
        documentId: 'ayataka',
        data: const <String, dynamic>{'productId': 'irohasu', 'sortOrder': 0},
      ),
      throwsFormatException,
    );
  });
}
