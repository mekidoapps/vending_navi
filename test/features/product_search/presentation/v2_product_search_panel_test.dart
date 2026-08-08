import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vending_app/core/errors/app_failure.dart';
import 'package:vending_app/core/result/app_result.dart';
import 'package:vending_app/features/product_master/data/fixtures/product_master_fixture.dart';
import 'package:vending_app/features/product_master/domain/entities/product.dart';
import 'package:vending_app/features/product_master/domain/repositories/product_repository.dart';
import 'package:vending_app/features/product_master/domain/value_objects/master_id.dart';
import 'package:vending_app/features/product_search/application/providers/product_search_providers.dart';
import 'package:vending_app/features/product_search/domain/services/product_candidate_search_service.dart';
import 'package:vending_app/features/product_search/presentation/v2_product_search_panel.dart';

void main() {
  testWidgets('入力後に候補を表示して商品を選択できる', (WidgetTester tester) async {
    Product? selected;
    var closed = 0;

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          productCandidateSearchServiceProvider.overrideWithValue(
            ProductCandidateSearchService(
              productRepository: _FixtureProductRepository(),
            ),
          ),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 360,
              height: 420,
              child: V2ProductSearchPanel(
                onProductSelected: (product) => selected = product,
                onClose: () => closed += 1,
              ),
            ),
          ),
        ),
      ),
    );

    await tester.enterText(find.byKey(const Key('productSearchField')), '綾鷹');
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump();

    expect(
      find.byKey(const Key('productCandidate_coca_cola_ayataka')),
      findsOneWidget,
    );

    await tester.tap(
      find.byKey(const Key('productCandidate_coca_cola_ayataka')),
    );
    await tester.pump();

    expect(selected?.name, '綾鷹');
    expect(closed, 0);
  });

  testWidgets('閉じる操作を通知する', (WidgetTester tester) async {
    var closed = 0;

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 360,
              height: 420,
              child: V2ProductSearchPanel(
                onProductSelected: (_) {},
                onClose: () => closed += 1,
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.byKey(const Key('closeProductSearchPanel')));
    await tester.pump();

    expect(closed, 1);
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
