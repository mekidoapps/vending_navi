import '../../../../core/errors/failure_mapper.dart';
import '../../../../core/result/app_result.dart';
import '../../../home_map/data/geo/geo_hash_query_planner.dart';
import '../../../home_map/domain/value_objects/map_viewport_bounds.dart';
import '../../../product_master/domain/value_objects/master_id.dart';
import '../../domain/entities/machine_product_index_entry.dart';
import '../../domain/repositories/machine_product_index_repository.dart';
import '../mappers/machine_product_index_mapper.dart';
import '../sources/machine_product_index_source.dart';

final class MachineProductIndexRepositoryImpl
    implements MachineProductIndexRepository {
  const MachineProductIndexRepositoryImpl({
    required MachineProductIndexSource source,
  }) : _source = source;

  final MachineProductIndexSource _source;

  @override
  Future<AppResult<List<MachineProductIndexEntry>>> findByProductInViewport({
    required ProductId productId,
    required MapViewportBounds viewport,
  }) async {
    try {
      final prefixes = GeoHashQueryPlanner.prefixesForBounds(viewport);

      final documents = await _source.fetchByProductAndGeohashPrefixes(
        productId: productId,
        geohashPrefixes: prefixes,
      );

      final entriesByMachine = <String, MachineProductIndexEntry>{};

      for (final document in documents) {
        final mapped = MachineProductIndexMapper.fromFirestoreDocument(
          documentId: document.id,
          data: document.data,
        );

        final failure = mapped.failureOrNull;
        if (failure != null) {
          return AppResult<List<MachineProductIndexEntry>>.failure(failure);
        }

        final entry = mapped.valueOrNull;
        if (entry == null) {
          continue;
        }

        if (entry.productId != productId) {
          continue;
        }

        if (!entry.isSearchVisible) {
          continue;
        }

        if (!viewport.contains(
          latitude: entry.location.latitude,
          longitude: entry.location.longitude,
        )) {
          continue;
        }

        final key = entry.machineId.value;
        final previous = entriesByMachine[key];

        if (previous == null || _priority(entry) > _priority(previous)) {
          entriesByMachine[key] = entry;
        }
      }

      final entries = entriesByMachine.values.toList(growable: false)
        ..sort(
          (left, right) =>
              left.machineId.value.compareTo(right.machineId.value),
        );

      return AppResult<List<MachineProductIndexEntry>>.success(
        List<MachineProductIndexEntry>.unmodifiable(entries),
      );
    } on Object catch (error) {
      return AppResult<List<MachineProductIndexEntry>>.failure(
        FailureMapper.map(error),
      );
    }
  }

  static int _priority(MachineProductIndexEntry entry) {
    if (entry.isConfirmed) {
      return 2;
    }
    if (entry.isInferred) {
      return 1;
    }
    return 0;
  }
}
