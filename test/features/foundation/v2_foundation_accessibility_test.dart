import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:vending_app/app/router/app_route.dart';
import 'package:vending_app/features/foundation/presentation/v2_foundation_screen.dart';

void main() {
  testWidgets('文字を2倍にしても主要ボタンを表示・操作できる', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final router = GoRouter(
      initialLocation: AppRoute.v2Foundation.path,
      routes: <RouteBase>[
        GoRoute(
          name: AppRoute.v2Foundation.name,
          path: AppRoute.v2Foundation.path,
          builder: (_, _) => const V2FoundationScreen(),
        ),
        GoRoute(
          name: AppRoute.legacyRoot.name,
          path: AppRoute.legacyRoot.path,
          builder: (_, _) => const Scaffold(body: Text('legacy')),
        ),
      ],
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(
      MaterialApp.router(
        routerConfig: router,
        builder: (BuildContext context, Widget? child) {
          return MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: const TextScaler.linear(2)),
            child: child!,
          );
        },
      ),
    );

    // Loading表示は継続アニメーションを含むためpumpAndSettleは使わない。
    await tester.pump(const Duration(milliseconds: 300));

    expect(tester.takeException(), isNull);
    expect(find.text('ここに行く'), findsOneWidget);
    expect(find.text('情報を更新する'), findsOneWidget);

    final primaryButton = find.widgetWithText(FilledButton, 'ここに行く');
    await tester.ensureVisible(primaryButton);
    await tester.tap(primaryButton);
    await tester.pump();

    expect(tester.takeException(), isNull);
  });
}
