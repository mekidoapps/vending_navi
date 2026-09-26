import 'package:cloud_firestore/cloud_firestore.dart';

import '../../home_map/domain/value_objects/map_viewport_bounds.dart';
import 'osm_cell_cover.dart';

/// Budgets are based on the locked 40,788-point seed density benchmark.
abstract final class OsmMapBudget {
  static const int pointDocuments = 120;
  static const int aggregateCells = 80;
  static const int totalMarkers = 200;
  static const int maxCellQueries = 12;
  static const int pointCacheEntries = 32;
  static const int aggregateCacheEntries = 128;
  static const double viewportPadding = 0.10;
  static const Duration cameraDebounce = Duration(milliseconds: 180);

  static int aggregatePrecision(double zoom) {
    if (zoom < 9) return 2;
    if (zoom < 14) return 4;
    return 6;
  }

  static bool loadPoints(double zoom) => zoom >= 16;
}

final class OsmMapPoint {
  const OsmMapPoint({
    required this.sourceId,
    required this.latitude,
    required this.longitude,
    this.brand,
    this.operator,
  });

  final String sourceId;
  final double latitude;
  final double longitude;
  final String? brand;
  final String? operator;

  factory OsmMapPoint.fromData(String id, Map<String, dynamic> data) {
    return OsmMapPoint(
      sourceId: id,
      latitude: (data['latitude'] as num).toDouble(),
      longitude: (data['longitude'] as num).toDouble(),
      brand: data['rawBrand'] as String?,
      operator: data['rawOperator'] as String?,
    );
  }
}

final class OsmAggregateCell {
  const OsmAggregateCell({
    required this.cellId,
    required this.count,
    required this.latitude,
    required this.longitude,
    required this.south,
    required this.west,
    required this.north,
    required this.east,
  });

  final String cellId;
  final int count;
  final double latitude;
  final double longitude;
  final double south;
  final double west;
  final double north;
  final double east;

  bool intersects(MapViewportBounds bounds) =>
      south <= bounds.north &&
      north >= bounds.south &&
      (bounds.west <= bounds.east
          ? west <= bounds.east && east >= bounds.west
          : east >= bounds.west || west <= bounds.east);

  factory OsmAggregateCell.fromData(String id, Map<String, dynamic> data) {
    final center = data['center'] as Map<String, dynamic>;
    final bounds = data['bounds'] as Map<String, dynamic>;
    return OsmAggregateCell(
      cellId: id,
      count: data['count'] as int,
      latitude: (center['latitude'] as num).toDouble(),
      longitude: (center['longitude'] as num).toDouble(),
      south: (bounds['south'] as num).toDouble(),
      west: (bounds['west'] as num).toDouble(),
      north: (bounds['north'] as num).toDouble(),
      east: (bounds['east'] as num).toDouble(),
    );
  }
}

abstract interface class OsmMapSource {
  Future<List<OsmAggregateCell>> fetchAggregate({
    required int precision,
    required String geohashPrefix,
    required int limit,
  });

  Future<List<OsmMapPoint>> fetchPoints({
    required String geohashPrefix,
    required int limit,
  });

  Future<OsmMapPoint?> fetchPoint(String sourceId);
}

final class FirestoreOsmMapSource implements OsmMapSource {
  FirestoreOsmMapSource(this._firestore);

  final FirebaseFirestore _firestore;

  @override
  Future<List<OsmAggregateCell>> fetchAggregate({
    required int precision,
    required String geohashPrefix,
    required int limit,
  }) async {
    final snapshot = await _firestore
        .collection('osm_vending_aggregate')
        .where('status', isEqualTo: 'published')
        .where('precision', isEqualTo: precision)
        .where('geohash', isGreaterThanOrEqualTo: geohashPrefix)
        .where('geohash', isLessThanOrEqualTo: '$geohashPrefix\uf8ff')
        .limit(limit)
        .get();
    return snapshot.docs
        .map((doc) => OsmAggregateCell.fromData(doc.id, doc.data()))
        .toList(growable: false);
  }

  @override
  Future<List<OsmMapPoint>> fetchPoints({
    required String geohashPrefix,
    required int limit,
  }) async {
    final snapshot = await _firestore
        .collection('osm_vending_seed')
        .where('status', isEqualTo: 'published')
        .where('geohash', isGreaterThanOrEqualTo: geohashPrefix)
        .where('geohash', isLessThanOrEqualTo: '$geohashPrefix\uf8ff')
        .limit(limit)
        .get();
    return snapshot.docs
        .map((doc) => OsmMapPoint.fromData(doc.id, doc.data()))
        .toList(growable: false);
  }

  @override
  Future<OsmMapPoint?> fetchPoint(String sourceId) async {
    final doc = await _firestore
        .collection('osm_vending_seed')
        .doc(sourceId)
        .get();
    final data = doc.data();
    if (data == null || data['status'] != 'published') return null;
    return OsmMapPoint.fromData(doc.id, data);
  }
}

final class OsmMapResult {
  const OsmMapResult({
    this.points = const [],
    this.cells = const [],
    this.dense = false,
    this.queryCount = 0,
    this.documentReads = 0,
    this.cacheHits = 0,
    this.elapsed = Duration.zero,
  });

