import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vending_app/app/router/app_router.dart';
import 'package:vending_app/app/router/entry_mode.dart';

void main() {
  testWidgets('v2重複候補routeを開ける', (WidgetTester tester) async {
    final router = createAppRouter(
      entryMode: AppEntryMode.v2,
      v2Builder: (_) => const Scaffold(body: Text('home')),
      registrationDuplicatesBuilder: (_) =>
          const Scaffold(body: Text('registration-duplicates')),
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(MaterialApp.router(routerConfig: router));

    router.go('/v2/register/duplicates');
    await tester.pumpAndSettle();

    expect(find.text('registration-duplicates'), findsOneWidget);
  });
}
