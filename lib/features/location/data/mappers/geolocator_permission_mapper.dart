import 'package:geolocator/geolocator.dart';

import '../../domain/entities/app_location_permission.dart';

abstract final class GeolocatorPermissionMapper {
  static AppLocationPermission toDomain(LocationPermission permission) {
    return switch (permission) {
      LocationPermission.denied => AppLocationPermission.denied,
      LocationPermission.deniedForever => AppLocationPermission.deniedForever,
      LocationPermission.whileInUse => AppLocationPermission.whileInUse,
      LocationPermission.always => AppLocationPermission.always,
      LocationPermission.unableToDetermine =>
        AppLocationPermission.unableToDetermine,
    };
  }
}
