import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vending_app/features/home_map/domain/value_objects/map_viewport_bounds.dart';
import 'package:vending_app/features/product_master/domain/value_objects/master_id.dart';
import 'package:vending_app/features/product_search/data/repositories/machine_product_index_repository_impl.dart';
import 'package:vending_app/features/product_search/data/sources/machine_product_index_document.dart';
import 'package:vending_app/features/product_search/data/sources/machine_product_index_source.dart';

void main() {
  test('Product IDとviewportに合うactive indexだけ返す', () async {
    final repository = MachineProductIndexRepositoryImpl(
      source: _FakeIndexSource(<MachineProductIndexDocument>[
        _document(
          id: 'confirmed',
          machineId: 'machine_1',
          productId: 'suntory_boss_black',
          evidenceType: 'manual_confirmed',
        ),
        _document(
          id: 'other_product',
          machineId: 'machine_2',
          productId: 'suntory_tennensui',
          evidenceType: 'manual_confirmed',
        ),
        _document(
          id: 'inactive',
          machineId: 'machine_3',
          productId: 'suntory_boss_black',
          evidenceType: 'manual_confirmed',
          isActive: false,
        ),
        _document(
          id: 'outside',
          machineId: 'machine_4',
          productId: 'suntory_boss_black',
          evidenceType: 'manual_confirmed',
          latitude: 34.0,
          longitude: 135.0,
        ),
      ]),
    );

    final result = await repository.findByProductInViewport(
      productId: ProductId.parse('suntory_boss_black'),
      viewport: MapViewportBounds(
        south: 35.6,
        west: 139.6,
        north: 35.8,
        east: 139.9,
      ),
    );

    expect(result.failureOrNull, isNull);
    expect(result.valueOrNull, hasLength(1));
    expect(result.valueOrNull!.single.machineId.value, 'machine_1');
  });

  test('同一machine重複時はconfirmedを優先する', () async {
    final repository = MachineProductIndexRepositoryImpl(
      source: _FakeIndexSource(<MachineProductIndexDocument>[
        _document(
          id: 'inferred',
          machineId: 'machine_1',
          productId: 'suntory_boss_black',
          evidenceType: 'manufacturer_inferred',
        ),
        _document(
          id: 'confirmed',
          machineId: 'machine_1',
          productId: 'suntory_boss_black',
          evidenceType: 'photo_confirmed',
        ),
      ]),
    );

    final result = await repository.findByProductInViewport(
      productId: ProductId.parse('suntory_boss_black'),
      viewport: MapViewportBounds(
        south: 35.6,
        west: 139.6,
        north: 35.8,
        east: 139.9,
      ),
    );

    expect(result.valueOrNull, hasLength(1));
    expect(result.valueOrNull!.single.isConfirmed, isTrue);
  });

  test('壊れたindex documentは静かに無視せずFailureにする', () async {
    final repository = MachineProductIndexRepositoryImpl(
      source: _FakeIndexSource(<MachineProductIndexDocument>[
        MachineProductIndexDocument(
          id: 'broken',
          data: <String, dynamic>{'machineId': 'machine_1'},
        ),
      ]),
    );

    final result = await repository.findByProductInViewport(
      productId: ProductId.parse('suntory_boss_black'),
      viewport: MapViewportBounds(
        south: 35.6,
        west: 139.6,
        north: 35.8,
        east: 139.9,
      ),
    );

    expect(result.isFailure, isTrue);
  });
}

MachineProductIndexDocument _document({
  required String id,
  required String machineId,
  required String productId,
  required String evidenceType,
  bool isActive = true,
  double latitude = 35.681236,
  double longitude = 139.767125,
}) {
  return MachineProductIndexDocument(
    id: id,
    data: <String, dynamic>{
      'machineId': machineId,
      'productId': productId,
      'genreIds': <String>['coffee'],
      'location': GeoPoint(latitude, longitude),
      'geohash': latitude > 35 ? 'xn76ur' : 'xn0',
      'evidenceType': evidenceType,
      'availability': 'available',
      'isActive': isActive,
      'machineStatus': 'active',
      'machineUpdatedAt': DateTime.utc(2026, 8, 7),
      'updatedAt': DateTime.utc(2026, 8, 7),
    },
  );
}

final class _FakeIndexSource implements MachineProductIndexSource {
  _FakeIndexSource(this.documents);

  final List<MachineProductIndexDocument> documents;

  @override
  Future<List<MachineProductIndexDocument>> fetchByProductAndGeohashPrefixes({
    required ProductId productId,
    required Set<String> geohashPrefixes,
  }) async {
    return documents;
  }
}
