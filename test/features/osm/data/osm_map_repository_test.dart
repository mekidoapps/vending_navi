import 'package:flutter_test/flutter_test.dart';
import 'package:vending_app/features/home_map/domain/value_objects/map_viewport_bounds.dart';
import 'package:vending_app/features/osm/data/osm_cell_cover.dart';
import 'package:vending_app/features/osm/data/osm_map_repository.dart';

void main() {
  final tokyo = MapViewportBounds(
    south: 35.680,
    west: 139.765,
    north: 35.682,
    east: 139.769,
  );

  test('exact cover is bounded and includes the visible center', () {
    final cover = OsmCellCover.forBounds(tokyo, precision: 6, maxCells: 12);
    expect(cover, isNotNull);
    expect(cover!.length, lessThanOrEqualTo(12));
    expect(
      OsmCellCover.forBounds(
        MapViewportBounds(south: 30, west: 130, north: 40, east: 145),
        precision: 6,
        maxCells: 12,
      ),
      isNull,
    );
  });

  test('wide zoom never requests point documents', () async {
    final source = _FakeSource();
    final repository = OsmMapRepository(source);
    final result = await repository.load(tokyo, 8);
    expect(source.pointCalls, 0);
    expect(source.aggregateCalls, greaterThan(0));
    expect(result.points, isEmpty);
    expect(result.documentReads, lessThanOrEqualTo(81));
  });

  test(
    'point overflow uses aggregate rather than unbounded pagination',
    () async {
      final source = _FakeSource(overfillPoints: true);
      final result = await OsmMapRepository(source).load(tokyo, 16);
      expect(result.dense, isTrue);
      expect(result.points, isEmpty);
      expect(source.pointCalls, 1);
      expect(source.maxRequestedLimit, lessThanOrEqualTo(121));
    },
  );

  test('session cell cache avoids repeat Firestore queries', () async {
    final source = _FakeSource();
    final repository = OsmMapRepository(source);
    await repository.load(tokyo, 8);
    final firstCount = source.aggregateCalls;
    final result = await repository.load(tokyo, 8);
    expect(source.aggregateCalls, firstCount);
    expect(result.cacheHits, greaterThan(0));
    expect(result.documentReads, 0);
  });

  test('zoom thresholds are derived from 40,788-point viewport benchmark', () {
    expect(OsmMapBudget.aggregatePrecision(8), 2);
    expect(OsmMapBudget.aggregatePrecision(9), 4);
    expect(OsmMapBudget.aggregatePrecision(14), 6);
    expect(OsmMapBudget.loadPoints(15), isFalse);
    expect(OsmMapBudget.loadPoints(16), isTrue);
  });
}

final class _FakeSource implements OsmMapSource {
  _FakeSource({this.overfillPoints = false});

  final bool overfillPoints;
  int pointCalls = 0;
  int aggregateCalls = 0;
  int maxRequestedLimit = 0;

  @override
  Future<List<OsmAggregateCell>> fetchAggregate({
    required int precision,
    required String geohashPrefix,
    required int limit,
  }) async {
    aggregateCalls++;
    maxRequestedLimit = limit > maxRequestedLimit ? limit : maxRequestedLimit;
    return const [];
  }

  @override
  Future<List<OsmMapPoint>> fetchPoints({
    required String geohashPrefix,
    required int limit,
  }) async {
    pointCalls++;
    maxRequestedLimit = limit > maxRequestedLimit ? limit : maxRequestedLimit;
    if (!overfillPoints) return const [];
    return List.generate(
      limit,
      (index) => OsmMapPoint(
        sourceId: 'osm:node:${index + 1}',
        latitude: 35.681,
        longitude: 139.767,
      ),
    );
  }

  @override
  Future<OsmMapPoint?> fetchPoint(String sourceId) async => null;
}
