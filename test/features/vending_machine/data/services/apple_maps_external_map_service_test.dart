import 'package:flutter_test/flutter_test.dart';
import 'package:vending_app/features/vending_machine/data/services/apple_maps_external_map_service.dart';

void main() {
  test(
    'Apple Maps walking directions omit origin to use the current location',
    () {
      final uri = AppleMapsExternalMapService.buildWalkingDirectionsUri(
        latitude: 35.68,
        longitude: 139.76,
      );
      expect(uri.scheme, 'https');
      expect(uri.host, 'maps.apple.com');
      expect(uri.queryParameters, {'daddr': '35.68,139.76', 'dirflg': 'w'});
    },
  );
  for (final coordinates in [
    (91.0, 139.0),
    (35.0, -181.0),
    (double.nan, 139.0),
    (35.0, double.infinity),
  ]) {
    test('invalid coordinates $coordinates are rejected', () {
      expect(
        () => AppleMapsExternalMapService.buildWalkingDirectionsUri(
          latitude: coordinates.$1,
          longitude: coordinates.$2,
        ),
        throwsFormatException,
      );
    });
  }
}
