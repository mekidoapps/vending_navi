import 'package:url_launcher/url_launcher.dart';

import '../../domain/services/external_map_service.dart';

final class AppleMapsExternalMapService implements ExternalMapService {
  const AppleMapsExternalMapService();

  @override
  Future<bool> openWalkingDirections({
    required double latitude,
    required double longitude,
  }) async {
    final uri = buildWalkingDirectionsUri(
      latitude: latitude,
      longitude: longitude,
    );
    try {
      return await launchUrl(uri, mode: LaunchMode.externalApplication);
    } on Object {
      return false;
    }
  }

  static Uri buildWalkingDirectionsUri({
    required double latitude,
    required double longitude,
  }) {
    if (!latitude.isFinite ||
        !longitude.isFinite ||
        latitude < -90 ||
        latitude > 90 ||
        longitude < -180 ||
        longitude > 180) {
      throw const FormatException('Invalid external map destination');
    }
    return Uri.https('maps.apple.com', '/', {
      'daddr': '$latitude,$longitude',
      'dirflg': 'w',
    });
  }
}