  final List<OsmMapPoint> points;
  final List<OsmAggregateCell> cells;
  final bool dense;
  final int queryCount;
  final int documentReads;
  final int cacheHits;
  final Duration elapsed;
}

/// Session-scoped cache. Never stores Firestore snapshots or raw OSM tags.
final class OsmMapRepository {
  OsmMapRepository(this._source);

  final OsmMapSource _source;
  final Map<String, List<OsmAggregateCell>> _aggregateCache = {};
  final Map<String, List<OsmMapPoint>> _pointCache = {};

  Future<OsmMapResult> load(MapViewportBounds viewport, double zoom) async {
    final timer = Stopwatch()..start();
    final bounds = _padded(viewport);
    var queries = 0;
    var reads = 0;
    var hits = 0;

    if (OsmMapBudget.loadPoints(zoom)) {
      final prefixes = OsmCellCover.forBounds(
        bounds,
        precision: 6,
        maxCells: OsmMapBudget.maxCellQueries,
      );
      if (prefixes != null) {
        final points = <String, OsmMapPoint>{};
        var overflow = false;
        for (final prefix in prefixes.toList()..sort()) {
          final cached = _pointCache[prefix];
          final remaining = OsmMapBudget.pointDocuments - points.length;
          if (remaining < 0) {
            overflow = true;
            break;
          }
          final batch =
              cached ??
              await _source.fetchPoints(
                geohashPrefix: prefix,
                limit: remaining + 1,
              );
          if (cached == null) {
            queries++;
            reads += batch.length;
            if (batch.length < remaining + 1) {
              _store(
                _pointCache,
                prefix,
                batch,
                OsmMapBudget.pointCacheEntries,
              );
            }
          } else {
            hits++;
          }
          for (final point in batch) {
            points[point.sourceId] = point;
          }
          if (points.length > OsmMapBudget.pointDocuments) {
            overflow = true;
            break;
          }
        }
        if (!overflow) {
          timer.stop();
          return OsmMapResult(
            points: points.values
                .where(
                  (point) => bounds.contains(
                    latitude: point.latitude,
                    longitude: point.longitude,
                  ),
                )
                .toList(growable: false),
            queryCount: queries,
            documentReads: reads,
            cacheHits: hits,
            elapsed: timer.elapsed,
          );
        }
      }
    }

    var precision = OsmMapBudget.aggregatePrecision(zoom);
    while (precision >= 2) {
      final prefixes = OsmCellCover.forBounds(
        bounds,
        precision: precision - 1,
        maxCells: OsmMapBudget.maxCellQueries,
      );
      if (prefixes == null) {
        precision -= 2;
        continue;
      }
      final cells = <String, OsmAggregateCell>{};
      var overflow = false;
      for (final prefix in prefixes.toList()..sort()) {
        final key = '$precision:$prefix';
        final cached = _aggregateCache[key];
        final remaining = OsmMapBudget.aggregateCells - cells.length;
        final batch =
            cached ??
            await _source.fetchAggregate(
              precision: precision,
              geohashPrefix: prefix,
              limit: remaining + 1,
            );
        if (cached == null) {
          queries++;
          reads += batch.length;
          if (batch.length < remaining + 1) {
            _store(
              _aggregateCache,
              key,
              batch,
              OsmMapBudget.aggregateCacheEntries,
            );
          }
        } else {
          hits++;
        }
        for (final cell in batch) {
          cells[cell.cellId] = cell;
        }
        if (cells.length > OsmMapBudget.aggregateCells) {
          overflow = true;
          break;
        }
      }
      if (!overflow) {
        timer.stop();
        return OsmMapResult(
          cells: cells.values
              .where((cell) => cell.intersects(bounds))
              .toList(growable: false),
          dense: OsmMapBudget.loadPoints(zoom),
          queryCount: queries,
          documentReads: reads,
          cacheHits: hits,
          elapsed: timer.elapsed,
        );
      }
      precision -= 2;
    }
    timer.stop();
    return OsmMapResult(
      dense: true,
      queryCount: queries,
      documentReads: reads,
      cacheHits: hits,
      elapsed: timer.elapsed,
    );
  }

  Future<OsmMapPoint?> getPoint(String sourceId) =>
      _source.fetchPoint(sourceId);

  static MapViewportBounds _padded(MapViewportBounds bounds) {
    final latitudePadding = bounds.latitudeSpan * OsmMapBudget.viewportPadding;
    final longitudePadding =
        bounds.longitudeSpan * OsmMapBudget.viewportPadding;
    // A dateline-spanning padded viewport is safely left unpadded.
    if (bounds.west > bounds.east ||
        bounds.west - longitudePadding < -180 ||
        bounds.east + longitudePadding > 180) {
      return bounds;
    }
    return MapViewportBounds(
      south: (bounds.south - latitudePadding).clamp(-90.0, 90.0).toDouble(),
      west: bounds.west - longitudePadding,
      north: (bounds.north + latitudePadding).clamp(-90.0, 90.0).toDouble(),
      east: bounds.east + longitudePadding,
    );
  }

  static void _store<T>(
    Map<String, List<T>> cache,
    String key,
    List<T> value,
    int max,
  ) {
    if (cache.length >= max) {
      cache.remove(cache.keys.first);
    }
    cache[key] = value;
  }
}
