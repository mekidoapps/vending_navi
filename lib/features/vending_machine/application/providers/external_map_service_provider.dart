import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/foundation.dart';

import '../../data/services/google_maps_external_map_service.dart';
import '../../data/services/apple_maps_external_map_service.dart';
import '../../domain/services/external_map_service.dart';

final externalMapServiceProvider = Provider<ExternalMapService>(
  (ref) => const GoogleMapsExternalMapService(),
  name: 'externalMapServiceProvider',
);

final appleExternalMapServiceProvider = Provider<ExternalMapService>(
  (_) => const AppleMapsExternalMapService(),
);

final appleMapsAvailableProvider = Provider<bool>(
  (_) => !kIsWeb && defaultTargetPlatform == TargetPlatform.iOS,
);
