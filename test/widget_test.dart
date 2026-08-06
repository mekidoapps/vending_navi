import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vending_app/app/bootstrap/bootstrap_result.dart';
import 'package:vending_app/app/router/entry_mode.dart';
import 'package:vending_app/app/vending_navi_app.dart';

void main() {
  testWidgets('起動失敗時にエラー画面を表示する', (WidgetTester tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: VendingNaviApp(
          bootstrapResult: BootstrapResult.failure('test startup error'),
          entryMode: AppEntryMode.legacy,
        ),
      ),
    );

    expect(find.text('起動に失敗しました'), findsOneWidget);
    expect(find.text('test startup error'), findsOneWidget);
  });

  testWidgets('v2指定時に基盤確認画面を表示する', (WidgetTester tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: VendingNaviApp(
          bootstrapResult: BootstrapResult.success(),
          entryMode: AppEntryMode.v2,
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('自販機ナビ v2'), findsOneWidget);
    expect(find.text('デザイン基盤確認'), findsOneWidget);
  });
}
