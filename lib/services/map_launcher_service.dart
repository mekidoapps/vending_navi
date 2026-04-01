import 'dart:io';

import 'package:url_launcher/url_launcher.dart';

class MapLauncherService {
  Future<void> openWalkingNavigation({
    required double latitude,
    required double longitude,
    String? label,
  }) async {
    final encodedLabel = Uri.encodeComponent(label ?? '目的地');

    final List<Uri> candidates = <Uri>[
      if (Platform.isAndroid)
        Uri.parse(
          'google.navigation:q=$latitude,$longitude&mode=w',
        ),
      if (Platform.isIOS)
        Uri.parse(
          'http://maps.apple.com/?ll=$latitude,$longitude&q=$encodedLabel&dirflg=w',
        ),
      Uri.parse(
        'https://www.google.com/maps/search/?api=1&query=$latitude,$longitude',
      ),
    ];

    for (final uri in candidates) {
      final launched = await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
      );
      if (launched) {
        return;
      }
    }

    throw Exception('地図アプリを起動できませんでした');
  }
}