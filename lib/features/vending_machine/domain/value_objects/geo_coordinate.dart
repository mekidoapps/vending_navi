final class GeoCoordinate {
  GeoCoordinate._({required this.latitude, required this.longitude});

  factory GeoCoordinate({required double latitude, required double longitude}) {
    if (!latitude.isFinite ||
        !longitude.isFinite ||
        latitude < -90 ||
        latitude > 90 ||
        longitude < -180 ||
        longitude > 180) {
      throw FormatException(
        'Invalid GeoCoordinate: latitude=$latitude longitude=$longitude',
      );
    }

    return GeoCoordinate._(latitude: latitude, longitude: longitude);
  }

  final double latitude;
  final double longitude;

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is GeoCoordinate &&
            other.latitude == latitude &&
            other.longitude == longitude;
  }

  @override
  int get hashCode => Object.hash(latitude, longitude);

  @override
  String toString() => 'GeoCoordinate($latitude, $longitude)';
}
