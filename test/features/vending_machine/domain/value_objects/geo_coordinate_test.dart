import 'package:flutter_test/flutter_test.dart';
import 'package:vending_app/features/vending_machine/domain/value_objects/geo_coordinate.dart';

void main() {
  group('GeoCoordinate', () {
    test('有効な緯度経度を保持する', () {
      final coordinate = GeoCoordinate(
        latitude: 35.681236,
        longitude: 139.767125,
      );

      expect(coordinate.latitude, 35.681236);
      expect(coordinate.longitude, 139.767125);
    });

    test('範囲外の緯度経度を拒否する', () {
      expect(
        () => GeoCoordinate(latitude: 91, longitude: 139),
        throwsFormatException,
      );
      expect(
        () => GeoCoordinate(latitude: 35, longitude: 181),
        throwsFormatException,
      );
    });
  });
}
