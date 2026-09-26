import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vending_app/features/home_map/domain/value_objects/map_viewport_bounds.dart';
import 'package:vending_app/features/osm/application/osm_map_controller.dart';
import 'package:vending_app/features/osm/data/osm_map_repository.dart';

void main() {
  test('newer viewport wins and stale response is discarded', () async {
    final source = _DeferredSource();
    final container = ProviderContainer(overrides: [
      osmMapRepositoryProvider.overrideWithValue(OsmMapRepository(source)),
    ]);
    addTearDown(container.dispose);
    final controller = container.read(osmMapControllerProvider.notifier);
    final bounds = MapViewportBounds(
      south: 35.680, west: 139.765, north: 35.682, east: 139.769,
    );
    final older = controller.load(bounds, 8);
    final newer = controller.load(bounds, 8);
    expect(source.pending, hasLength(2));
    source.pending[1].complete(const []);
    await newer;
    source.pending[0].complete([const OsmAggregateCell(
      cellId: 'old', count: 999, latitude: 35.681, longitude: 139.767,
      south: 35, west: 139, north: 36, east: 140,
    )]);
    await older;
    final state = container.read(osmMapControllerProvider);
    expect(state.result.cells, isEmpty);
    expect(state.staleDiscarded, 1);
  });
}

final class _DeferredSource implements OsmMapSource {
  final pending = <Completer<List<OsmAggregateCell>>>[];

  @override
  Future<List<OsmAggregateCell>> fetchAggregate({
    required int precision, required String geohashPrefix, required int limit,
  }) {
    final completer = Completer<List<OsmAggregateCell>>();
    pending.add(completer);
    return completer.future;
  }

  @override
  Future<List<OsmMapPoint>> fetchPoints({
    required String geohashPrefix, required int limit,
  }) async => const [];

  @override
  Future<OsmMapPoint?> fetchPoint(String sourceId) async => null;
}
