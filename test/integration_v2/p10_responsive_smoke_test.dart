import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vending_app/core/result/app_result.dart';
import 'package:vending_app/features/machine_registration/application/machine_registration_controller.dart';
import 'package:vending_app/features/machine_registration/application/manufacturer_selection_controller.dart';
import 'package:vending_app/features/machine_registration/presentation/v2_registration_confirmation_screen.dart';
import 'package:vending_app/features/machine_update/application/providers/machine_correction_providers.dart';
import 'package:vending_app/features/machine_update/presentation/v2_machine_correction_screen.dart';
import 'package:vending_app/features/machine_update/presentation/v2_manual_product_update_screen.dart';
import 'package:vending_app/features/product_master/application/providers/product_master_providers.dart';
import 'package:vending_app/features/product_master/domain/entities/manufacturer.dart';
import 'package:vending_app/features/product_master/domain/repositories/manufacturer_repository.dart';
import 'package:vending_app/features/product_master/domain/value_objects/master_id.dart';
import 'package:vending_app/features/vending_machine/application/models/vending_machine_detail_data.dart';
import 'package:vending_app/features/vending_machine/application/providers/vending_machine_detail_providers.dart';
import 'package:vending_app/features/vending_machine/domain/entities/vending_machine.dart';
import 'package:vending_app/features/vending_machine/domain/entities/vending_machine_enums.dart';
import 'package:vending_app/features/vending_machine/domain/entities/vending_machine_product.dart';
import 'package:vending_app/features/vending_machine/domain/value_objects/geo_coordinate.dart';
import 'package:vending_app/features/vending_machine/domain/value_objects/vending_machine_id.dart';

void main() {
  const cases = <_ResponsiveCase>[
    _ResponsiveCase(
      label: 'small',
      size: Size(320, 568),
    ),
    _ResponsiveCase(
      label: 'baseline',
      size: Size(390, 844),
    ),
    _ResponsiveCase(
      label: 'large',
      size: Size(600, 960),
    ),
    _ResponsiveCase(
      label: 'large-text',
      size: Size(390, 844),
      textScale: 1.4,
    ),
  ];

  for (final responsiveCase in cases) {
    testWidgets(
      '登録確認 ${responsiveCase.label} でoverflowせずsubmitへ到達できる',
      (WidgetTester tester) async {
        _configureView(tester, responsiveCase);

        final manufacturer = _manufacturer();
        final container = ProviderContainer(
          overrides: [
            manufacturerRepositoryProvider.overrideWithValue(
              _FakeManufacturerRepository(
                <Manufacturer>[manufacturer],
              ),
            ),
          ],
        );
        addTearDown(container.dispose);

        final registration = container.read(
          machineRegistrationControllerProvider.notifier,
        );

        registration.setLocation(
          GeoCoordinate(
            latitude: 35.681236,
            longitude: 139.767125,
          ),
        );
        registration.continueFromPosition();
        registration.continueAfterDuplicateCheck();
        registration.chooseManufacturerMethod();

        await container
            .read(
              manufacturerSelectionControllerProvider.notifier,
            )
            .load();

        registration.selectManufacturer(manufacturer.id);

        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: _app(
              textScale: responsiveCase.textScale,
              home: V2RegistrationConfirmationScreen(
                onSubmit: () async {},
              ),
            ),
          ),
        );

        await tester.pumpAndSettle();

        await tester.scrollUntilVisible(
          find.byKey(
            const Key('registrationConfirmationSubmitButton'),
          ),
          300,
        );

        expect(tester.takeException(), isNull);
        expect(
          find.byKey(
            const Key('registrationConfirmationSubmitButton'),
          ),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      '手動商品更新 ${responsiveCase.label} でoverflowせず確認操作へ到達できる',
      (WidgetTester tester) async {
        _configureView(tester, responsiveCase);

        final detail = _detail();
        final machineId = detail.machine.id;

        final container = ProviderContainer(
          overrides: [
            vendingMachineDetailProvider(machineId).overrideWithValue(
              AsyncValue<AppResult<VendingMachineDetailData>>.data(
                AppResult<VendingMachineDetailData>.success(
                  detail,
                ),
              ),
            ),
          ],
        );
        addTearDown(container.dispose);

        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: _app(
              textScale: responsiveCase.textScale,
              home: V2ManualProductUpdateScreen(
                machineId: machineId,
                onReviewPressed: () {},
              ),
            ),
          ),
        );

        await tester.pumpAndSettle();

        expect(
          find.byKey(const Key('manualProductUpdateScreen')),
          findsOneWidget,
        );

        await tester.scrollUntilVisible(
          find.byKey(
            const Key('reviewMachineProductChangesButton'),
          ),
          300,
        );

        expect(tester.takeException(), isNull);
        expect(
          find.byKey(
            const Key('reviewMachineProductChangesButton'),
          ),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      '基本情報修正 ${responsiveCase.label} でoverflowせず確認操作へ到達できる',
      (WidgetTester tester) async {
        _configureView(tester, responsiveCase);

        final detail = _detail();
        final machineId = detail.machine.id;

        final container = ProviderContainer(
          overrides: [
            vendingMachineDetailProvider.overrideWith(
              (ref, requestedMachineId) async {
                return AppResult<VendingMachineDetailData>.success(
                  detail,
                );
              },
            ),
            machineCorrectionManufacturersProvider.overrideWith(
              (ref) async {
                return const AppResult<List<Manufacturer>>.success(
                  <Manufacturer>[],
                );
              },
            ),
          ],
        );
        addTearDown(container.dispose);

        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: _app(
              textScale: responsiveCase.textScale,
              home: V2MachineCorrectionScreen(
                machineId: machineId,
                onReviewPressed: () {},
              ),
            ),
          ),
        );

        await tester.pumpAndSettle();

        expect(
          find.byKey(const Key('machineCorrectionScreen')),
          findsOneWidget,
        );

        final correctionScroll = find.byKey(
          const Key('machineCorrectionScreen'),
        );

        await tester.drag(
          correctionScroll,
          const Offset(0, -700),
        );
        await tester.pumpAndSettle();

        await tester.drag(
          correctionScroll,
          const Offset(0, -700),
        );
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
        expect(
          find.byKey(
            const Key('machineCorrectionReviewButton'),
          ),
          findsOneWidget,
        );
      },
    );
  }
}

