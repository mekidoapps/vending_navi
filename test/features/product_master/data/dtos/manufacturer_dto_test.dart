import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vending_app/features/product_master/data/dtos/manufacturer_dto.dart';

void main() {
  final createdAt = DateTime.utc(2026, 8, 1);
  final updatedAt = DateTime.utc(2026, 8, 6);

  test('FirestoreデータとドキュメントIDからDTOを生成できる', () {
    final dto = ManufacturerDto.fromFirestoreDocument(
      documentId: 'coca_cola',
      data: <String, dynamic>{
        'name': 'コカ・コーラ ボトラーズジャパン',
        'displayShortName': 'コカ・コーラ',
        'searchKeywords': <String>['coca-cola'],
        'presetProductIds': <String>['coca_cola_ayataka'],
        'isActive': true,
        'createdAt': Timestamp.fromDate(createdAt),
        'updatedAt': Timestamp.fromDate(updatedAt),
      },
    );

    expect(dto.documentId, 'coca_cola');
    expect(dto.createdAt, createdAt);
    expect(dto.updatedAt, updatedAt);
  });

  test('Firestore書き出し時はdocumentIdを含めない', () {
    final dto = ManufacturerDto(
      documentId: 'coca_cola',
      name: 'コカ・コーラ ボトラーズジャパン',
      displayShortName: 'コカ・コーラ',
      createdAt: createdAt,
      updatedAt: updatedAt,
    );

    expect(dto.toFirestoreData(), isNot(contains('documentId')));
  });
}
