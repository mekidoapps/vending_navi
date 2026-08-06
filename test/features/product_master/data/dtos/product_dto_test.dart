import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vending_app/features/product_master/data/dtos/product_dto.dart';

void main() {
  final createdAt = DateTime.utc(2026, 8, 1);
  final updatedAt = DateTime.utc(2026, 8, 6);

  test('FirestoreデータとドキュメントIDからDTOを生成できる', () {
    final dto = ProductDto.fromFirestoreDocument(
      documentId: 'coca_cola_ayataka',
      data: <String, dynamic>{
        'name': '綾鷹',
        'manufacturerId': 'coca_cola',
        'searchKeywords': <String>['あやたか'],
        'genreIds': <String>['green_tea'],
        'imageUrl': null,
        'isActive': true,
        'createdAt': Timestamp.fromDate(createdAt),
        'updatedAt': Timestamp.fromDate(updatedAt),
      },
    );

    expect(dto.documentId, 'coca_cola_ayataka');
    expect(dto.createdAt, createdAt);
    expect(dto.updatedAt, updatedAt);
  });

  test('Firestore書き出し時はdocumentIdを含めず日時をTimestampにする', () {
    final dto = ProductDto(
      documentId: 'coca_cola_ayataka',
      name: '綾鷹',
      manufacturerId: 'coca_cola',
      genreIds: const <String>['green_tea'],
      createdAt: createdAt,
      updatedAt: updatedAt,
    );

    final data = dto.toFirestoreData();

    expect(data, isNot(contains('documentId')));
    expect(data['createdAt'], isA<Timestamp>());
    expect(data['updatedAt'], isA<Timestamp>());
  });
}
