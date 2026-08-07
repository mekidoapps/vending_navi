import '../../../core/errors/app_failure.dart';
import '../domain/models/product_search_candidate.dart';
import '../domain/value_objects/product_search_query.dart';

final class ProductSearchState {
  const ProductSearchState({
    required this.query,
    this.candidates = const <ProductSearchCandidate>[],
    this.failure,
    this.isLoading = false,
    this.hasSearched = false,
  });

  factory ProductSearchState.initial() {
    return ProductSearchState(query: ProductSearchQuery(''));
  }

  final ProductSearchQuery query;
  final List<ProductSearchCandidate> candidates;
  final AppFailure? failure;
  final bool isLoading;
  final bool hasSearched;

  bool get isEmptyResult =>
      hasSearched &&
      !isLoading &&
      failure == null &&
      !query.isEmpty &&
      candidates.isEmpty;

  ProductSearchState copyWith({
    ProductSearchQuery? query,
    List<ProductSearchCandidate>? candidates,
    AppFailure? failure,
    bool clearFailure = false,
    bool? isLoading,
    bool? hasSearched,
  }) {
    return ProductSearchState(
      query: query ?? this.query,
      candidates: candidates ?? this.candidates,
      failure: clearFailure ? null : failure ?? this.failure,
      isLoading: isLoading ?? this.isLoading,
      hasSearched: hasSearched ?? this.hasSearched,
    );
  }
}
