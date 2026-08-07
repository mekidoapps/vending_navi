import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/value_objects/product_search_query.dart';
import 'product_search_state.dart';
import 'providers/product_search_providers.dart';

final productSearchControllerProvider =
    NotifierProvider<ProductSearchController, ProductSearchState>(
      ProductSearchController.new,
      name: 'productSearchControllerProvider',
    );

final class ProductSearchController extends Notifier<ProductSearchState> {
  var _requestSerial = 0;

  @override
  ProductSearchState build() {
    return ProductSearchState.initial();
  }

  Future<void> search(String rawText) async {
    final query = ProductSearchQuery(rawText);
    final requestId = ++_requestSerial;

    if (query.isEmpty) {
      state = ProductSearchState.initial();
      return;
    }

    state = state.copyWith(
      query: query,
      candidates: const [],
      isLoading: true,
      hasSearched: false,
      clearFailure: true,
    );

    final result = await ref
        .read(productCandidateSearchServiceProvider)
        .search(query);

    if (requestId != _requestSerial) {
      return;
    }

    final failure = result.failureOrNull;
    if (failure != null) {
      state = state.copyWith(
        failure: failure,
        candidates: const [],
        isLoading: false,
        hasSearched: true,
      );
      return;
    }

    state = state.copyWith(
      candidates: result.valueOrNull ?? const [],
      isLoading: false,
      hasSearched: true,
      clearFailure: true,
    );
  }

  void clear() {
    _requestSerial += 1;
    state = ProductSearchState.initial();
  }
}
