import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../../lib/features/machine_update/presentation/v2_machine_update_menu_screen.dart';
import '../../../../lib/features/vending_machine/domain/value_objects/vending_machine_id.dart';

void main() {
  testWidgets('manual product update action is available', (tester) async {
    var pressed = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: V2MachineUpdateMenuScreen(
          machineId: VendingMachineId.tryParse('machine-001')!,
          onManualProductUpdatePressed: () {
            pressed += 1;
          },
        ),
      ),
    );

    expect(
      find.byKey(const Key('manualProductUpdateMenuItem')),
      findsOneWidget,
    );
    expect(find.text('商品情報を更新'), findsOneWidget);

    await tester.tap(find.byKey(const Key('manualProductUpdateMenuItem')));
    await tester.pump();

    expect(pressed, 1);
  });
}
