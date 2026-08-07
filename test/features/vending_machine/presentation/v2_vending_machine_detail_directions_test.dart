import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vending_app/core/result/app_result.dart';
import 'package:vending_app/features/product_master/domain/value_objects/master_id.dart';
import 'package:vending_app/features/vending_machine/application/models/vending_machine_detail_data.dart';
import 'package:vending_app/features/vending_machine/application/providers/external_map_service_provider.dart';
import 'package:vending_app/features/vending_machine/application/providers/vending_machine_detail_providers.dart';
import 'package:vending_app/features/vending_machine/domain/entities/vending_machine.dart';
import 'package:vending_app/features/vending_machine/domain/entities/vending_machine_enums.dart';
import 'package:vending_app/features/vending_machine/domain/services/external_map_service.dart';
import 'package:vending_app/features/vending_machine/domain/value_objects/geo_coordinate.dart';
import 'package:vending_app/features/vending_machine/domain/value_objects/vending_machine_id.dart';
import 'package:vending_app/features/vending_machine/presentation/v2_vending_machine_detail_screen.dart';

void main() {
  testWidgets('経路を見るで選択自販機の緯度経度を外部地図Serviceへ渡す', (WidgetTester tester) async {
    final data = _detailData();
    final externalMap = _FakeExternalMapService(result: true);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          vendingMachineDetailProvider(data.machine.id).overrideWithValue(
            AsyncValue<AppResult<VendingMachineDetailData>>.data(
              AppResult<VendingMachineDetailData>.success(data),
            ),
          ),
          externalMapServiceProvider.overrideWithValue(externalMap),
        ],
        child: MaterialApp(
          home: V2VendingMachineDetailScreen(machineId: data.machine.id),
        ),
      ),
    );

    await tester.pump();

    await tester.tap(find.byKey(const Key('openDirectionsButton')));
    await tester.pump();

    expect(externalMap.calls, 1);
    expect(externalMap.latitude, 35.681236);
    expect(externalMap.longitude, 139.767125);
    expect(find.text('地図アプリを開けませんでした'), findsNothing);
  });

  testWidgets('外部地図を開けない場合だけSnackBarを表示する', (WidgetTester tester) async {
    final data = _detailData();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          vendingMachineDetailProvider(data.machine.id).overrideWithValue(
            AsyncValue<AppResult<VendingMachineDetailData>>.data(
              AppResult<VendingMachineDetailData>.success(data),
            ),
          ),
          externalMapServiceProvider.overrideWithValue(
            _FakeExternalMapService(result: false),
          ),
        ],
        child: MaterialApp(
          home: V2VendingMachineDetailScreen(machineId: data.machine.id),
        ),
      ),
    );

    await tester.pump();

    await tester.tap(find.byKey(const Key('openDirectionsButton')));
    await tester.pump();

    expect(find.text('地図アプリを開けませんでした'), findsOneWidget);
  });
}

VendingMachineDetailData _detailData() {
  return VendingMachineDetailData(
    machine: VendingMachine(
      id: VendingMachineId.parse('machine_directions'),
      schemaVersion: 2,
      name: '駅前の自販機',
      manufacturerId: ManufacturerId.parse('suntory'),
      manufacturerStatus: ManufacturerStatus.confirmed,
      location: GeoCoordinate(latitude: 35.681236, longitude: 139.767125),
      geohash: 'xn76ur',
      placeDescription: '駅東口',
      installationType: InstallationType.outdoor,
      status: VendingMachineStatus.active,
      dataLevel: VendingMachineDataLevel.locationOnly,
      createdBy: 'test',
    ),
    manufacturerName: 'サントリー',
    products: const [],
  );
}

final class _FakeExternalMapService implements ExternalMapService {
  _FakeExternalMapService({required this.result});

  final bool result;
  int calls = 0;
  double? latitude;
  double? longitude;

  @override
  Future<bool> openWalkingDirections({
    required double latitude,
    required double longitude,
  }) async {
    calls += 1;
    this.latitude = latitude;
    this.longitude = longitude;
    return result;
  }
}
