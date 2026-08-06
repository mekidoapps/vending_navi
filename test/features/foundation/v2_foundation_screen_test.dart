import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:vending_app/features/foundation/presentation/v2_foundation_screen.dart';

void main() {
  testWidgets('基盤画面に共通UIが表示される', (WidgetTester tester) async {
    final router = GoRouter(
      initialLocation: '/v2',
      routes: <RouteBase>[
        GoRoute(path: '/v2', builder: (_, __) => const V2FoundationScreen()),
        GoRoute(
          name: 'legacyRoot',
          path: '/',
          builder: (_, __) => const Scaffold(body: Text('legacy')),
        ),
      ],
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('デザイン基盤確認'), findsOneWidget);
    expect(find.text('ここに行く'), findsOneWidget);
    expect(find.text('情報を更新する'), findsOneWidget);
    expect(find.text('確認済み'), findsOneWidget);
    expect(find.text('あるかも'), findsOneWidget);
    expect(find.text('以前の情報'), findsOneWidget);
  });

  testWidgets('探すボタンを登録・マイより大きく表示する', (WidgetTester tester) async {
    final router = GoRouter(
      initialLocation: '/v2',
      routes: <RouteBase>[
        GoRoute(path: '/v2', builder: (_, __) => const V2FoundationScreen()),
        GoRoute(
          name: 'legacyRoot',
          path: '/',
          builder: (_, __) => const Scaffold(body: Text('legacy')),
        ),
      ],
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.pump(const Duration(milliseconds: 300));

    final searchSize = tester.getSize(find.byKey(const Key('searchMapAction')));
    final registerSize = tester.getSize(
      find.byKey(const Key('registerMapAction')),
    );
    final profileSize = tester.getSize(
      find.byKey(const Key('profileMapAction')),
    );

    expect(searchSize.width, greaterThan(registerSize.width));
    expect(searchSize.width, greaterThan(profileSize.width));
    expect(searchSize.height, greaterThan(registerSize.height));
  });
}
