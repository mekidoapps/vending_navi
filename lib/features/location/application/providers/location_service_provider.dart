import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/services/geolocator_location_service.dart';
import '../../domain/services/location_service.dart';

final locationServiceProvider = Provider<LocationService>(
  (ref) => const GeolocatorLocationService(),
  name: 'locationServiceProvider',
);
