import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vending_app/features/ugc_terms/presentation/ugc_terms_gate.dart';

void main() {
  testWidgets('投稿ルールの確認はsmall viewportでも表示される', (tester) async {
    await tester.binding.setSurfaceSize(const Size(320, 568));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(const MaterialApp(home: Scaffold(body: UgcTermsSheet())));
    expect(find.text('投稿ルールの確認'), findsOneWidget);
    expect(find.text('同意して続ける'), findsOneWidget);
    expect(find.text('キャンセル'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
