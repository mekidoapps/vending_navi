import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vending_app/app/router/app_router.dart';
import 'package:vending_app/app/router/app_route.dart';
import 'package:vending_app/app/router/entry_mode.dart';

void main() {
  testWidgets('legacyを指定すると現行ルートを初期表示する', (WidgetTester tester) async {
    final router = createAppRouter(
      entryMode: AppEntryMode.legacy,
      legacyBuilder: (_) => const Scaffold(body: Text('legacy screen')),
      v2Builder: (_) => const Scaffold(body: Text('v2 screen')),
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.pumpAndSettle();

    expect(find.text('legacy screen'), findsOneWidget);
    expect(find.text('v2 screen'), findsNothing);
  });

  testWidgets('v2を指定するとv2ルートを初期表示する', (WidgetTester tester) async {
    final router = createAppRouter(
      entryMode: AppEntryMode.v2,
      legacyBuilder: (_) => const Scaffold(body: Text('legacy screen')),
      v2Builder: (_) => const Scaffold(body: Text('v2 screen')),
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.pumpAndSettle();

    expect(find.text('v2 screen'), findsOneWidget);
    expect(find.text('legacy screen'), findsNothing);
  });

  testWidgets('名前付きルートでv1とv2を切り替えられる', (WidgetTester tester) async {
    final router = createAppRouter(
      entryMode: AppEntryMode.legacy,
      legacyBuilder: (_) => const Scaffold(body: Text('legacy screen')),
      v2Builder: (_) => const Scaffold(body: Text('v2 screen')),
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.pumpAndSettle();

    router.goNamed(AppRoute.v2Foundation.name);
    await tester.pumpAndSettle();
    expect(find.text('v2 screen'), findsOneWidget);

    router.goNamed(AppRoute.legacyRoot.name);
    await tester.pumpAndSettle();
    expect(find.text('legacy screen'), findsOneWidget);
  });
}
