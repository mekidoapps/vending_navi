import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:vending_app/features/location/data/mappers/geolocator_permission_mapper.dart';
import 'package:vending_app/features/location/domain/entities/app_location_permission.dart';

void main() {
  test('Geolocatorの全権限状態をDomainへ変換する', () {
    expect(
      GeolocatorPermissionMapper.toDomain(LocationPermission.denied),
      AppLocationPermission.denied,
    );
    expect(
      GeolocatorPermissionMapper.toDomain(LocationPermission.deniedForever),
      AppLocationPermission.deniedForever,
    );
    expect(
      GeolocatorPermissionMapper.toDomain(LocationPermission.whileInUse),
      AppLocationPermission.whileInUse,
    );
    expect(
      GeolocatorPermissionMapper.toDomain(LocationPermission.always),
      AppLocationPermission.always,
    );
    expect(
      GeolocatorPermissionMapper.toDomain(LocationPermission.unableToDetermine),
      AppLocationPermission.unableToDetermine,
    );
  });
}
