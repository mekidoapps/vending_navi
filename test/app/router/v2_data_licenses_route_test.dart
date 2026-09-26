import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vending_app/app/router/app_route.dart';
import 'package:vending_app/app/router/app_router.dart';
import 'package:vending_app/app/router/entry_mode.dart';

void main() {
  testWidgets('データ・ライセンス画面へ名前付きrouteで遷移できる', (tester) async {
    final router = createAppRouter(
      entryMode: AppEntryMode.v2,
      v2Builder: (_) => const Scaffold(body: Text('v2 home')),
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.pumpAndSettle();

    router.goNamed(AppRoute.v2DataLicenses.name);
    await tester.pumpAndSettle();

    expect(find.text('データ・ライセンス'), findsOneWidget);
    expect(find.text('© OpenStreetMap contributors'), findsOneWidget);
  });
}
