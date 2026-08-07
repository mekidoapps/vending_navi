import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/services/google_maps_external_map_service.dart';
import '../../domain/services/external_map_service.dart';

final externalMapServiceProvider = Provider<ExternalMapService>(
  (ref) => const GoogleMapsExternalMapService(),
  name: 'externalMapServiceProvider',
);
