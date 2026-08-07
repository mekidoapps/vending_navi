import 'package:flutter_test/flutter_test.dart';
import 'package:vending_app/features/vending_machine/data/services/google_maps_external_map_service.dart';

void main() {
  group('GoogleMapsExternalMapService', () {
    test('徒歩経路のGoogle Maps URIを生成する', () {
      final uri = GoogleMapsExternalMapService.buildWalkingDirectionsUri(
        latitude: 35.681236,
        longitude: 139.767125,
      );

      expect(uri.scheme, 'https');
      expect(uri.host, 'www.google.com');
      expect(uri.path, '/maps/dir/');
      expect(uri.queryParameters['api'], '1');
      expect(uri.queryParameters['destination'], '35.681236,139.767125');
      expect(uri.queryParameters['travelmode'], 'walking');
      expect(uri.queryParameters['dir_action'], 'navigate');
    });

    test('不正座標を拒否する', () {
      expect(
        () => GoogleMapsExternalMapService.buildWalkingDirectionsUri(
          latitude: 91,
          longitude: 139,
        ),
        throwsFormatException,
      );
    });
  });
}
