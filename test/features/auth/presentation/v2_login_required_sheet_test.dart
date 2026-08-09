import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vending_app/app/theme/v2_theme.dart';
import 'package:vending_app/features/auth/presentation/v2_login_required_sheet.dart';

void main() {
  testWidgets('未ログイン操作の説明とログイン導線を表示する', (WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: V2Theme.light(),
        home: Builder(
          builder: (context) {
            return Scaffold(
              body: FilledButton(
                key: const Key('openLoginSheet'),
                onPressed: () {
                  V2LoginRequiredSheet.show(context, actionLabel: '自販機の登録');
                },
                child: const Text('open'),
              ),
            );
          },
        ),
      ),
    );

    await tester.tap(find.byKey(const Key('openLoginSheet')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('loginRequiredSheet')), findsOneWidget);
    expect(find.text('この操作はログインが必要です'), findsOneWidget);
    expect(find.textContaining('自販機の登録'), findsOneWidget);
    expect(find.byKey(const Key('loginRequiredContinue')), findsOneWidget);
    expect(find.byKey(const Key('loginRequiredCancel')), findsOneWidget);
  });

  testWidgets('今はしないでfalseを返す', (WidgetTester tester) async {
    bool? result;

    await tester.pumpWidget(
      MaterialApp(
        theme: V2Theme.light(),
        home: Builder(
          builder: (context) {
            return Scaffold(
              body: FilledButton(
                key: const Key('openLoginSheet'),
                onPressed: () async {
                  result = await V2LoginRequiredSheet.show(
                    context,
                    actionLabel: '自販機の登録',
                  );
                },
                child: const Text('open'),
              ),
            );
          },
        ),
      ),
    );

    await tester.tap(find.byKey(const Key('openLoginSheet')));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('loginRequiredCancel')));
    await tester.pumpAndSettle();

    expect(result, isFalse);
  });

  testWidgets('ログイン選択でtrueを返す', (WidgetTester tester) async {
    bool? result;

    await tester.pumpWidget(
      MaterialApp(
        theme: V2Theme.light(),
        home: Builder(
          builder: (context) {
            return Scaffold(
              body: FilledButton(
                key: const Key('openLoginSheet'),
                onPressed: () async {
                  result = await V2LoginRequiredSheet.show(
                    context,
                    actionLabel: '自販機の登録',
                  );
                },
                child: const Text('open'),
              ),
            );
          },
        ),
      ),
    );

    await tester.tap(find.byKey(const Key('openLoginSheet')));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('loginRequiredContinue')));
    await tester.pumpAndSettle();

    expect(result, isTrue);
  });
}
