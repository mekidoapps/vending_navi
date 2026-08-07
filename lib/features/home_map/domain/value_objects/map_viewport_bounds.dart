final class MapViewportBounds {
  const MapViewportBounds._({
    required this.south,
    required this.west,
    required this.north,
    required this.east,
  });

  factory MapViewportBounds({
    required double south,
    required double west,
    required double north,
    required double east,
  }) {
    if (!south.isFinite ||
        !west.isFinite ||
        !north.isFinite ||
        !east.isFinite ||
        south < -90 ||
        south > 90 ||
        north < -90 ||
        north > 90 ||
        west < -180 ||
        west > 180 ||
        east < -180 ||
        east > 180 ||
        south > north) {
      throw FormatException(
        'Invalid map viewport: '
        'south=$south west=$west north=$north east=$east',
      );
    }

    return MapViewportBounds._(
      south: south,
      west: west,
      north: north,
      east: east,
    );
  }

  final double south;
  final double west;
  final double north;
  final double east;

  double get latitudeSpan => north - south;

  double get longitudeSpan {
    if (west <= east) {
      return east - west;
    }
    return (180 - west) + (east + 180);
  }

  double get centerLatitude => (south + north) / 2;

  double get centerLongitude {
    if (west <= east) {
      return (west + east) / 2;
    }

    final width = longitudeSpan;
    final center = west + width / 2;
    return center > 180 ? center - 360 : center;
  }

  bool contains({required double latitude, required double longitude}) {
    if (latitude < south || latitude > north) {
      return false;
    }

    if (west <= east) {
      return longitude >= west && longitude <= east;
    }

    return longitude >= west || longitude <= east;
  }

  bool roughlyEquals(MapViewportBounds other, {double tolerance = 0.00001}) {
    return (south - other.south).abs() <= tolerance &&
        (west - other.west).abs() <= tolerance &&
        (north - other.north).abs() <= tolerance &&
        (east - other.east).abs() <= tolerance;
  }
}
