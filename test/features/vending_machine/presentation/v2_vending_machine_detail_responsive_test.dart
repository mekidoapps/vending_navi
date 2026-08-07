import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vending_app/core/result/app_result.dart';
import 'package:vending_app/features/product_master/domain/value_objects/master_id.dart';
import 'package:vending_app/features/vending_machine/application/models/vending_machine_detail_data.dart';
import 'package:vending_app/features/vending_machine/application/providers/vending_machine_detail_providers.dart';
import 'package:vending_app/features/vending_machine/domain/entities/vending_machine.dart';
import 'package:vending_app/features/vending_machine/domain/entities/vending_machine_enums.dart';
import 'package:vending_app/features/vending_machine/domain/value_objects/geo_coordinate.dart';
import 'package:vending_app/features/vending_machine/domain/value_objects/vending_machine_id.dart';
import 'package:vending_app/features/vending_machine/presentation/v2_vending_machine_detail_screen.dart';

void main() {
  for (final size in <Size>[
    const Size(320, 568),
    const Size(390, 844),
    const Size(600, 960),
  ]) {
    testWidgets(
      '詳細画面 ${size.width.toInt()}x${size.height.toInt()} でoverflowしない',
      (WidgetTester tester) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        final data = _data();

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              vendingMachineDetailProvider(data.machine.id).overrideWithValue(
                AsyncValue<AppResult<VendingMachineDetailData>>.data(
                  AppResult<VendingMachineDetailData>.success(data),
                ),
              ),
            ],
            child: MaterialApp(
              home: V2VendingMachineDetailScreen(machineId: data.machine.id),
            ),
          ),
        );

        await tester.pump();

        expect(tester.takeException(), isNull);
        expect(find.text('ここまでの経路を見る'), findsOneWidget);
      },
    );
  }
}

VendingMachineDetailData _data() {
  return VendingMachineDetailData(
    machine: VendingMachine(
      id: VendingMachineId.parse('machine_responsive'),
      schemaVersion: 2,
      name: '長めの名前でも確認する駅前の自販機',
      manufacturerId: ManufacturerId.parse('suntory'),
      manufacturerStatus: ManufacturerStatus.confirmed,
      location: GeoCoordinate(latitude: 35.681236, longitude: 139.767125),
      geohash: 'xn76ur',
      placeDescription: '駅東口の壁沿い・改札を出て右側',
      installationType: InstallationType.outdoor,
      status: VendingMachineStatus.active,
      dataLevel: VendingMachineDataLevel.locationOnly,
      createdBy: 'test',
    ),
    manufacturerName: 'サントリー',
    products: const [],
  );
}
