import 'package:flutter_test/flutter_test.dart';
import 'package:vending_app/features/home_map/domain/value_objects/map_viewport_bounds.dart';

void main() {
  group('MapViewportBounds', () {
    test('通常のviewport内外を判定する', () {
      final bounds = MapViewportBounds(
        south: 35.6,
        west: 139.6,
        north: 35.8,
        east: 139.9,
      );

      expect(bounds.contains(latitude: 35.68, longitude: 139.76), isTrue);
      expect(bounds.contains(latitude: 35.9, longitude: 139.76), isFalse);
    });

    test('日付変更線をまたぐviewportを扱える', () {
      final bounds = MapViewportBounds(
        south: -10,
        west: 170,
        north: 10,
        east: -170,
      );

      expect(bounds.contains(latitude: 0, longitude: 179), isTrue);
      expect(bounds.contains(latitude: 0, longitude: -179), isTrue);
      expect(bounds.contains(latitude: 0, longitude: 0), isFalse);
    });
  });
}
