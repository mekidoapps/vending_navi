import 'dart:math' as math;

import 'package:geolocator/geolocator.dart';

import '../models/position_data.dart';

class DistanceUtil {
  DistanceUtil._();

  static const double _earthRadiusMeters = 6371000.0;

  /// km単位で返す旧互換メソッド
  static double calculateDistance(
      double lat1,
      double lon1,
      double lat2,
      double lon2,
      ) {
    final meters = calculateDistanceMeters(
      fromLat: lat1,
      fromLng: lon1,
      toLat: lat2,
      toLng: lon2,
    );

    if (!meters.isFinite) {
      return 9999;
    }

    return meters / 1000.0;
  }

  /// meter単位で返す主力メソッド
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

    final dLat = _degToRad(toLat! - fromLat!);
    final dLng = _degToRad(toLng! - fromLng!);

    final a = math.pow(math.sin(dLat / 2), 2) +
        math.cos(_degToRad(fromLat)) *
            math.cos(_degToRad(toLat)) *
            math.pow(math.sin(dLng / 2), 2);

    final c = 2 *
        math.atan2(
          math.sqrt(a.toDouble()),
          math.sqrt(1 - a.toDouble()),
        );

    return _earthRadiusMeters * c;
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
    if (value is num) return value.toDouble();

    if (value is String) {
      return double.tryParse(value.trim());
    }

    return null;
  }

  static Future<PositionData?> getCurrentPositionSafe() async {
    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        return null;
      }

      var permission = await Geolocator.checkPermission();

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

  static Future<bool> ensureLocationPermission() async {
    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) return false;

      var permission = await Geolocator.checkPermission();

      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      return permission == LocationPermission.always ||
          permission == LocationPermission.whileInUse;
    } catch (_) {
      return false;
    }
  }

  static bool _isValidLatLng(double lat, double lng) {
    if (lat == 0 && lng == 0) return false;
    if (lat < -90 || lat > 90) return false;
    if (lng < -180 || lng > 180) return false;
    return true;
  }

  static double _degToRad(double deg) {
    return deg * (math.pi / 180.0);
  }
}