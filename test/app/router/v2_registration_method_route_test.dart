import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vending_app/app/router/app_router.dart';
import 'package:vending_app/app/router/entry_mode.dart';

void main() {
  testWidgets('v2登録方法routeを開ける', (WidgetTester tester) async {
    final router = createAppRouter(
      entryMode: AppEntryMode.v2,
      v2Builder: (_) => const Scaffold(body: Text('home')),
      registrationMethodBuilder: (_) =>
          const Scaffold(body: Text('registration-method')),
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(MaterialApp.router(routerConfig: router));

    router.go('/v2/register/method');
    await tester.pumpAndSettle();

    expect(find.text('registration-method'), findsOneWidget);
  });
}
