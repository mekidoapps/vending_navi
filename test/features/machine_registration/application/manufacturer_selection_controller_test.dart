import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vending_app/core/result/app_result.dart';
import 'package:vending_app/features/machine_registration/application/manufacturer_selection_controller.dart';
import 'package:vending_app/features/product_master/application/providers/product_master_providers.dart';
import 'package:vending_app/features/product_master/domain/entities/manufacturer.dart';
import 'package:vending_app/features/product_master/domain/repositories/manufacturer_repository.dart';
import 'package:vending_app/features/product_master/domain/value_objects/master_id.dart';

void main() {
  test('activeかつselectableなメーカーだけを表示する', () async {
    final repository = _FakeManufacturerRepository(
      manufacturers: <Manufacturer>[
        _manufacturer(id: 'suntory', name: 'サントリー', shortName: 'サントリー'),
        _manufacturer(id: 'coca_cola', name: 'コカ・コーラ', shortName: 'コカ・コーラ'),
        _manufacturer(
          id: 'hidden',
          name: '非表示',
          shortName: '非表示',
          isActive: false,
        ),
      ],
    );

    final container = ProviderContainer(
      overrides: [manufacturerRepositoryProvider.overrideWithValue(repository)],
    );
    addTearDown(container.dispose);

    await container
        .read(manufacturerSelectionControllerProvider.notifier)
        .load();

    final state = container.read(manufacturerSelectionControllerProvider);

    expect(state.failure, isNull);
    expect(state.hasLoaded, isTrue);
    expect(state.manufacturers.map((item) => item.id.value).toSet(), <String>{
      'coca_cola',
      'suntory',
    });
  });
}

Manufacturer _manufacturer({
  required String id,
  required String name,
  required String shortName,
  bool isActive = true,
}) {
  return Manufacturer(
    id: ManufacturerId.parse(id),
    name: name,
    displayShortName: shortName,
    isActive: isActive,
    createdAt: DateTime.utc(2026, 8, 11),
    updatedAt: DateTime.utc(2026, 8, 11),
  );
}

final class _FakeManufacturerRepository implements ManufacturerRepository {
  const _FakeManufacturerRepository({required this.manufacturers});

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
