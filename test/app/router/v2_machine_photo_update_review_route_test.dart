import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vending_app/app/router/app_router.dart';
import 'package:vending_app/app/router/entry_mode.dart';

void main() {
  testWidgets('v2写真更新確認routeからmachineIdを受け取れる', (WidgetTester tester) async {
    final router = createAppRouter(
      entryMode: AppEntryMode.v2,
      v2Builder: (_) => const Scaffold(body: Text('home')),
      photoProductUpdateConfirmationBuilder: (_, machineId) =>
          Scaffold(body: Text('photo-review:${machineId.value}')),
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(MaterialApp.router(routerConfig: router));

    router.go('/v2/machines/machine_001/update/photo/confirm');
    await tester.pumpAndSettle();

    expect(find.text('photo-review:machine_001'), findsOneWidget);
  });
}
