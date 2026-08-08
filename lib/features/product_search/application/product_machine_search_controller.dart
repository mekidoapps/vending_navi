import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../home_map/domain/value_objects/map_viewport_bounds.dart';
import '../../product_master/domain/value_objects/master_id.dart';
import 'product_machine_search_state.dart';
import 'providers/machine_product_index_providers.dart';

final productMachineSearchControllerProvider =
    NotifierProvider<ProductMachineSearchController, ProductMachineSearchState>(
      ProductMachineSearchController.new,
      name: 'productMachineSearchControllerProvider',
    );

final class ProductMachineSearchController
    extends Notifier<ProductMachineSearchState> {
  var _requestSerial = 0;

  @override
  ProductMachineSearchState build() {
    return const ProductMachineSearchState();
  }

  Future<void> search({
    required ProductId productId,
    required MapViewportBounds viewport,
    bool force = false,
  }) async {
    if (!force &&
        state.represents(productId: productId, viewport: viewport) &&
        state.hasSearched &&
        !state.isLoading) {
      return;
    }

    final requestId = ++_requestSerial;

    state = ProductMachineSearchState(
      productId: productId,
      viewport: viewport,
      isLoading: true,
    );

    final result = await ref
        .read(machineProductIndexRepositoryProvider)
        .findByProductInViewport(productId: productId, viewport: viewport);

    if (requestId != _requestSerial) {
      return;
    }

    final failure = result.failureOrNull;
    if (failure != null) {
      state = state.copyWith(
        failure: failure,
        entries: const [],
        isLoading: false,
        hasSearched: true,
      );
      return;
    }

    state = state.copyWith(
      entries: result.valueOrNull ?? const [],
      isLoading: false,
      hasSearched: true,
      clearFailure: true,
    );
  }

  Future<void> retry() async {
    final productId = state.productId;
    final viewport = state.viewport;
    if (productId == null || viewport == null) {
      return;
    }

    await search(productId: productId, viewport: viewport, force: true);
  }

  void clear() {
    _requestSerial += 1;
    state = const ProductMachineSearchState();
  }
}
