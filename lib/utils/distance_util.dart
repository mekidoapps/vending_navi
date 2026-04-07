import 'dart:math';

import 'package:geolocator/geolocator.dart';

import '../models/position_data.dart';

class DistanceUtil {
  static const double _earthRadiusKm = 6371.0;

  static double calculateDistance(
      double lat1,
      double lon1,
      double lat2,
      double lon2,
      ) {
    if (!_isValidLatLng(lat1, lon1) || !_isValidLatLng(lat2, lon2)) {
      return 9999;
    }

    final dLat = _deg2rad(lat2 - lat1);
    final dLon = _deg2rad(lon2 - lon1);

    final a = sin(dLat / 2) * sin(dLat / 2) +
        cos(_deg2rad(lat1)) *
            cos(_deg2rad(lat2)) *
            sin(dLon / 2) *
            sin(dLon / 2);

    final c = 2 * atan2(sqrt(a), sqrt(1 - a));
    return _earthRadiusKm * c;
  }

  static double calculateDistanceMeters({
    required double? fromLat,
    required double? fromLng,
    required double? toLat,
    required double? toLng,
  }) {
    if (!isValidCoordinate(fromLat, fromLng) ||
        !isValidCoordinate(toLat, toLng)) {
      return double.infinity;
    }

    return Geolocator.distanceBetween(
      fromLat!,
      fromLng!,
      toLat!,
      toLng!,
    );
  }

  static String formatDistance(double? meters) {
    if (meters == null || !meters.isFinite) {
      return '距離不明';
    }

    if (meters < 1000) {
      return '${meters.round()}m';
    }

    return '${(meters / 1000).toStringAsFixed(1)}km';
  }

  static String formatWalkingTime(double? meters) {
    if (meters == null || !meters.isFinite) {
      return '';
    }

    const double walkingSpeedMetersPerMinute = 80.0;
    final minutes = (meters / walkingSpeedMetersPerMinute).ceil();

    if (minutes <= 1) {
      return '徒歩1分';
    }

    return '徒歩${minutes}分';
  }

  static bool isValidCoordinate(double? lat, double? lng) {
    if (lat == null || lng == null) return false;
    return _isValidLatLng(lat, lng);
  }

  static double? parseCoordinate(dynamic value) {
    if (value == null) return null;

    if (value is double) return value;
    if (value is int) return value.toDouble();

    if (value is String) {
      return double.tryParse(value.trim());
    }

    return null;
  }

  static Future<PositionData?> getCurrentPositionSafe() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        return null;
      }

      LocationPermission permission = await Geolocator.checkPermission();

      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        return null;
      }

      final pos = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      return PositionData(
        latitude: pos.latitude,
        longitude: pos.longitude,
      );
    } catch (_) {
      return null;
    }
  }

  static bool _isValidLatLng(double lat, double lng) {
    if (lat == 0 && lng == 0) return false;
    if (lat < -90 || lat > 90) return false;
    if (lng < -180 || lng > 180) return false;
    return true;
  }

  static double _deg2rad(double deg) {
    return deg * (pi / 180);
  }
}