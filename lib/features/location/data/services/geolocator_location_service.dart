import 'dart:async';

import 'package:geolocator/geolocator.dart';

import '../../../../core/errors/app_failure.dart';
import '../../../../core/errors/failure_mapper.dart';
import '../../../../core/result/app_result.dart';
import '../../domain/entities/app_location_permission.dart';
import '../../domain/entities/current_location.dart';
import '../../domain/services/location_service.dart';
import '../mappers/geolocator_permission_mapper.dart';

final class GeolocatorLocationService implements LocationService {
  const GeolocatorLocationService({this.timeout = const Duration(seconds: 12)});

  final Duration timeout;

  @override
  Future<bool> isLocationServiceEnabled() {
    return Geolocator.isLocationServiceEnabled();
  }

  @override
  Future<AppLocationPermission> checkPermission() async {
    final permission = await Geolocator.checkPermission();
    return GeolocatorPermissionMapper.toDomain(permission);
  }

  @override
  Future<AppLocationPermission> requestPermission() async {
    final permission = await Geolocator.requestPermission();
    return GeolocatorPermissionMapper.toDomain(permission);
  }

  @override
  Future<AppResult<CurrentLocation>> getCurrentLocation() async {
    try {
      final position = await Geolocator.getCurrentPosition(
        locationSettings: LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: timeout,
        ),
      );

      return AppResult<CurrentLocation>.success(
        CurrentLocation(
          latitude: position.latitude,
          longitude: position.longitude,
          accuracyMeters: position.accuracy,
          capturedAt: position.timestamp,
        ),
      );
    } on TimeoutException {
      return const AppResult<CurrentLocation>.failure(
        LocationUnavailableFailure(),
      );
    } on LocationServiceDisabledException {
      return const AppResult<CurrentLocation>.failure(
        LocationUnavailableFailure(),
      );
    } on FormatException {
      return const AppResult<CurrentLocation>.failure(
        ValidationFailure(field: 'location'),
      );
    } on Object catch (error) {
      return AppResult<CurrentLocation>.failure(FailureMapper.map(error));
    }
  }

  @override
  Future<bool> openAppSettings() {
    return Geolocator.openAppSettings();
  }

  @override
  Future<bool> openLocationSettings() {
    return Geolocator.openLocationSettings();
  }
}
