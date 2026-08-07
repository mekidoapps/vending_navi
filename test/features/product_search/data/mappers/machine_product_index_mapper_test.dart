import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vending_app/features/product_search/data/mappers/machine_product_index_mapper.dart';
import 'package:vending_app/features/vending_machine/domain/entities/vending_machine_enums.dart';

void main() {
  test('Firestore index documentをDomainへ変換する', () {
    final result = MachineProductIndexMapper.fromFirestoreDocument(
      documentId: 'opaque_index_id',
      data: <String, dynamic>{
        'machineId': 'machine_v2_station_east',
        'productId': 'suntory_boss_black',
        'genreIds': <String>['coffee'],
        'location': const GeoPoint(35.681236, 139.767125),
        'geohash': 'xn76ur',
        'evidenceType': 'manual_confirmed',
        'availability': 'available',
        'isActive': true,
        'machineStatus': 'active',
        'machineUpdatedAt': DateTime.utc(2026, 8, 7),
        'updatedAt': DateTime.utc(2026, 8, 7),
      },
    );

    expect(result.failureOrNull, isNull);
    expect(result.valueOrNull?.machineId.value, 'machine_v2_station_east');
    expect(result.valueOrNull?.productId.value, 'suntory_boss_black');
    expect(result.valueOrNull?.isConfirmed, isTrue);
    expect(result.valueOrNull?.availability, ProductAvailability.available);
  });

  test('未知Genreを拒否する', () {
    final result = MachineProductIndexMapper.fromFirestoreDocument(
      documentId: 'opaque_index_id',
      data: <String, dynamic>{
        'machineId': 'machine_v2_station_east',
        'productId': 'suntory_boss_black',
        'genreIds': <String>['future_genre'],
        'location': const GeoPoint(35.681236, 139.767125),
        'geohash': 'xn76ur',
        'evidenceType': 'manual_confirmed',
        'availability': 'available',
        'isActive': true,
        'machineStatus': 'active',
        'machineUpdatedAt': DateTime.utc(2026, 8, 7),
        'updatedAt': DateTime.utc(2026, 8, 7),
      },
    );

    expect(result.isFailure, isTrue);
  });

  test('未知evidenceTypeを拒否する', () {
    final result = MachineProductIndexMapper.fromFirestoreDocument(
      documentId: 'opaque_index_id',
      data: <String, dynamic>{
        'machineId': 'machine_v2_station_east',
        'productId': 'suntory_boss_black',
        'genreIds': <String>['coffee'],
        'location': const GeoPoint(35.681236, 139.767125),
        'geohash': 'xn76ur',
        'evidenceType': 'ai_unconfirmed',
        'availability': 'unknown',
        'isActive': true,
        'machineStatus': 'active',
        'machineUpdatedAt': DateTime.utc(2026, 8, 7),
        'updatedAt': DateTime.utc(2026, 8, 7),
      },
    );

    expect(result.isFailure, isTrue);
  });
}
