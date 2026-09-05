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
    expect(theme.textTheme.bodyMedium?.fontFamily, V2Theme.japaneseFontFamily);
    expect(theme.textTheme.bodyMedium?.fontFamilyFallback, <String>[
      V2Theme.japaneseFontFamily,
    ]);
    expect(
      theme.primaryTextTheme.titleMedium?.fontFamily,
      V2Theme.japaneseFontFamily,
    );
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

  testWidgets('日本語localeでも代表的なv2文言はNoto Sans JPで描画する', (
    WidgetTester tester,
  ) async {
    late Text text;

    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('ja', 'JP'),
        theme: V2Theme.light(),
        home: Scaffold(
          body: Builder(
            builder: (BuildContext context) {
              return Text(
                '登録・確認・詳細・情報・更新・検索・位置',
                key: const Key('japaneseTypographySample'),
                style: Theme.of(context).textTheme.bodyMedium,
              );
            },
          ),
        ),
      ),
    );

    text = tester.widget<Text>(
      find.byKey(const Key('japaneseTypographySample')),
    );

    expect(text.style?.fontFamily, V2Theme.japaneseFontFamily);
    expect(text.style?.fontFamilyFallback, <String>[
      V2Theme.japaneseFontFamily,
    ]);
  });
}
