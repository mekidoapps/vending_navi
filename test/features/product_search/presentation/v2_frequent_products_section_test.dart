import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vending_app/features/product_master/data/fixtures/product_master_fixture.dart';
import 'package:vending_app/features/product_master/domain/entities/product.dart';
import 'package:vending_app/features/product_search/presentation/v2_frequent_products_section.dart';

void main() {
  testWidgets('実データがない時は自然な空状態を表示する', (WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 320,
            height: 140,
            child: V2FrequentProductsSection(
              products: const <Product>[],
              onSelected: (_) {},
            ),
          ),
        ),
      ),
    );

    expect(find.byKey(const Key('frequentProductsEmpty')), findsOneWidget);
    expect(find.text('よく飲む商品はまだありません'), findsOneWidget);
    expect(find.byKey(const Key('frequentProductsList')), findsNothing);
  });

  testWidgets('渡された商品を表示して通常の商品選択へ渡せる', (WidgetTester tester) async {
    final product = ProductMasterFixture.products.firstWhere(
      (item) => item.name == '綾鷹',
    );
    Product? selected;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 320,
            height: 180,
            child: V2FrequentProductsSection(
              products: <Product>[product],
              onSelected: (value) => selected = value,
            ),
          ),
        ),
      ),
    );

    expect(
      find.byKey(Key('frequentProduct_${product.id.value}')),
      findsOneWidget,
    );

    await tester.tap(find.byKey(Key('frequentProduct_${product.id.value}')));
    await tester.pump();

    expect(selected?.id, product.id);
  });
}
