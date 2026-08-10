import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vending_app/features/product_search/presentation/v2_frequent_products_section.dart';

void main() {
  testWidgets('未ログイン時は架空商品ではなくログイン導線を表示する', (WidgetTester tester) async {
    var requested = false;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            height: 220,
            child: V2FrequentProductsSection(
              products: const [],
              isAuthenticated: false,
              onLoginRequested: () {
                requested = true;
              },
              onSelected: (_) {},
            ),
          ),
        ),
      ),
    );

    expect(
      find.byKey(const Key('frequentProductsLoginRequired')),
      findsOneWidget,
    );
    expect(find.byKey(const Key('frequentProductsEmpty')), findsNothing);

    await tester.tap(find.byKey(const Key('frequentProductsLoginButton')));

    expect(requested, isTrue);
  });
}
