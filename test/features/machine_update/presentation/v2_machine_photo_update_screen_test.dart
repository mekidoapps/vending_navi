import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../../lib/features/machine_update/presentation/v2_machine_photo_update_screen.dart';
import '../../../../lib/features/vending_machine/domain/value_objects/vending_machine_id.dart';

void main() {
  testWidgets('写真更新画面はAIが自動確定しないことを表示する', (tester) async {
    final machineId = VendingMachineId.tryParse('machine-test-001')!;

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: V2MachinePhotoUpdateScreen(machineId: machineId),
        ),
      ),
    );

    expect(find.text('写真から商品情報を更新'), findsOneWidget);
    expect(find.text('今の自販機を撮影してください'), findsOneWidget);
    expect(find.textContaining('AIの結果だけで自動更新はせず'), findsOneWidget);
    expect(
      find.byKey(const Key('machinePhotoUpdateCaptureButton')),
      findsOneWidget,
    );
    expect(find.text('カメラで撮影'), findsOneWidget);
  });
}
