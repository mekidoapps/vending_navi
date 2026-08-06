import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vending_app/app/theme/v2_theme.dart';
import 'package:vending_app/core/ui/badges/v2_status_badge.dart';

void main() {
  testWidgets('状態を色だけでなくアイコンと文言で表示する', (WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: V2Theme.light(),
        home: const Scaffold(
          body: Column(
            children: <Widget>[
              V2StatusBadge(type: V2StatusBadgeType.confirmed),
              V2StatusBadge(type: V2StatusBadgeType.inferred),
              V2StatusBadge(type: V2StatusBadgeType.stale),
            ],
          ),
        ),
      ),
    );

    expect(find.text('確認済み'), findsOneWidget);
    expect(find.text('あるかも'), findsOneWidget);
    expect(find.text('以前の情報'), findsOneWidget);
    expect(find.byIcon(Icons.check_circle_rounded), findsOneWidget);
    expect(find.byIcon(Icons.help_rounded), findsOneWidget);
    expect(find.byIcon(Icons.schedule_rounded), findsOneWidget);
  });
}
