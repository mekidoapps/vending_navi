import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vending_app/app/router/app_router.dart';
import 'package:vending_app/app/router/entry_mode.dart';

void main() {
  testWidgets('v2登録位置routeを開ける', (WidgetTester tester) async {
    final router = createAppRouter(
      entryMode: AppEntryMode.v2,
      v2Builder: (_) => const Scaffold(body: Text('home')),
      registrationPositionBuilder: (_) =>
          const Scaffold(body: Text('registration-position')),
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(MaterialApp.router(routerConfig: router));

    router.go('/v2/register/position');
    await tester.pumpAndSettle();

    expect(find.text('registration-position'), findsOneWidget);
  });
}
