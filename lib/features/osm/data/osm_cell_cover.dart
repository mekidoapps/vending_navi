import '../../home_map/data/geo/geo_hash_codec.dart';
import '../../home_map/domain/value_objects/map_viewport_bounds.dart';

/// Exact geohash-cell cover. Returns null before allocating an oversized grid.
abstract final class OsmCellCover {
  static Set<String>? forBounds(
    MapViewportBounds bounds, {
    required int precision,
    required int maxCells,
  }) {
    if (precision < 1 || precision > 9 || maxCells < 1) {
      throw ArgumentError('Invalid geohash cover budget');
    }
    final longitudeBits = (precision * 5 + 1) ~/ 2;
    final latitudeBits = precision * 5 ~/ 2;
    final cellWidth = 360.0 / (1 << longitudeBits);
    final cellHeight = 180.0 / (1 << latitudeBits);
    final rowStart = _cellIndex(
      bounds.south,
      -90,
      cellHeight,
      1 << latitudeBits,
    );
    final rowEnd = _cellIndex(bounds.north, -90, cellHeight, 1 << latitudeBits);
    final segments = bounds.west <= bounds.east
        ? <(double, double)>[(bounds.west, bounds.east)]
        : <(double, double)>[(bounds.west, 180), (-180, bounds.east)];
    final columns = <int>{};
    for (final segment in segments) {
      final start = _cellIndex(segment.$1, -180, cellWidth, 1 << longitudeBits);
      final end = _cellIndex(segment.$2, -180, cellWidth, 1 << longitudeBits);
      for (var column = start; column <= end; column++) {
        columns.add(column);
        if (columns.length * (rowEnd - rowStart + 1) > maxCells) {
          return null;
        }
      }
    }
    final result = <String>{};
    for (var row = rowStart; row <= rowEnd; row++) {
      for (final column in columns) {
        result.add(
          GeoHashCodec.encode(
            latitude: -90 + (row + 0.5) * cellHeight,
            longitude: -180 + (column + 0.5) * cellWidth,
            precision: precision,
          ),
        );
      }
    }
    return result;
  }

  static int _cellIndex(double value, int minimum, double size, int count) =>
      ((value - minimum) / size).floor().clamp(0, count - 1);
}
