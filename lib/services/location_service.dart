import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';

class CurrentLocationResult {
  const CurrentLocationResult({
    required this.latitude,
    required this.longitude,
    required this.addressLabel,
    required this.rawPlacemark,
  });

  final double latitude;
  final double longitude;
  final String addressLabel;
  final Placemark? rawPlacemark;
}

class LocationServiceException implements Exception {
  const LocationServiceException(this.message);

  final String message;

  @override
  String toString() => message;
}

class LocationService {
  Future<CurrentLocationResult> getCurrentLocation() async {
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      throw const LocationServiceException('位置情報サービスがオフです');
    }

    LocationPermission permission = await Geolocator.checkPermission();

    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }

    if (permission == LocationPermission.denied) {
      throw const LocationServiceException('位置情報の権限が許可されていません');
    }

    if (permission == LocationPermission.deniedForever) {
      throw const LocationServiceException(
        '位置情報の権限が恒久的に拒否されています。設定から許可してください',
      );
    }

    final position = await Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
      ),
    );

    Placemark? placemark;
    String address = '';

    try {
      final placemarks = await placemarkFromCoordinates(
        position.latitude,
        position.longitude,
      );

      if (placemarks.isNotEmpty) {
        placemark = placemarks.first;
        address = _formatPlacemark(placemark);
      }
    } catch (_) {
      // 住所化に失敗しても座標は返す
    }

    return CurrentLocationResult(
      latitude: position.latitude,
      longitude: position.longitude,
      addressLabel: address,
      rawPlacemark: placemark,
    );
  }

  Future<Position?> getCurrentPositionSafe() async {
    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) return null;

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        return null;
      }

      return await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      );
    } catch (_) {
      return null;
    }
  }

  String _formatPlacemark(Placemark placemark) {
    final parts = <String?>[
      placemark.administrativeArea,
      placemark.locality,
      placemark.subLocality,
      placemark.thoroughfare,
      placemark.subThoroughfare,
      placemark.name,
    ];

    final cleaned = parts
        .whereType<String>()
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();

    final unique = <String>[];
    for (final part in cleaned) {
      if (!unique.contains(part)) {
        unique.add(part);
      }
    }

    return unique.join(' ');
  }
}