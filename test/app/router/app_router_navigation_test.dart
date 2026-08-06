import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vending_app/app/router/app_route.dart';
import 'package:vending_app/app/router/app_router.dart';
import 'package:vending_app/app/router/entry_mode.dart';

void main() {
  testWidgets('v2パスを直接指定して表示できる', (WidgetTester tester) async {
    final router = createAppRouter(
      entryMode: AppEntryMode.legacy,
      legacyBuilder: (_) => const Scaffold(body: Text('legacy screen')),
      v2Builder: (_) => const Scaffold(body: Text('v2 screen')),
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.pump();

    router.go(AppRoute.v2Foundation.path);
    await tester.pumpAndSettle();

    expect(find.text('v2 screen'), findsOneWidget);
    expect(find.text('legacy screen'), findsNothing);
  });

  testWidgets('v2へpushした後に戻ると現行ルートへ復帰する', (WidgetTester tester) async {
    final router = createAppRouter(
      entryMode: AppEntryMode.legacy,
      legacyBuilder: (_) => const Scaffold(body: Text('legacy screen')),
      v2Builder: (_) => const Scaffold(body: Text('v2 screen')),
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.pumpAndSettle();

    router.pushNamed(AppRoute.v2Foundation.name);
    await tester.pumpAndSettle();
    expect(find.text('v2 screen'), findsOneWidget);
    expect(router.canPop(), isTrue);

    router.pop();
    await tester.pumpAndSettle();
    expect(find.text('legacy screen'), findsOneWidget);
  });

  testWidgets('不明なパスではルートエラー画面を表示する', (WidgetTester tester) async {
    final router = createAppRouter(
      entryMode: AppEntryMode.legacy,
      legacyBuilder: (_) => const Scaffold(body: Text('legacy screen')),
      v2Builder: (_) => const Scaffold(body: Text('v2 screen')),
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.pump();

    router.go('/not-found');
    await tester.pumpAndSettle();

    expect(find.text('画面を表示できませんでした'), findsOneWidget);
    expect(find.text('/not-found'), findsOneWidget);
  });
}
