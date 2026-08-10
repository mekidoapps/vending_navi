import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/application/providers/auth_providers.dart';
import '../../auth/domain/entities/auth_session.dart';
import '../../product_master/domain/entities/product.dart';
import 'favorite_products_state.dart';
import 'providers/favorite_products_providers.dart';

final favoriteProductsControllerProvider =
    NotifierProvider<FavoriteProductsController, FavoriteProductsState>(
      FavoriteProductsController.new,
      name: 'favoriteProductsControllerProvider',
    );

final class FavoriteProductsController extends Notifier<FavoriteProductsState> {
  @override
  FavoriteProductsState build() {
    return const FavoriteProductsState();
  }

  Future<void> refresh() async {
    final session = ref.read(authRepositoryProvider).currentSession;

    if (session is! AuthenticatedAuthSession) {
      clearForGuest();
      return;
    }

    await _load(uid: session.user.uid, showLoading: true);
  }

  Future<bool> add(Product product) async {
    final uid = state.uid;
    if (!state.isAuthenticated || uid == null || state.isMutating) {
      return false;
    }

    state = state.copyWith(isMutating: true, clearFailure: true);

    final result = await ref
        .read(favoriteProductsServiceProvider)
        .add(uid: uid, product: product, current: state.currentView);

    final failure = result.failureOrNull;
    if (failure != null) {
      state = state.copyWith(isMutating: false, failure: failure);
      return false;
    }

    await _load(uid: uid, showLoading: false);
    return true;
  }

  Future<bool> remove(Product product) async {
    final uid = state.uid;
    if (!state.isAuthenticated || uid == null || state.isMutating) {
      return false;
    }

    state = state.copyWith(isMutating: true, clearFailure: true);

    final result = await ref
        .read(favoriteProductsServiceProvider)
        .remove(uid: uid, product: product, current: state.currentView);

    final failure = result.failureOrNull;
    if (failure != null) {
      state = state.copyWith(isMutating: false, failure: failure);
      return false;
    }

    await _load(uid: uid, showLoading: false);
    return true;
  }

  void clearFailure() {
    state = state.copyWith(clearFailure: true);
  }

  void clearForGuest() {
    state = const FavoriteProductsState();
  }

  Future<void> _load({required String uid, required bool showLoading}) async {
    state = state.copyWith(
      isAuthenticated: true,
      uid: uid,
      isLoading: showLoading,
      isMutating: false,
      clearFailure: true,
    );

    final result = await ref
        .read(favoriteProductsServiceProvider)
        .load(uid: uid);

    final failure = result.failureOrNull;
    if (failure != null) {
      state = state.copyWith(
        isLoading: false,
        isMutating: false,
        failure: failure,
      );
      return;
    }

    final view = result.valueOrNull;
    if (view == null) {
      state = state.copyWith(isLoading: false, isMutating: false);
      return;
    }

    state = FavoriteProductsState(
      isAuthenticated: true,
      uid: uid,
      products: view.products,
      isLegacyFallback: view.isLegacyFallback,
      nextSortOrder: view.nextSortOrder,
    );
  }
}
