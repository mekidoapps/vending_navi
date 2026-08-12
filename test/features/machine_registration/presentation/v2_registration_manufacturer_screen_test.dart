import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vending_app/core/result/app_result.dart';
import 'package:vending_app/features/machine_registration/application/machine_registration_controller.dart';
import 'package:vending_app/features/machine_registration/application/machine_registration_state.dart';
import 'package:vending_app/features/machine_registration/domain/entities/machine_registration_method.dart';
import 'package:vending_app/features/machine_registration/presentation/v2_registration_manufacturer_screen.dart';
import 'package:vending_app/features/product_master/application/providers/product_master_providers.dart';
import 'package:vending_app/features/product_master/domain/entities/manufacturer.dart';
import 'package:vending_app/features/product_master/domain/repositories/manufacturer_repository.dart';
import 'package:vending_app/features/product_master/domain/value_objects/master_id.dart';

void main() {
  testWidgets('メーカーマスタから選択してdraftへManufacturerIdを保存する', (
    WidgetTester tester,
  ) async {
    final manufacturer = _manufacturer();
    final container = ProviderContainer(
      overrides: [
        manufacturerRepositoryProvider.overrideWithValue(
          _FakeManufacturerRepository(<Manufacturer>[manufacturer]),
        ),
      ],
    );
    addTearDown(container.dispose);

    var selectedCount = 0;

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          home: V2RegistrationManufacturerScreen(
            onManufacturerSelected: (_) {
              selectedCount += 1;
            },
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('コカ・コーラ'), findsWidgets);

    await tester.tap(
      find.byKey(const Key('registrationManufacturer_coca_cola')),
    );
    await tester.pump();

    final state = container.read(machineRegistrationControllerProvider);
    expect(selectedCount, 1);
    expect(state.step, MachineRegistrationStep.confirm);
    expect(
      state.draft.registrationMethod,
      MachineRegistrationMethod.manufacturer,
    );
    expect(state.draft.manufacturerId?.value, 'coca_cola');
  });

  testWidgets('分からないを選ぶとlocationOnlyへ切り替える', (WidgetTester tester) async {
    final container = ProviderContainer(
      overrides: [
        manufacturerRepositoryProvider.overrideWithValue(
          const _FakeManufacturerRepository(<Manufacturer>[]),
        ),
      ],
    );
    addTearDown(container.dispose);

    var unknownSelected = false;

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          home: V2RegistrationManufacturerScreen(
            onUnknownSelected: () {
              unknownSelected = true;
            },
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('registrationManufacturerUnknown')));
    await tester.pump();

    final state = container.read(machineRegistrationControllerProvider);
    expect(unknownSelected, isTrue);
    expect(state.step, MachineRegistrationStep.confirm);
    expect(
      state.draft.registrationMethod,
      MachineRegistrationMethod.locationOnly,
    );
    expect(state.draft.manufacturerId, isNull);
  });
}

Manufacturer _manufacturer() {
  return Manufacturer(
    id: ManufacturerId.parse('coca_cola'),
    name: 'コカ・コーラ',
    displayShortName: 'コカ・コーラ',
    presetProductIds: <ProductId>[ProductId.parse('ayataka_regular')],
    createdAt: DateTime.utc(2026, 8, 11),
    updatedAt: DateTime.utc(2026, 8, 11),
  );
}

final class _FakeManufacturerRepository implements ManufacturerRepository {
  const _FakeManufacturerRepository(this.manufacturers);

  final List<Manufacturer> manufacturers;

  @override
  Future<AppResult<List<Manufacturer>>> getManufacturers({
    bool activeOnly = true,
  }) async {
    return AppResult<List<Manufacturer>>.success(manufacturers);
  }

  @override
  Future<AppResult<Manufacturer>> getManufacturer(ManufacturerId id) async {
    final manufacturer = manufacturers.firstWhere((item) => item.id == id);
    return AppResult<Manufacturer>.success(manufacturer);
  }
}
