import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vending_app/app/router/app_router.dart';
import 'package:vending_app/app/router/entry_mode.dart';

void main() {
  testWidgets('v2写真更新routeからmachineIdを受け取れる', (WidgetTester tester) async {
    final router = createAppRouter(
      entryMode: AppEntryMode.v2,
      v2Builder: (_) => const Scaffold(body: Text('home')),
      photoProductUpdateBuilder: (_, machineId) =>
          Scaffold(body: Text('photo-update:${machineId.value}')),
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(MaterialApp.router(routerConfig: router));

    router.go('/v2/machines/machine_001/update/photo');
    await tester.pumpAndSettle();

    expect(find.text('photo-update:machine_001'), findsOneWidget);
  });

  testWidgets('不正machineIdの写真更新routeはroute error画面にする', (
    WidgetTester tester,
  ) async {
    final router = createAppRouter(
      entryMode: AppEntryMode.v2,
      v2Builder: (_) => const Scaffold(body: Text('home')),
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(MaterialApp.router(routerConfig: router));

    router.go('/v2/machines/a%2Fb/update/photo');
    await tester.pumpAndSettle();

    expect(find.text('画面を表示できませんでした'), findsOneWidget);
  });
}
