import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vending_app/app/router/app_router.dart';
import 'package:vending_app/app/router/entry_mode.dart';

void main() {
  testWidgets('v2自販機詳細routeからmachineIdを受け取れる', (WidgetTester tester) async {
    final router = createAppRouter(
      entryMode: AppEntryMode.v2,
      v2Builder: (_) => const Scaffold(body: Text('home')),
      machineDetailBuilder: (_, machineId) =>
          Scaffold(body: Text('detail:${machineId.value}')),
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(MaterialApp.router(routerConfig: router));

    router.go('/v2/machines/machine_001');
    await tester.pumpAndSettle();

    expect(find.text('detail:machine_001'), findsOneWidget);
  });

  testWidgets('不正machineId routeはroute error画面にする', (
    WidgetTester tester,
  ) async {
    final router = createAppRouter(
      entryMode: AppEntryMode.v2,
      v2Builder: (_) => const Scaffold(body: Text('home')),
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(MaterialApp.router(routerConfig: router));

    router.go('/v2/machines/a%2Fb');
    await tester.pumpAndSettle();

    expect(find.text('画面を表示できませんでした'), findsOneWidget);
  });
}
