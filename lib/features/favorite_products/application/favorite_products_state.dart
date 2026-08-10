import '../../../core/errors/app_failure.dart';
import '../../product_master/domain/entities/product.dart';
import '../domain/models/favorite_products_view.dart';

final class FavoriteProductsState {
  const FavoriteProductsState({
    this.isAuthenticated = false,
    this.uid,
    this.products = const <Product>[],
    this.isLegacyFallback = false,
    this.nextSortOrder = 0,
    this.isLoading = false,
    this.isMutating = false,
    this.failure,
  });

  final bool isAuthenticated;
  final String? uid;
  final List<Product> products;
  final bool isLegacyFallback;
  final int nextSortOrder;
  final bool isLoading;
  final bool isMutating;
  final AppFailure? failure;

  FavoriteProductsView get currentView {
    return FavoriteProductsView(
      products: products,
      isLegacyFallback: isLegacyFallback,
      nextSortOrder: nextSortOrder,
    );
  }

  FavoriteProductsState copyWith({
    bool? isAuthenticated,
    String? uid,
    bool clearUid = false,
    List<Product>? products,
    bool? isLegacyFallback,
    int? nextSortOrder,
    bool? isLoading,
    bool? isMutating,
    AppFailure? failure,
    bool clearFailure = false,
  }) {
    return FavoriteProductsState(
      isAuthenticated: isAuthenticated ?? this.isAuthenticated,
      uid: clearUid ? null : uid ?? this.uid,
      products: products ?? this.products,
      isLegacyFallback: isLegacyFallback ?? this.isLegacyFallback,
      nextSortOrder: nextSortOrder ?? this.nextSortOrder,
      isLoading: isLoading ?? this.isLoading,
      isMutating: isMutating ?? this.isMutating,
      failure: clearFailure ? null : failure ?? this.failure,
    );
  }
}
