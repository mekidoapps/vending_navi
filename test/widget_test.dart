import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vending_app/app/bootstrap/bootstrap_result.dart';
import 'package:vending_app/app/vending_navi_app.dart';

void main() {
  testWidgets('起動失敗時にエラー画面を表示する', (WidgetTester tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: VendingNaviApp(
          bootstrapResult: BootstrapResult.failure('test startup error'),
        ),
      ),
    );

    expect(find.text('起動に失敗しました'), findsOneWidget);
    expect(find.text('test startup error'), findsOneWidget);
  });
}
