import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vending_app/core/errors/app_failure.dart';
import 'package:vending_app/core/result/app_result.dart';
import 'package:vending_app/features/product_master/data/fixtures/product_master_fixture.dart';
import 'package:vending_app/features/product_master/domain/entities/product.dart';
import 'package:vending_app/features/product_master/domain/entities/product_genre.dart';
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
                onGenreSelected: (_) {},
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
                onGenreSelected: (_) {},
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

  testWidgets('ジャンル候補を表示して選択できる', (WidgetTester tester) async {
    ProductGenre? selectedGenre;

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 360,
              height: 420,
              child: V2ProductSearchPanel(
                onProductSelected: (_) {},
                onGenreSelected: (genre) => selectedGenre = genre,
                onClose: () {},
              ),
            ),
          ),
        ),
      ),
    );

    expect(find.byKey(const Key('genreCandidate_coffee')), findsOneWidget);

    await tester.tap(find.byKey(const Key('genreCandidate_coffee')));
    await tester.pump();

    expect(selectedGenre, ProductGenre.coffee);
  });

  testWidgets('ジャンル追加後も低い検索パネルでoverflowしない', (WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: Scaffold(
            body: Align(
              alignment: Alignment.topLeft,
              child: SizedBox(
                width: 312,
                height: 320,
                child: V2ProductSearchPanel(
                  onProductSelected: (_) {},
                  onGenreSelected: (_) {},
                  onClose: () {},
                ),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.pump();

    expect(tester.takeException(), isNull);
    expect(find.byKey(const Key('genreCandidate_coffee')), findsOneWidget);
  });

  testWidgets('初期状態では架空データを作らずよく飲む商品の空状態を表示する', (WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 360,
              height: 420,
              child: V2ProductSearchPanel(
                onProductSelected: (_) {},
                onGenreSelected: (_) {},
                onClose: () {},
              ),
            ),
          ),
        ),
      ),
    );

    expect(find.text('よく飲む商品'), findsOneWidget);
    expect(find.byKey(const Key('frequentProductsEmpty')), findsOneWidget);
  });

  testWidgets('Phase 5から商品を渡せる接続口を持ち選択時は通常商品選択を使う', (
    WidgetTester tester,
  ) async {
    final product = ProductMasterFixture.products.firstWhere(
      (item) => item.name == '綾鷹',
    );
    Product? selected;

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 360,
              height: 420,
              child: V2ProductSearchPanel(
                frequentProducts: <Product>[product],
                onProductSelected: (value) => selected = value,
                onGenreSelected: (_) {},
                onClose: () {},
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.byKey(Key('frequentProduct_${product.id.value}')));
    await tester.pump();

    expect(selected?.id, product.id);
  });

  testWidgets('商品名を入力するとよく飲む商品から検索候補表示へ切り替える', (WidgetTester tester) async {
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
                onProductSelected: (_) {},
                onGenreSelected: (_) {},
                onClose: () {},
              ),
            ),
          ),
        ),
      ),
    );

    expect(find.text('よく飲む商品'), findsOneWidget);

    await tester.enterText(find.byKey(const Key('productSearchField')), '綾鷹');
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump();

    expect(find.text('候補'), findsOneWidget);
    expect(find.byKey(const Key('frequentProductsEmpty')), findsNothing);
    expect(
      find.byKey(const Key('productCandidate_coca_cola_ayataka')),
      findsOneWidget,
    );
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
