import 'package:flutter_test/flutter_test.dart';
import 'package:vending_app/core/errors/app_failure.dart';
import 'package:vending_app/core/result/app_result.dart';
import 'package:vending_app/features/product_master/data/fixtures/product_master_fixture.dart';
import 'package:vending_app/features/product_master/domain/entities/product.dart';
import 'package:vending_app/features/product_master/domain/repositories/product_repository.dart';
import 'package:vending_app/features/product_master/domain/value_objects/master_id.dart';
import 'package:vending_app/features/product_search/domain/models/product_search_candidate.dart';
import 'package:vending_app/features/product_search/domain/services/product_candidate_search_service.dart';
import 'package:vending_app/features/product_search/domain/value_objects/product_search_query.dart';

void main() {
  final service = ProductCandidateSearchService(
    productRepository: _FixtureProductRepository(),
  );

  test('商品名完全一致を最優先に返す', () async {
    final result = await service.search(ProductSearchQuery('綾鷹'));

    expect(result.failureOrNull, isNull);
    expect(result.valueOrNull, isNotEmpty);
    expect(result.valueOrNull!.first.product.name, '綾鷹');
    expect(
      result.valueOrNull!.first.matchKind,
      ProductSearchMatchKind.nameExact,
    );
  });

  test('ひらがなkeywordでも商品候補を返す', () async {
    final result = await service.search(ProductSearchQuery('あやたか'));

    expect(result.failureOrNull, isNull);
    expect(result.valueOrNull!.first.product.name, '綾鷹');
    expect(
      result.valueOrNull!.first.matchKind,
      ProductSearchMatchKind.keywordExact,
    );
  });

  test('英字keywordは大小文字を無視する', () async {
    final result = await service.search(ProductSearchQuery('BOSS BLACK'));

    expect(result.failureOrNull, isNull);
    expect(result.valueOrNull!.first.product.name, 'BOSS ブラック');
  });

  test('カタカナ表記でもひらがなkeywordの商品を返す', () async {
    final result = await service.search(ProductSearchQuery('アヤタカ'));

    expect(result.failureOrNull, isNull);
    expect(result.valueOrNull, isNotEmpty);
    expect(result.valueOrNull!.first.product.name, '綾鷹');
  });

  test('全角英字でも半角英字keywordの商品を返す', () async {
    final result = await service.search(ProductSearchQuery('ＢＯＳＳ ＢＬＡＣＫ'));

    expect(result.failureOrNull, isNull);
    expect(result.valueOrNull, isNotEmpty);
    expect(result.valueOrNull!.first.product.name, 'BOSS ブラック');
  });

  test('部分一致でも候補を返す', () async {
    final result = await service.search(ProductSearchQuery('ブラック'));

    expect(result.failureOrNull, isNull);
    expect(
      result.valueOrNull!.any(
        (candidate) => candidate.product.name == 'BOSS ブラック',
      ),
      isTrue,
    );
  });

  test('Product ID完全一致を最優先にする', () async {
    final result = await service.search(
      ProductSearchQuery('suntory_boss_black'),
    );

    expect(result.failureOrNull, isNull);
    expect(result.valueOrNull!.first.product.name, 'BOSS ブラック');
    expect(
      result.valueOrNull!.first.matchKind,
      ProductSearchMatchKind.productIdExact,
    );
  });

  test('空queryではRepositoryを読まず空候補を返す', () async {
    final repository = _CountingProductRepository();
    final target = ProductCandidateSearchService(productRepository: repository);

    final result = await target.search(ProductSearchQuery(' '));

    expect(result.valueOrNull, isEmpty);
    expect(repository.calls, 0);
  });

  test('Repository Failureを保持する', () async {
    final target = ProductCandidateSearchService(
      productRepository: _FailingProductRepository(),
    );

    final result = await target.search(ProductSearchQuery('綾鷹'));

    expect(result.failureOrNull, isA<NetworkFailure>());
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

final class _CountingProductRepository implements ProductRepository {
  int calls = 0;

  @override
  Future<AppResult<Product>> getProduct(ProductId id) async {
    calls += 1;
    return const AppResult<Product>.failure(NotFoundFailure());
  }

  @override
  Future<AppResult<List<Product>>> getProducts({bool activeOnly = true}) async {
    calls += 1;
    return const AppResult<List<Product>>.success(<Product>[]);
  }
}

final class _FailingProductRepository implements ProductRepository {
  @override
  Future<AppResult<Product>> getProduct(ProductId id) async {
    return const AppResult<Product>.failure(NetworkFailure());
  }

  @override
  Future<AppResult<List<Product>>> getProducts({bool activeOnly = true}) async {
    return const AppResult<List<Product>>.failure(NetworkFailure());
  }
}
