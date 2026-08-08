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
  testWidgets('商品検索から詳細へ入ると検索対象表示を引き継ぐ', (WidgetTester tester) async {
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

    expect(find.byKey(const Key('detailSearchPriorityNotice')), findsOneWidget);
    expect(find.text('検索条件「BOSS ブラック」に合う商品を先に表示しています'), findsOneWidget);
    expect(find.text('検索対象'), findsOneWidget);
  });
}

VendingMachineDetailData _detailData() {
  final machine = VendingMachine(
    id: VendingMachineId.parse('machine_detail_search'),
    schemaVersion: 2,
    name: '検索詳細テスト自販機',
    manufacturerStatus: ManufacturerStatus.confirmed,
    location: GeoCoordinate(latitude: 35.68, longitude: 139.76),
    geohash: 'xn76',
    installationType: InstallationType.outdoor,
    status: VendingMachineStatus.active,
    dataLevel: VendingMachineDataLevel.productsConfirmed,
    createdBy: 'test',
  );

  return VendingMachineDetailData(
    machine: machine,
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
