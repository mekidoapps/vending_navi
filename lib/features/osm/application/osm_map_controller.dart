import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/firebase/firebase_providers.dart';
import '../../home_map/domain/value_objects/map_viewport_bounds.dart';
import '../data/osm_map_repository.dart';

final osmMapRepositoryProvider = Provider<OsmMapRepository>((ref) {
  return OsmMapRepository(FirestoreOsmMapSource(ref.watch(firestoreProvider)));
});

final osmMapControllerProvider =
    NotifierProvider<OsmMapController, OsmMapState>(OsmMapController.new);

final class OsmMapState {
  const OsmMapState({
    this.result = const OsmMapResult(),
    this.loading = false,
    this.error = false,
    this.staleDiscarded = 0,
  });

  final OsmMapResult result;
  final bool loading;
  final bool error;
  final int staleDiscarded;
}

final class OsmMapController extends Notifier<OsmMapState> {
  int _generation = 0;

  @override
  OsmMapState build() => const OsmMapState();

  void invalidate() {
    _generation++;
  }

  void suspend() {
    invalidate();
    state = OsmMapState(staleDiscarded: state.staleDiscarded);
  }

  Future<void> load(MapViewportBounds viewport, double zoom) async {
    final generation = ++_generation;
    state = OsmMapState(
      result: state.result,
      loading: true,
      staleDiscarded: state.staleDiscarded,
    );
    try {
      final result = await ref
          .read(osmMapRepositoryProvider)
          .load(viewport, zoom);
      if (generation != _generation) {
        state = OsmMapState(
          result: state.result,
          loading: state.loading,
          error: state.error,
          staleDiscarded: state.staleDiscarded + 1,
        );
        return;
      }
      state = OsmMapState(result: result, staleDiscarded: state.staleDiscarded);
    } on Object {
      if (generation != _generation) return;
      state = OsmMapState(error: true, staleDiscarded: state.staleDiscarded);
    }
  }
}
