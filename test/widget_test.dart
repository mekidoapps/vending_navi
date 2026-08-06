import 'package:flutter_test/flutter_test.dart';
import 'package:vending_app/main.dart';

void main() {
  testWidgets('app builds smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(
      const VendingApp(startupError: 'test startup error'),
    );

    expect(find.text('起動に失敗しました'), findsOneWidget);
  });
}
