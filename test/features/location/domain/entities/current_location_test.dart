import 'package:flutter_test/flutter_test.dart';
import 'package:vending_app/features/location/domain/entities/current_location.dart';

void main() {
  group('CurrentLocation', () {
    test('有効な現在地をUTCで保持する', () {
      final location = CurrentLocation(
        latitude: 35.681236,
        longitude: 139.767125,
        accuracyMeters: 8.5,
        capturedAt: DateTime.parse('2026-08-07T14:00:00+09:00'),
      );

      expect(location.latitude, 35.681236);
      expect(location.longitude, 139.767125);
      expect(location.accuracyMeters, 8.5);
      expect(location.capturedAt.isUtc, isTrue);
    });

    test('範囲外座標を拒否する', () {
      expect(
        () => CurrentLocation(
          latitude: 91,
          longitude: 139,
          accuracyMeters: 10,
          capturedAt: DateTime.utc(2026, 8, 7),
        ),
        throwsFormatException,
      );
    });

    test('負の精度を拒否する', () {
      expect(
        () => CurrentLocation(
          latitude: 35,
          longitude: 139,
          accuracyMeters: -1,
          capturedAt: DateTime.utc(2026, 8, 7),
        ),
        throwsFormatException,
      );
    });
  });
}
