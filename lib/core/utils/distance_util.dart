import 'dart:math' as math;

class DistanceUtil {
  DistanceUtil._();

  static double calculateDistanceKm({
    required double startLatitude,
    required double startLongitude,
    required double endLatitude,
    required double endLongitude,
  }) {
    const double earthRadiusKm = 6371.0;

    final double dLat = _degToRad(endLatitude - startLatitude);
    final double dLng = _degToRad(endLongitude - startLongitude);

    final double a =
        math.sin(dLat / 2) * math.sin(dLat / 2) +
            math.cos(_degToRad(startLatitude)) *
                math.cos(_degToRad(endLatitude)) *
                math.sin(dLng / 2) *
                math.sin(dLng / 2);

    final double c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    return earthRadiusKm * c;
  }

  static String formatDistanceKm(double distanceKm) {
    if (distanceKm < 1) {
      final int meter = (distanceKm * 1000).round();
      return '約$meter m';
    }

    return '約${distanceKm.toStringAsFixed(1)}km';
  }

  static String formatWalkingEstimate(double distanceKm) {
    final int meter = (distanceKm * 1000).round();
    final int minute = math.max(1, (meter / 80).round());
    return '徒歩$minute 分';
  }

  static String buildDistanceLabel(double distanceKm) {
    if (distanceKm < 1) {
      return '${formatDistanceKm(distanceKm)} / ${formatWalkingEstimate(distanceKm)}';
    }
    return formatDistanceKm(distanceKm);
  }

  static double _degToRad(double degree) {
    return degree * math.pi / 180.0;
  }
}