import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vending_app/core/result/app_result.dart';
import 'package:vending_app/features/product_master/domain/value_objects/master_id.dart';
import 'package:vending_app/features/vending_machine/application/models/vending_machine_detail_data.dart';
import 'package:vending_app/features/vending_machine/application/providers/vending_machine_detail_providers.dart';
import 'package:vending_app/features/vending_machine/domain/entities/vending_machine.dart';
import 'package:vending_app/features/vending_machine/domain/entities/vending_machine_enums.dart';
import 'package:vending_app/features/vending_machine/domain/entities/vending_machine_product.dart';
import 'package:vending_app/features/vending_machine/domain/value_objects/geo_coordinate.dart';
import 'package:vending_app/features/vending_machine/domain/value_objects/vending_machine_id.dart';
import 'package:vending_app/features/vending_machine/presentation/v2_vending_machine_detail_screen.dart';

void main() {
  testWidgets('自販機詳細にメーカー・場所・確認状態・在庫状態を表示する', (WidgetTester tester) async {
    final data = _detailData();

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
    await tester.pump();

    expect(find.text('自販機詳細'), findsOneWidget);
    expect(find.text('駅前の自販機'), findsOneWidget);
    expect(find.text('サントリー'), findsWidgets);
    expect(find.text('駅東口の壁沿い'), findsOneWidget);
    expect(find.text('BOSS ブラック'), findsOneWidget);
    expect(find.text('サントリー天然水'), findsOneWidget);
    expect(find.text('確認済み'), findsWidgets);
    expect(find.text('あるかも'), findsWidgets);
    expect(find.text('販売中'), findsOneWidget);
    expect(find.text('在庫不明'), findsOneWidget);
  });
}

VendingMachineDetailData _detailData() {
  final machine = VendingMachine(
    id: VendingMachineId.parse('machine_detail'),
    schemaVersion: 2,
    name: '駅前の自販機',
    manufacturerId: ManufacturerId.parse('suntory'),
    manufacturerStatus: ManufacturerStatus.confirmed,
    location: GeoCoordinate(latitude: 35.681236, longitude: 139.767125),
    geohash: 'xn76ur',
    placeDescription: '駅東口の壁沿い',
    installationType: InstallationType.outdoor,
    status: VendingMachineStatus.active,
    dataLevel: VendingMachineDataLevel.productsConfirmed,
    createdBy: 'test',
    products: <VendingMachineProduct>[
      VendingMachineProduct(
        productId: ProductId.parse('suntory_boss_black'),
        evidenceType: ProductEvidenceType.manualConfirmed,
        availability: ProductAvailability.available,
      ),
      VendingMachineProduct(
        productId: ProductId.parse('suntory_tennensui'),
        evidenceType: ProductEvidenceType.manufacturerInferred,
        availability: ProductAvailability.unknown,
      ),
    ],
  );

  return VendingMachineDetailData(
    machine: machine,
    manufacturerName: 'サントリー',
    products: <VendingMachineProductDetailItem>[
      VendingMachineProductDetailItem(
        productId: ProductId.parse('suntory_boss_black'),
        productName: 'BOSS ブラック',
        evidenceType: ProductEvidenceType.manualConfirmed,
        availability: ProductAvailability.available,
      ),
      VendingMachineProductDetailItem(
        productId: ProductId.parse('suntory_tennensui'),
        productName: 'サントリー天然水',
        evidenceType: ProductEvidenceType.manufacturerInferred,
        availability: ProductAvailability.unknown,
      ),
    ],
  );
}
