final class CurrentLocation {
  CurrentLocation._({
    required this.latitude,
    required this.longitude,
    required this.accuracyMeters,
    required this.capturedAt,
  });

  factory CurrentLocation({
    required double latitude,
    required double longitude,
    required double accuracyMeters,
    required DateTime capturedAt,
  }) {
    if (!latitude.isFinite ||
        !longitude.isFinite ||
        latitude < -90 ||
        latitude > 90 ||
        longitude < -180 ||
        longitude > 180) {
      throw FormatException(
        'Invalid current location: latitude=$latitude longitude=$longitude',
      );
    }

    if (!accuracyMeters.isFinite || accuracyMeters < 0) {
      throw FormatException(
        'Invalid current location accuracy: $accuracyMeters',
      );
    }

    return CurrentLocation._(
      latitude: latitude,
      longitude: longitude,
      accuracyMeters: accuracyMeters,
      capturedAt: capturedAt.toUtc(),
    );
  }

  final double latitude;
  final double longitude;
  final double accuracyMeters;
  final DateTime capturedAt;

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is CurrentLocation &&
            other.latitude == latitude &&
            other.longitude == longitude &&
            other.accuracyMeters == accuracyMeters &&
            other.capturedAt == capturedAt;
  }

  @override
  int get hashCode =>
      Object.hash(latitude, longitude, accuracyMeters, capturedAt);

  @override
  String toString() {
    return 'CurrentLocation('
        'latitude: $latitude, '
        'longitude: $longitude, '
        'accuracyMeters: $accuracyMeters, '
        'capturedAt: $capturedAt'
        ')';
  }
}
