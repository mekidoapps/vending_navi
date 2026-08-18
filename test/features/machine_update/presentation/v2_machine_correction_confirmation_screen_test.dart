import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../../lib/core/result/app_result.dart';
import '../../../../lib/features/machine_update/application/machine_correction_controller.dart';
import '../../../../lib/features/machine_update/domain/models/machine_correction_draft.dart';
import '../../../../lib/features/machine_update/domain/models/machine_correction_field.dart';
import '../../../../lib/features/machine_update/presentation/v2_machine_correction_confirmation_screen.dart';
import '../../../../lib/features/product_master/domain/value_objects/master_id.dart';
import '../../../../lib/features/vending_machine/application/models/vending_machine_detail_data.dart';
import '../../../../lib/features/vending_machine/application/providers/vending_machine_detail_providers.dart';
import '../../../../lib/features/vending_machine/domain/entities/vending_machine.dart';
import '../../../../lib/features/vending_machine/domain/entities/vending_machine_enums.dart';
import '../../../../lib/features/vending_machine/domain/value_objects/geo_coordinate.dart';
import '../../../../lib/features/vending_machine/domain/value_objects/vending_machine_id.dart';

void main() {
  testWidgets('missing correction draft is rejected safely', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: V2MachineCorrectionConfirmationScreen(
            machineId: _machineId,
            onCompleted: () {},
          ),
        ),
      ),
    );

    await tester.pump();

    expect(
      find.byKey(const Key('missingMachineCorrectionDraft')),
      findsOneWidget,
    );

    expect(find.textContaining('確認できる修正内容がありません'), findsOneWidget);
  });

  testWidgets('confirmation shows changed fields and moderation notice', (
    tester,
  ) async {
    final container = ProviderContainer(
      overrides: [
        vendingMachineDetailProvider.overrideWith((ref, machineId) async {
          return AppResult<VendingMachineDetailData>.success(_detail());
        }),
      ],
    );
    addTearDown(container.dispose);

    container
        .read(machineCorrectionControllerProvider.notifier)
        .begin(
          MachineCorrectionDraft(
            machineId: _machineId,
            name: const MachineCorrectionField<String>.changed('東京駅東口 自販機'),
          ),
        );

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          home: V2MachineCorrectionConfirmationScreen(
            machineId: _machineId,
            onCompleted: () {},
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(
      find.byKey(const Key('machineCorrectionReview_name')),
      findsOneWidget,
    );

    expect(find.text('駅東口の自販機'), findsOneWidget);
    expect(find.text('東京駅東口 自販機'), findsOneWidget);

    final notice = find.byKey(const Key('machineCorrectionModerationNotice'));

    await tester.ensureVisible(notice);

    expect(notice, findsOneWidget);

    expect(find.textContaining('修正内容はすぐには反映されません'), findsOneWidget);
  });
}

final VendingMachineId _machineId = VendingMachineId.tryParse('machine-001')!;

VendingMachineDetailData _detail() {
  return VendingMachineDetailData(
    machine: VendingMachine(
      id: _machineId,
      schemaVersion: 2,
      name: '駅東口の自販機',
      manufacturerId: ManufacturerId.tryParse('suntory')!,
      manufacturerStatus: ManufacturerStatus.confirmed,
      location: GeoCoordinate(latitude: 35.681236, longitude: 139.767125),
      geohash: 'xn76ur',
      placeDescription: '駅東口の壁沿い',
      installationType: InstallationType.outdoor,
      status: VendingMachineStatus.active,
      dataLevel: VendingMachineDataLevel.manufacturerOnly,
      createdBy: 'fixture-user',
    ),
    manufacturerName: 'サントリー',
    products: const [],
  );
}
