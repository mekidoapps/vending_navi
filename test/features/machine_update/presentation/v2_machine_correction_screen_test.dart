import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../../lib/core/result/app_result.dart';
import '../../../../lib/features/machine_update/application/machine_correction_controller.dart';
import '../../../../lib/features/machine_update/application/providers/machine_correction_providers.dart';
import '../../../../lib/features/machine_update/presentation/v2_machine_correction_screen.dart';
import '../../../../lib/features/product_master/domain/entities/manufacturer.dart';
import '../../../../lib/features/product_master/domain/value_objects/master_id.dart';
import '../../../../lib/features/vending_machine/application/models/vending_machine_detail_data.dart';
import '../../../../lib/features/vending_machine/application/providers/vending_machine_detail_providers.dart';
import '../../../../lib/features/vending_machine/domain/entities/vending_machine.dart';
import '../../../../lib/features/vending_machine/domain/entities/vending_machine_enums.dart';
import '../../../../lib/features/vending_machine/domain/value_objects/geo_coordinate.dart';
import '../../../../lib/features/vending_machine/domain/value_objects/vending_machine_id.dart';

void main() {
  testWidgets('current basic information is shown initially', (tester) async {
    final container = _container();
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          home: V2MachineCorrectionScreen(
            machineId: _machineId,
            onReviewPressed: () {},
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    final nameField = tester.widget<TextField>(
      find.byKey(const Key('machineCorrectionNameField')),
    );
    final placeField = tester.widget<TextField>(
      find.byKey(const Key('machineCorrectionPlaceField')),
    );

    expect(nameField.controller?.text, '駅東口の自販機');
    expect(placeField.controller?.text, '駅東口の壁沿い');

    await _scrollDown(tester);

    final locationFinder = find.byKey(
      const Key('machineCorrectionLocationValue'),
    );

    expect(locationFinder, findsOneWidget);

    final locationText = tester.widget<Text>(locationFinder);

    expect(locationText.data, '35.68124, 139.76712');

  });

  testWidgets('changing only name creates only a name correction', (
    tester,
  ) async {
    final container = _container();
    addTearDown(container.dispose);

    var reviewCount = 0;

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          home: V2MachineCorrectionScreen(
            machineId: _machineId,
            onReviewPressed: () {
              reviewCount += 1;
            },
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const Key('machineCorrectionNameField')),
      '東京駅東口 自販機',
    );

    await _scrollToBottom(tester);

    final reviewButton = find.byKey(const Key('machineCorrectionReviewButton'));

    expect(reviewButton, findsOneWidget);

    await tester.tap(reviewButton);
    await tester.pump();

    expect(reviewCount, 1);

    final draft = container.read(machineCorrectionControllerProvider).draft;

    expect(draft, isNotNull);

    expect(draft!.name.isChanged, isTrue);
    expect(draft.name.value, '東京駅東口 自販機');

    expect(draft.manufacturerId.isChanged, isFalse);
    expect(draft.location.isChanged, isFalse);
    expect(draft.placeDescription.isChanged, isFalse);
    expect(draft.installationType.isChanged, isFalse);
  });

  testWidgets('clearing place description creates changed null', (
    tester,
  ) async {
    final container = _container();
    addTearDown(container.dispose);

    var reviewCount = 0;

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          home: V2MachineCorrectionScreen(
            machineId: _machineId,
            onReviewPressed: () {
              reviewCount += 1;
            },
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const Key('machineCorrectionPlaceField')),
      '',
    );

    await _scrollToBottom(tester);

    final reviewButton = find.byKey(const Key('machineCorrectionReviewButton'));

    expect(reviewButton, findsOneWidget);

    await tester.tap(reviewButton);
    await tester.pump();

    expect(reviewCount, 1);

    final draft = container.read(machineCorrectionControllerProvider).draft;

    expect(draft, isNotNull);
    expect(draft!.placeDescription.isChanged, isTrue);
    expect(draft.placeDescription.value, isNull);

    expect(draft.name.isChanged, isFalse);
    expect(draft.manufacturerId.isChanged, isFalse);
    expect(draft.location.isChanged, isFalse);
    expect(draft.installationType.isChanged, isFalse);
  });

  testWidgets('unchanged information does not proceed to review', (
    tester,
  ) async {
    final container = _container();
    addTearDown(container.dispose);

    var reviewCount = 0;

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          home: V2MachineCorrectionScreen(
            machineId: _machineId,
            onReviewPressed: () {
              reviewCount += 1;
            },
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    await _scrollToBottom(tester);

    final reviewButton = find.byKey(const Key('machineCorrectionReviewButton'));

    expect(reviewButton, findsOneWidget);

    await tester.tap(reviewButton);
    await tester.pump();

    expect(reviewCount, 0);

    expect(find.text('現在の情報から変更された項目がありません。'), findsOneWidget);

    expect(container.read(machineCorrectionControllerProvider).draft, isNull);
  });
}

Future<void> _scrollDown(WidgetTester tester) async {
  await tester.drag(
    find.byKey(const Key('machineCorrectionScreen')),
    const Offset(0, -350),
  );
  await tester.pumpAndSettle();
}

Future<void> _scrollToBottom(WidgetTester tester) async {
  final scrollable = find.byKey(const Key('machineCorrectionScreen'));

  await tester.drag(scrollable, const Offset(0, -700));
  await tester.pumpAndSettle();

  await tester.drag(scrollable, const Offset(0, -700));
  await tester.pumpAndSettle();
}

final VendingMachineId _machineId = VendingMachineId.tryParse('machine-001')!;

ProviderContainer _container() {
  final detail = _detail();

  return ProviderContainer(
    overrides: [
      vendingMachineDetailProvider.overrideWith((ref, machineId) async {
        return AppResult<VendingMachineDetailData>.success(detail);
      }),
      machineCorrectionManufacturersProvider.overrideWith((ref) async {
        return AppResult<List<Manufacturer>>.success(const <Manufacturer>[]);
      }),
    ],
  );
}

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
