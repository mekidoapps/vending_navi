import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vending_app/app/theme/v2_theme.dart';
import 'package:vending_app/core/errors/app_failure.dart';
import 'package:vending_app/core/ui/states/v2_error_state.dart';

void main() {
  testWidgets('AppFailureの安全な文言をエラー表示へ接続する', (WidgetTester tester) async {
    var retried = false;

    await tester.pumpWidget(
      MaterialApp(
        theme: V2Theme.light(),
        home: Scaffold(
          body: V2ErrorState.fromFailure(
            failure: const NetworkFailure(),
            onRetry: () => retried = true,
          ),
        ),
      ),
    );

    expect(find.text('通信できませんでした'), findsOneWidget);
    expect(find.text('通信状態を確認して、もう一度お試しください。'), findsOneWidget);
    expect(find.text('再試行'), findsOneWidget);

    await tester.tap(find.text('再試行'));
    expect(retried, isTrue);
  });

  testWidgets('再試行できないFailureでは再試行ボタンを表示しない', (WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: V2Theme.light(),
        home: Scaffold(
          body: V2ErrorState.fromFailure(
            failure: const PermissionFailure(),
            onRetry: () {},
          ),
        ),
      ),
    );

    expect(find.text('操作できませんでした'), findsOneWidget);
    expect(find.text('再試行'), findsNothing);
  });
}
