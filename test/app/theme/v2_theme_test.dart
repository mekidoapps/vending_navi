import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vending_app/app/theme/v2_color_tokens.dart';
import 'package:vending_app/app/theme/v2_theme.dart';

void main() {
  test('v2テーマへSky Blueトークンが登録される', () {
    final theme = V2Theme.light();
    final colors = theme.extension<V2ColorTokens>();

    expect(colors, isNotNull);
    expect(colors!.primary, V2ColorTokens.skyBlue.primary);
    expect(theme.scaffoldBackgroundColor, V2ColorTokens.skyBlue.surface);
    expect(theme.useMaterial3, isTrue);
  });

  testWidgets('テーマ配下からカラートークンを取得できる', (WidgetTester tester) async {
    late V2ColorTokens actual;

    await tester.pumpWidget(
      MaterialApp(
        theme: V2Theme.light(),
        home: Builder(
          builder: (BuildContext context) {
            actual = V2ColorTokens.of(context);
            return const SizedBox.shrink();
          },
        ),
      ),
    );

    expect(actual.primaryStrong, V2ColorTokens.skyBlue.primaryStrong);
  });
}
