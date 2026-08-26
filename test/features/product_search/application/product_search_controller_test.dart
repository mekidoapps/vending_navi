import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vending_app/core/errors/app_failure.dart';
import 'package:vending_app/core/result/app_result.dart';
import 'package:vending_app/features/product_master/data/fixtures/product_master_fixture.dart';
import 'package:vending_app/features/product_master/domain/entities/product.dart';
import 'package:vending_app/features/product_master/domain/repositories/product_repository.dart';
import 'package:vending_app/features/product_master/domain/value_objects/master_id.dart';
import 'package:vending_app/features/product_search/application/product_search_controller.dart';
import 'package:vending_app/features/product_search/application/providers/product_search_providers.dart';
import 'package:vending_app/features/product_search/domain/services/product_candidate_search_service.dart';

void main() {
  test('検索成功後に候補と完了状態を保持する', () async {
    final container = ProviderContainer(
      overrides: [
        productCandidateSearchServiceProvider.overrideWithValue(
          ProductCandidateSearchService(
            productRepository: _FixtureProductRepository(),
          ),
        ),
      ],
    );
    addTearDown(container.dispose);

    await container.read(productSearchControllerProvider.notifier).search('綾鷹');

    final state = container.read(productSearchControllerProvider);
    expect(state.isLoading, isFalse);
    expect(state.hasSearched, isTrue);
    expect(state.failure, isNull);
    expect(state.candidates.first.product.name, '綾鷹');
  });

  test('clearでqueryと候補を初期化する', () async {
    final container = ProviderContainer(
      overrides: [
        productCandidateSearchServiceProvider.overrideWithValue(
          ProductCandidateSearchService(
            productRepository: _FixtureProductRepository(),
          ),
        ),
      ],
    );
    addTearDown(container.dispose);

    final controller = container.read(productSearchControllerProvider.notifier);

    await controller.search('綾鷹');
    controller.clear();

    final state = container.read(productSearchControllerProvider);
    expect(state.query.isEmpty, isTrue);
    expect(state.candidates, isEmpty);
    expect(state.hasSearched, isFalse);
  });

  test('古い非同期結果で新しい検索状態を上書きしない', () async {
    final repository = _DeferredProductRepository();

    final container = ProviderContainer(
      overrides: [
        productCandidateSearchServiceProvider.overrideWithValue(
          ProductCandidateSearchService(productRepository: repository),
        ),
      ],
    );
    addTearDown(container.dispose);

    final controller = container.read(productSearchControllerProvider.notifier);

    final ayataka = ProductMasterFixture.products.singleWhere(
      (product) => product.id.value == 'coca_cola_ayataka',
    );
    final bossBlack = ProductMasterFixture.products.singleWhere(
      (product) => product.id.value == 'suntory_boss_black',
    );

    final first = controller.search('綾鷹');
    final second = controller.search('BOSS');

    repository.completeCall(1, <Product>[bossBlack]);
    await second;

    repository.completeCall(0, <Product>[ayataka]);
    await first;

    final state = container.read(productSearchControllerProvider);

    expect(state.query.trimmedText, 'BOSS');
    expect(state.candidates, hasLength(1));
    expect(state.candidates.single.product.id.value, 'suntory_boss_black');
  });
}

final class _FixtureProductRepository implements ProductRepository {
  @override
  Future<AppResult<Product>> getProduct(ProductId id) async {
    for (final product in ProductMasterFixture.products) {
      if (product.id == id) {
        return AppResult<Product>.success(product);
      }
    }
    return const AppResult<Product>.failure(NotFoundFailure());
  }

  @override
  Future<AppResult<List<Product>>> getProducts({bool activeOnly = true}) async {
    return AppResult<List<Product>>.success(
      ProductMasterFixture.products
          .where((product) => !activeOnly || product.isActive)
          .toList(growable: false),
    );
  }
}

final class _DeferredProductRepository implements ProductRepository {
  final List<Completer<AppResult<List<Product>>>> _calls = [];

  @override
  Future<AppResult<Product>> getProduct(ProductId id) async {
    return const AppResult<Product>.failure(NotFoundFailure());
  }

  @override
  Future<AppResult<List<Product>>> getProducts({bool activeOnly = true}) {
    final completer = Completer<AppResult<List<Product>>>();
    _calls.add(completer);
    return completer.future;
  }

  void completeCall(int index, List<Product> products) {
    _calls[index].complete(AppResult<List<Product>>.success(products));
  }
}
