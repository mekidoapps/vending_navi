import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vending_app/app/router/app_route.dart';
import 'package:vending_app/app/router/app_router.dart';
import 'package:vending_app/app/router/entry_mode.dart';

void main() {
  testWidgets('v2 email auth routeを名前付きrouteで開ける', (WidgetTester tester) async {
    final router = createAppRouter(
      entryMode: AppEntryMode.v2,
      v2Builder: (_) => const Scaffold(body: Text('v2 home')),
      emailAuthBuilder: (_) => const Scaffold(body: Text('email auth')),
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.pumpAndSettle();

    router.goNamed(AppRoute.v2EmailAuth.name);
    await tester.pumpAndSettle();

    expect(find.text('email auth'), findsOneWidget);
  });
}
