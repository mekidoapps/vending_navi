import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vending_app/core/result/app_result.dart';
import 'package:vending_app/features/home_map/application/providers/vending_machine_map_providers.dart';
import 'package:vending_app/features/home_map/domain/repositories/vending_machine_map_repository.dart';
import 'package:vending_app/features/home_map/domain/value_objects/map_viewport_bounds.dart';
import 'package:vending_app/features/machine_registration/application/machine_registration_controller.dart';
import 'package:vending_app/features/machine_registration/presentation/v2_registration_duplicate_candidates_screen.dart';
import 'package:vending_app/features/product_master/domain/value_objects/master_id.dart';
import 'package:vending_app/features/vending_machine/domain/entities/vending_machine.dart';
import 'package:vending_app/features/vending_machine/domain/entities/vending_machine_enums.dart';
import 'package:vending_app/features/vending_machine/domain/value_objects/geo_coordinate.dart';
import 'package:vending_app/features/vending_machine/domain/value_objects/vending_machine_id.dart';

void main() {
  testWidgets('候補0件なら画面を挟まずcontinueする', (WidgetTester tester) async {
    final container = ProviderContainer(
      overrides: [
        vendingMachineMapRepositoryProvider.overrideWithValue(
          _FakeMapRepository(const <VendingMachine>[]),
        ),
      ],
    );
    addTearDown(container.dispose);

    container
        .read(machineRegistrationControllerProvider.notifier)
        .setLocation(GeoCoordinate(latitude: 35.68, longitude: 139.76));
    container
        .read(machineRegistrationControllerProvider.notifier)
        .continueFromPosition();

    var continueCount = 0;

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          home: V2RegistrationDuplicateCandidatesScreen(
            onContinue: () {
              continueCount += 1;
            },
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(continueCount, 1);
  });

  testWidgets('30m以内の候補を表示して別自販機として続行できる', (WidgetTester tester) async {
    final machine = _machine(
      id: 'machine_candidate',
      latitude: 35.68010,
      longitude: 139.76,
    );
    final container = ProviderContainer(
      overrides: [
        vendingMachineMapRepositoryProvider.overrideWithValue(
          _FakeMapRepository(<VendingMachine>[machine]),
        ),
      ],
    );
    addTearDown(container.dispose);

    container
        .read(machineRegistrationControllerProvider.notifier)
        .setLocation(GeoCoordinate(latitude: 35.68, longitude: 139.76));
    container
        .read(machineRegistrationControllerProvider.notifier)
        .continueFromPosition();

    var continueCount = 0;

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          home: V2RegistrationDuplicateCandidatesScreen(
            onContinue: () {
              continueCount += 1;
            },
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('候補の自販機'), findsOneWidget);
    expect(find.textContaining('m'), findsWidgets);

    await tester.tap(
      find.byKey(const Key('registrationDuplicateContinueButton')),
    );
    await tester.pump();

    expect(continueCount, 1);
  });
}

VendingMachine _machine({
  required String id,
  required double latitude,
  required double longitude,
}) {
  return VendingMachine(
    id: VendingMachineId.parse(id),
    schemaVersion: 2,
    name: '候補の自販機',
    manufacturerId: ManufacturerId.parse('coca_cola'),
    manufacturerStatus: ManufacturerStatus.confirmed,
    location: GeoCoordinate(latitude: latitude, longitude: longitude),
    geohash: 'xn76',
    installationType: InstallationType.outdoor,
    status: VendingMachineStatus.active,
    dataLevel: VendingMachineDataLevel.manufacturerOnly,
    createdBy: 'fixture_user',
  );
}

final class _FakeMapRepository implements VendingMachineMapRepository {
  const _FakeMapRepository(this.machines);

  final List<VendingMachine> machines;

  @override
  Future<AppResult<List<VendingMachine>>> getMachinesInViewport(
    MapViewportBounds bounds,
  ) async {
    return AppResult<List<VendingMachine>>.success(machines);
  }
}
