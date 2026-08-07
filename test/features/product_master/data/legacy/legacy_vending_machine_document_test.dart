import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vending_app/features/product_master/data/legacy/legacy_product_candidate.dart';
import 'package:vending_app/features/product_master/data/legacy/legacy_vending_machine_document.dart';

void main() {
  group('LegacyVendingMachineDocument', () {
    test('productsを最優先で読み取り旧lat/lngとTimestampを吸収する', () {
      final time = DateTime.utc(2026, 8, 1, 10);
      final document = LegacyVendingMachineDocument.fromDocumentData(
        documentId: 'machine-1',
        data: <String, dynamic>{
          'lat': '35.6',
          'lng': 140,
          'manufacturer': ' コカ・コーラ ',
          'products': <Object?>[
            <String, dynamic>{
              'productId': 'coca_cola_ayataka',
              'name': ' 綾鷹 ',
              'tags': <String>['お茶', 'お茶', ' 無糖 '],
              'isSoldOut': true,
            },
          ],
          'drinkSlots': <Object?>['別の商品'],
          'createdAt': Timestamp.fromDate(time),
        },
      );

      expect(document.schemaVersion, 1);
      expect(document.latitude, 35.6);
      expect(document.longitude, 140.0);
      expect(document.manufacturer, 'コカ・コーラ');
      expect(document.createdAt, time);
      expect(document.updatedAt, time);
      expect(document.products, hasLength(1));
      expect(document.products.single.source, LegacyProductSource.products);
      expect(document.products.single.rawName, '綾鷹');
      expect(document.products.single.isSoldOut, isTrue);
      expect(document.products.single.tags, <String>['お茶', '無糖']);
    });

    test('productsが使えない場合drinkSlots slots drinksの順でフォールバックする', () {
      final document = LegacyVendingMachineDocument.fromDocumentData(
        documentId: 'machine-2',
        data: <String, dynamic>{
          'products': const <Object?>[],
          'drinkSlots': const <Object?>[],
          'slots': <Object?>[
            <String, dynamic>{'name': 'BOSS ブラック'},
          ],
          'drinks': <Object?>['綾鷹'],
        },
      );

      expect(document.products, hasLength(1));
      expect(document.products.single.source, LegacyProductSource.slots);
      expect(document.products.single.rawName, 'BOSS ブラック');
    });

    test('GeoPointと欠損Timestampを安全に扱う', () {
      final document = LegacyVendingMachineDocument.fromDocumentData(
        documentId: 'machine-3',
        data: <String, dynamic>{
          'location': const GeoPoint(35.0, 139.0),
          'drinks': <Object?>['綾鷹', '', null],
        },
      );

      expect(document.latitude, 35.0);
      expect(document.longitude, 139.0);
      expect(document.createdAt, isNull);
      expect(document.updatedAt, isNull);
      expect(document.lastCheckedAt, isNull);
      expect(document.products, hasLength(1));
    });
  });
}
