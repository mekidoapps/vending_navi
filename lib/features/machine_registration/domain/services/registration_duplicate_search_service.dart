import 'dart:math' as math;

import '../../../../core/errors/app_failure.dart';
import '../../../../core/result/app_result.dart';
import '../../../home_map/domain/repositories/vending_machine_map_repository.dart';
import '../../../home_map/domain/value_objects/map_viewport_bounds.dart';
import '../../../vending_machine/domain/value_objects/geo_coordinate.dart';
import '../models/registration_duplicate_candidate.dart';

final class RegistrationDuplicateSearchService {
  const RegistrationDuplicateSearchService(this._repository);

  static const double candidateRadiusMeters = 30;
  static const double _earthRadiusMeters = 6371000;

  final VendingMachineMapRepository _repository;

  Future<AppResult<List<RegistrationDuplicateCandidate>>> search(
    GeoCoordinate center,
  ) async {
    final bounds = _boundsAround(center, radiusMeters: candidateRadiusMeters);
    final result = await _repository.getMachinesInViewport(bounds);
    final failure = result.failureOrNull;

    if (failure != null) {
      return AppResult<List<RegistrationDuplicateCandidate>>.failure(failure);
    }

    final machines = result.valueOrNull;
    if (machines == null) {
      return const AppResult<List<RegistrationDuplicateCandidate>>.failure(
        UnknownFailure(),
      );
    }

    final candidates = <RegistrationDuplicateCandidate>[];

    for (final machine in machines) {
      final distance = distanceMeters(center, machine.location);
      if (distance <= candidateRadiusMeters) {
        candidates.add(
          RegistrationDuplicateCandidate(
            machine: machine,
            distanceMeters: distance,
          ),
        );
      }
    }

    candidates.sort(
      (left, right) => left.distanceMeters.compareTo(right.distanceMeters),
    );

    return AppResult<List<RegistrationDuplicateCandidate>>.success(
      List<RegistrationDuplicateCandidate>.unmodifiable(candidates),
    );
  }

  static double distanceMeters(GeoCoordinate left, GeoCoordinate right) {
    final lat1 = _degreesToRadians(left.latitude);
    final lat2 = _degreesToRadians(right.latitude);
    final deltaLat = _degreesToRadians(right.latitude - left.latitude);
    final deltaLon = _degreesToRadians(right.longitude - left.longitude);

    final sinLat = math.sin(deltaLat / 2);
    final sinLon = math.sin(deltaLon / 2);
    final a =
        sinLat * sinLat + math.cos(lat1) * math.cos(lat2) * sinLon * sinLon;
    final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));

    return _earthRadiusMeters * c;
  }

  static MapViewportBounds _boundsAround(
    GeoCoordinate center, {
    required double radiusMeters,
  }) {
    final angularDistance = radiusMeters / _earthRadiusMeters;
    final latitudeDelta = _radiansToDegrees(angularDistance);
    final cosine = math.cos(_degreesToRadians(center.latitude)).abs();
    final longitudeDelta = cosine < 0.000001
        ? 180.0
        : math.min(180.0, latitudeDelta / cosine);

    final south = math.max(-90.0, center.latitude - latitudeDelta);
    final north = math.min(90.0, center.latitude + latitudeDelta);
    final west = _normalizeLongitude(center.longitude - longitudeDelta);
    final east = _normalizeLongitude(center.longitude + longitudeDelta);

    return MapViewportBounds(
      south: south,
      west: west,
      north: north,
      east: east,
    );
  }

  static double _degreesToRadians(double value) => value * math.pi / 180;

  static double _radiansToDegrees(double value) => value * 180 / math.pi;

  static double _normalizeLongitude(double value) {
    var normalized = value;
    while (normalized < -180) {
      normalized += 360;
    }
    while (normalized > 180) {
      normalized -= 360;
    }
    return normalized;
  }
}
