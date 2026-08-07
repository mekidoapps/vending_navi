import '../../domain/value_objects/map_viewport_bounds.dart';
import 'geo_hash_codec.dart';

abstract final class GeoHashQueryPlanner {
  static Set<String> prefixesForBounds(MapViewportBounds bounds) {
    final precision = _precisionFor(bounds);
    final latitudes = _samples(bounds.south, bounds.north);
    final longitudeSegments = _longitudeSegments(bounds);
    final prefixes = <String>{};

    for (final latitude in latitudes) {
      for (final segment in longitudeSegments) {
        for (final longitude in _samples(segment.$1, segment.$2)) {
          prefixes.add(
            GeoHashCodec.encode(
              latitude: latitude,
              longitude: longitude,
              precision: precision,
            ),
          );
        }
      }
    }

    return prefixes;
  }

  static int _precisionFor(MapViewportBounds bounds) {
    final span = bounds.latitudeSpan > bounds.longitudeSpan
        ? bounds.latitudeSpan
        : bounds.longitudeSpan;

    if (span <= 0.004) {
      return 6;
    }
    if (span <= 0.035) {
      return 5;
    }
    if (span <= 0.17) {
      return 4;
    }
    if (span <= 1.3) {
      return 3;
    }
    if (span <= 5.5) {
      return 2;
    }
    return 1;
  }

  static List<double> _samples(double start, double end) {
    if ((end - start).abs() < 0.0000001) {
      return <double>[start];
    }
    return <double>[start, (start + end) / 2, end];
  }

  static List<(double, double)> _longitudeSegments(MapViewportBounds bounds) {
    if (bounds.west <= bounds.east) {
      return <(double, double)>[(bounds.west, bounds.east)];
    }

    return <(double, double)>[(bounds.west, 180), (-180, bounds.east)];
  }
}
