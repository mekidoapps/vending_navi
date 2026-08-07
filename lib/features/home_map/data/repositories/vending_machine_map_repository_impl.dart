import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../../core/errors/app_failure.dart';
import '../../../../core/errors/failure_mapper.dart';
import '../../../../core/result/app_result.dart';
import '../../../vending_machine/data/sources/vending_machine_document.dart';
import '../../../vending_machine/domain/entities/vending_machine.dart';
import '../../../vending_machine/domain/entities/vending_machine_enums.dart';
import '../../../vending_machine/domain/repositories/vending_machine_repository.dart';
import '../../../vending_machine/domain/value_objects/vending_machine_id.dart';
import '../../domain/repositories/vending_machine_map_repository.dart';
import '../../domain/value_objects/map_viewport_bounds.dart';
import '../geo/geo_hash_query_planner.dart';
import '../sources/vending_machine_viewport_source.dart';

final class VendingMachineMapRepositoryImpl
    implements VendingMachineMapRepository {
  VendingMachineMapRepositoryImpl({
    required VendingMachineViewportSource viewportSource,
    required VendingMachineRepository machineRepository,
  }) : _viewportSource = viewportSource,
       _machineRepository = machineRepository;

  final VendingMachineViewportSource _viewportSource;
  final VendingMachineRepository _machineRepository;

  @override
  Future<AppResult<List<VendingMachine>>> getMachinesInViewport(
    MapViewportBounds bounds,
  ) async {
    try {
      final prefixes = GeoHashQueryPlanner.prefixesForBounds(bounds);

      final results = await Future.wait(<Future<List<VendingMachineDocument>>>[
        _viewportSource.fetchV2ByGeohashPrefixes(prefixes),
        _viewportSource.fetchLegacyDocuments(),
      ]);

      final candidates = <String, VendingMachineDocument>{};

      for (final document in results.expand((items) => items)) {
        final location = _readLocation(document.data);
        if (location == null) {
          continue;
        }

        if (!bounds.contains(latitude: location.$1, longitude: location.$2)) {
          continue;
        }

        candidates[document.id] = document;
      }

      final machines = <VendingMachine>[];

      for (final document in candidates.values) {
        final id = VendingMachineId.tryParse(document.id);
        if (id == null) {
          return const AppResult<List<VendingMachine>>.failure(
            ValidationFailure(field: 'vendingMachine.id'),
          );
        }

        final result = await _machineRepository.getMachine(id);
        final failure = result.failureOrNull;
        if (failure != null) {
          return AppResult<List<VendingMachine>>.failure(failure);
        }

        final machine = result.valueOrNull;
        if (machine == null) {
          return const AppResult<List<VendingMachine>>.failure(
            UnknownFailure(),
          );
        }

        if (machine.status != VendingMachineStatus.active) {
          continue;
        }

        if (!bounds.contains(
          latitude: machine.location.latitude,
          longitude: machine.location.longitude,
        )) {
          continue;
        }

        machines.add(machine);
      }

      machines.sort(
        (left, right) => _distanceSquaredFromCenter(
          left,
          bounds,
        ).compareTo(_distanceSquaredFromCenter(right, bounds)),
      );

      return AppResult<List<VendingMachine>>.success(
        List<VendingMachine>.unmodifiable(machines),
      );
    } on Object catch (error) {
      return AppResult<List<VendingMachine>>.failure(FailureMapper.map(error));
    }
  }

  static (double, double)? _readLocation(Map<String, dynamic> data) {
    final location = data['location'];

    if (location is GeoPoint) {
      return (location.latitude, location.longitude);
    }

    final latitude = _readDouble(data['lat'] ?? data['latitude']);
    final longitude = _readDouble(data['lng'] ?? data['longitude']);

    if (latitude == null ||
        longitude == null ||
        latitude < -90 ||
        latitude > 90 ||
        longitude < -180 ||
        longitude > 180) {
      return null;
    }

    return (latitude, longitude);
  }

  static double? _readDouble(Object? value) {
    return switch (value) {
      num number => number.toDouble(),
      String text => double.tryParse(text.trim()),
      _ => null,
    };
  }

  static double _distanceSquaredFromCenter(
    VendingMachine machine,
    MapViewportBounds bounds,
  ) {
    final latitudeDelta = machine.location.latitude - bounds.centerLatitude;
    var longitudeDelta = machine.location.longitude - bounds.centerLongitude;

    if (longitudeDelta > 180) {
      longitudeDelta -= 360;
    } else if (longitudeDelta < -180) {
      longitudeDelta += 360;
    }

    return latitudeDelta * latitudeDelta + longitudeDelta * longitudeDelta;
  }
}
