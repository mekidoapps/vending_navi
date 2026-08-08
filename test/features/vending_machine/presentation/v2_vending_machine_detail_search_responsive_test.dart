import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vending_app/core/result/app_result.dart';
import 'package:vending_app/features/product_master/data/fixtures/product_master_fixture.dart';
import 'package:vending_app/features/product_master/domain/entities/product_genre.dart';
import 'package:vending_app/features/product_master/domain/value_objects/master_id.dart';
import 'package:vending_app/features/product_search/application/product_search_selection_controller.dart';
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
      '検索中詳細 ${size.width.toInt()}x${size.height.toInt()} でoverflowしない',
      (WidgetTester tester) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        final data = _detailData();
        final boss = ProductMasterFixture.products.firstWhere(
          (product) => product.id.value == 'suntory_boss_black',
        );

        final container = ProviderContainer(
          overrides: [
            vendingMachineDetailProvider(data.machine.id).overrideWithValue(
              AsyncValue<AppResult<VendingMachineDetailData>>.data(
                AppResult<VendingMachineDetailData>.success(data),
              ),
            ),
          ],
        );
        addTearDown(container.dispose);

        container
            .read(productSearchSelectionControllerProvider.notifier)
            .select(boss);

        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: MaterialApp(
              home: V2VendingMachineDetailScreen(machineId: data.machine.id),
            ),
          ),
        );

        await tester.pump();
        await tester.pump();

        expect(tester.takeException(), isNull);
        expect(
          find.byKey(const Key('detailSearchPriorityNotice')),
          findsOneWidget,
        );
        expect(find.text('検索対象'), findsOneWidget);
        expect(find.text('ここまでの経路を見る'), findsOneWidget);
      },
    );
  }
}

VendingMachineDetailData _detailData() {
  return VendingMachineDetailData(
    machine: VendingMachine(
      id: VendingMachineId.parse('machine_phase4_responsive'),
      schemaVersion: 2,
      name: '駅東口の検索対象自販機',
      manufacturerId: ManufacturerId.parse('suntory'),
      manufacturerStatus: ManufacturerStatus.confirmed,
      location: GeoCoordinate(latitude: 35.681236, longitude: 139.767125),
      geohash: 'xn76ur',
      placeDescription: '駅東口の壁沿い',
      installationType: InstallationType.outdoor,
      status: VendingMachineStatus.active,
      dataLevel: VendingMachineDataLevel.productsConfirmed,
      createdBy: 'test',
    ),
    manufacturerName: 'サントリー',
    products: <VendingMachineProductDetailItem>[
      VendingMachineProductDetailItem(
        productId: ProductId.parse('suntory_tennensui'),
        productName: 'サントリー天然水',
        evidenceType: ProductEvidenceType.manualConfirmed,
        availability: ProductAvailability.available,
        genres: const <ProductGenre>[ProductGenre.water],
      ),
      VendingMachineProductDetailItem(
        productId: ProductId.parse('suntory_boss_black'),
        productName: 'BOSS ブラック',
        evidenceType: ProductEvidenceType.manufacturerInferred,
        availability: ProductAvailability.available,
        genres: const <ProductGenre>[ProductGenre.coffee],
      ),
    ],
  );
}