void _configureView(
  WidgetTester tester,
  _ResponsiveCase responsiveCase,
) {
  tester.view.physicalSize = responsiveCase.size;
  tester.view.devicePixelRatio = 1;

  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

Widget _app({
  required double textScale,
  required Widget home,
}) {
  return MaterialApp(
    builder: (context, child) {
      return MediaQuery(
        data: MediaQuery.of(
          context,
        ).copyWith(
          textScaler: TextScaler.linear(textScale),
        ),
        child: child!,
      );
    },
    home: home,
  );
}

Manufacturer _manufacturer() {
  return Manufacturer(
    id: ManufacturerId.parse('coca_cola'),
    name: 'コカ・コーラ',
    displayShortName: 'コカ・コーラ',
    presetProductIds: <ProductId>[
      ProductId.parse('coca_cola_ayataka'),
    ],
    createdAt: DateTime.utc(2026, 8, 21),
    updatedAt: DateTime.utc(2026, 8, 21),
  );
}

VendingMachineDetailData _detail() {
  final machine = VendingMachine(
    id: VendingMachineId.parse('machine_p10_responsive'),
    schemaVersion: 2,
    name: '駅東口の少し長い名前の自販機',
    manufacturerId: ManufacturerId.parse('suntory'),
    manufacturerStatus: ManufacturerStatus.confirmed,
    location: GeoCoordinate(
      latitude: 35.681236,
      longitude: 139.767125,
    ),
    geohash: 'xn76ur',
    placeDescription: '駅東口の壁沿い・改札を出て右側',
    installationType: InstallationType.outdoor,
    status: VendingMachineStatus.active,
    dataLevel: VendingMachineDataLevel.productsConfirmed,
    createdBy: 'p10-responsive',
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

final class _FakeManufacturerRepository
    implements ManufacturerRepository {
  const _FakeManufacturerRepository(
    this.manufacturers,
  );

  final List<Manufacturer> manufacturers;

  @override
  Future<AppResult<List<Manufacturer>>> getManufacturers({
    bool activeOnly = true,
  }) async {
    return AppResult<List<Manufacturer>>.success(
      manufacturers,
    );
  }

  @override
  Future<AppResult<Manufacturer>> getManufacturer(
    ManufacturerId id,
  ) async {
    final manufacturer = manufacturers.firstWhere(
      (item) => item.id == id,
    );

    return AppResult<Manufacturer>.success(
      manufacturer,
    );
  }
}

final class _ResponsiveCase {
  const _ResponsiveCase({
    required this.label,
    required this.size,
    this.textScale = 1,
  });

  final String label;
  final Size size;
  final double textScale;
}
