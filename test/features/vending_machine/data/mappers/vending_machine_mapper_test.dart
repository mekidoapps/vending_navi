import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vending_app/core/errors/app_failure.dart';
import 'package:vending_app/features/vending_machine/data/mappers/vending_machine_mapper.dart';
import 'package:vending_app/features/vending_machine/domain/entities/vending_machine_enums.dart';

void main() {
  group('VendingMachineMapper', () {
    test('schemaVersion=2のFirestore文書をDomainへ変換する', () {
      final result = VendingMachineMapper.fromFirestoreDocument(
        documentId: 'machine_001',
        data: _validDocument(),
      );

      expect(result.failureOrNull, isNull);

      final machine = result.valueOrNull;
      expect(machine?.id.value, 'machine_001');
      expect(machine?.manufacturerId?.value, 'suntory');
      expect(machine?.manufacturerStatus, ManufacturerStatus.confirmed);
      expect(machine?.location.latitude, 35.681236);
      expect(machine?.dataLevel, VendingMachineDataLevel.productsConfirmed);
      expect(machine?.products, isEmpty);
    });

    test('未知のstatusはValidationFailureにする', () {
      final data = _validDocument()..['status'] = 'mystery';

      final result = VendingMachineMapper.fromFirestoreDocument(
        documentId: 'machine_001',
        data: data,
      );

      expect(result.failureOrNull, isA<ValidationFailure>());
    });

    test('schemaVersion=1はv2 Mapperで黙って補正しない', () {
      final data = _validDocument()..['schemaVersion'] = 1;

      final result = VendingMachineMapper.fromFirestoreDocument(
        documentId: 'machine_001',
        data: data,
      );

      expect(result.failureOrNull, isA<ValidationFailure>());
    });

    test('不正座標はValidationFailureにする', () {
      final data = _validDocument()..['location'] = 'invalid_location';

      final result = VendingMachineMapper.fromFirestoreDocument(
        documentId: 'machine_001',
        data: data,
      );

      expect(result.failureOrNull, isA<ValidationFailure>());
    });
  });
}

Map<String, dynamic> _validDocument() {
  final createdAt = DateTime.utc(2026, 8, 7, 1);
  final updatedAt = DateTime.utc(2026, 8, 7, 2);

  return <String, dynamic>{
    'schemaVersion': 2,
    'name': '駅前の自販機',
    'manufacturerId': 'suntory',
    'manufacturerStatus': 'confirmed',
    'location': const GeoPoint(35.681236, 139.767125),
    'geohash': 'xn76ur',
    'placeDescription': '駅東口の壁沿い',
    'installationType': 'outdoor',
    'status': 'active',
    'mergedIntoMachineId': null,
    'dataLevel': 'productsConfirmed',
    'primaryPhotoId': null,
    'createdBy': 'test_uid',
    'createdAt': Timestamp.fromDate(createdAt),
    'updatedAt': Timestamp.fromDate(updatedAt),
    'lastProductUpdatedAt': Timestamp.fromDate(updatedAt),
  };
}
