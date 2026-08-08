import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../home_map/domain/value_objects/map_viewport_bounds.dart';
import '../../product_master/domain/entities/product_genre.dart';
import 'genre_machine_search_state.dart';
import 'providers/genre_search_providers.dart';

final genreMachineSearchControllerProvider =
    NotifierProvider<GenreMachineSearchController, GenreMachineSearchState>(
      GenreMachineSearchController.new,
      name: 'genreMachineSearchControllerProvider',
    );

final class GenreMachineSearchController
    extends Notifier<GenreMachineSearchState> {
  var _requestSerial = 0;

  @override
  GenreMachineSearchState build() {
    return const GenreMachineSearchState();
  }

  Future<void> search({
    required ProductGenre genre,
    required MapViewportBounds viewport,
    bool force = false,
  }) async {
    if (!force &&
        state.represents(genre: genre, viewport: viewport) &&
        state.hasSearched &&
        !state.isLoading) {
      return;
    }

    final requestId = ++_requestSerial;

    state = GenreMachineSearchState(
      genre: genre,
      viewport: viewport,
      isLoading: true,
    );

    final result = await ref
        .read(genreMachineSearchServiceProvider)
        .search(genre: genre, viewport: viewport);

    if (requestId != _requestSerial) {
      return;
    }

    final failure = result.failureOrNull;
    if (failure != null) {
      state = state.copyWith(
        productIds: const {},
        entries: const [],
        failure: failure,
        isLoading: false,
        hasSearched: true,
      );
      return;
    }

    final value = result.valueOrNull;
    state = state.copyWith(
      productIds: value?.productIds ?? const {},
      entries: value?.entries ?? const [],
      isLoading: false,
      hasSearched: true,
      clearFailure: true,
    );
  }

  Future<void> retry() async {
    final genre = state.genre;
    final viewport = state.viewport;
    if (genre == null || viewport == null) {
      return;
    }

    await search(genre: genre, viewport: viewport, force: true);
  }

  void clear() {
    _requestSerial += 1;
    state = const GenreMachineSearchState();
  }
}
