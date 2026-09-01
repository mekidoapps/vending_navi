import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vending_app/core/errors/app_failure.dart';
import 'package:vending_app/features/vending_machine/data/mappers/vending_machine_product_mapper.dart';
import 'package:vending_app/features/vending_machine/domain/entities/vending_machine_enums.dart';

void main() {
  group('VendingMachineProductMapper', () {
    test('確認済み商品をDomainへ変換する', () {
      final time = DateTime.utc(2026, 8, 7, 3);

      final result = VendingMachineProductMapper.fromFirestoreDocument(
        documentId: 'suntory_boss_black',
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

      expect(result.failureOrNull, isNull);
      expect(result.valueOrNull?.isConfirmed, isTrue);
      expect(result.valueOrNull?.confirmedBy, isNull);
      expect(result.valueOrNull?.availability, ProductAvailability.available);
    });

    test('メーカー推定商品をあるかも判定用に保持する', () {
      final time = DateTime.utc(2026, 8, 7, 3);

      final result = VendingMachineProductMapper.fromFirestoreDocument(
        documentId: 'suntory_tennensui',
        data: <String, dynamic>{
          'productId': 'suntory_tennensui',
          'evidenceType': 'manufacturer_inferred',
          'availability': 'unknown',
          'isActive': true,
          'confirmedBy': null,
          'confirmedAt': null,
          'createdAt': Timestamp.fromDate(time),
          'updatedAt': Timestamp.fromDate(time),
        },
      );

      expect(result.failureOrNull, isNull);
      expect(result.valueOrNull?.isInferred, isTrue);
      expect(result.valueOrNull?.isConfirmed, isFalse);
    });

    test('documentIdとproductIdが違う文書を拒否する', () {
      final time = DateTime.utc(2026, 8, 7, 3);

      final result = VendingMachineProductMapper.fromFirestoreDocument(
        documentId: 'suntory_boss_black',
        data: <String, dynamic>{
          'productId': 'suntory_tennensui',
          'evidenceType': 'manual_confirmed',
          'availability': 'available',
          'isActive': true,
          'confirmedBy': 'test_uid',
          'confirmedAt': Timestamp.fromDate(time),
          'createdAt': Timestamp.fromDate(time),
          'updatedAt': Timestamp.fromDate(time),
        },
      );

      expect(result.failureOrNull, isA<ValidationFailure>());
    });
  });
}
