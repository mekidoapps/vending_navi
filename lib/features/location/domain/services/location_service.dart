import '../../../../core/result/app_result.dart';
import '../entities/app_location_permission.dart';
import '../entities/current_location.dart';

abstract interface class LocationService {
  Future<bool> isLocationServiceEnabled();

  Future<AppLocationPermission> checkPermission();

  Future<AppLocationPermission> requestPermission();

  Future<AppResult<CurrentLocation>> getCurrentLocation();

  Future<bool> openAppSettings();

  Future<bool> openLocationSettings();
}
