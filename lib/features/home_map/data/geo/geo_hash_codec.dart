abstract final class GeoHashCodec {
  static const String _base32 = '0123456789bcdefghjkmnpqrstuvwxyz';

  static String encode({
    required double latitude,
    required double longitude,
    required int precision,
  }) {
    if (!latitude.isFinite ||
        !longitude.isFinite ||
        latitude < -90 ||
        latitude > 90 ||
        longitude < -180 ||
        longitude > 180 ||
        precision < 1 ||
        precision > 12) {
      throw FormatException(
        'Invalid geohash input: '
        'latitude=$latitude longitude=$longitude precision=$precision',
      );
    }

    var latitudeMin = -90.0;
    var latitudeMax = 90.0;
    var longitudeMin = -180.0;
    var longitudeMax = 180.0;

    final result = StringBuffer();
    var evenBit = true;
    var bit = 0;
    var character = 0;

    while (result.length < precision) {
      if (evenBit) {
        final midpoint = (longitudeMin + longitudeMax) / 2;
        if (longitude >= midpoint) {
          character |= 1 << (4 - bit);
          longitudeMin = midpoint;
        } else {
          longitudeMax = midpoint;
        }
      } else {
        final midpoint = (latitudeMin + latitudeMax) / 2;
        if (latitude >= midpoint) {
          character |= 1 << (4 - bit);
          latitudeMin = midpoint;
        } else {
          latitudeMax = midpoint;
        }
      }

      evenBit = !evenBit;

      if (bit < 4) {
        bit += 1;
        continue;
      }

      result.write(_base32[character]);
      bit = 0;
      character = 0;
    }

    return result.toString();
  }
}
