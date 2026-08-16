import 'package:flutter_test/flutter_test.dart';

import '../../../../../lib/features/machine_update/data/repositories/machine_product_update_repository_impl.dart';
import '../../../../../lib/features/machine_update/data/sources/machine_product_update_data_source.dart';
import '../../../../../lib/features/machine_update/domain/models/machine_product_update_draft.dart';
import '../../../../../lib/features/machine_update/domain/models/machine_product_update_operation.dart';
import '../../../../../lib/features/vending_machine/domain/value_objects/vending_machine_id.dart';

void main() {
  test('maps callable response to domain result', () async {
    final source = _FixtureSource(<String, Object?>{
      'machineId': 'machine-001',
      'updated': true,
      'changedProductIds': <String>['asahi_calpis'],
    });

    final repository = MachineProductUpdateRepositoryImpl(source);

    final result = await repository.updateProducts(
      requestId: '123e4567-e89b-42d3-a456-426614174000',
      draft: MachineProductUpdateDraft(
        machineId: VendingMachineId.tryParse('machine-001')!,
        operations: const <MachineProductUpdateOperation>[
          MachineProductUpdateOperation.addConfirmed(
            productId: 'asahi_calpis',
            source: MachineProductUpdateSource.manual,
          ),
        ],
      ),
    );

    expect(result.failureOrNull, isNull);
    expect(result.valueOrNull?.updated, isTrue);
    expect(result.valueOrNull?.changedProductIds, <String>['asahi_calpis']);

    expect(source.lastRequest?['machineId'], 'machine-001');
    expect(
      source.lastRequest?['requestId'],
      '123e4567-e89b-42d3-a456-426614174000',
    );
  });

  test('rejects response for a different machine', () async {
    final repository = MachineProductUpdateRepositoryImpl(
      _FixtureSource(<String, Object?>{
        'machineId': 'machine-999',
        'updated': true,
        'changedProductIds': <String>['asahi_calpis'],
      }),
    );

    final result = await repository.updateProducts(
      requestId: '123e4567-e89b-42d3-a456-426614174000',
      draft: MachineProductUpdateDraft(
        machineId: VendingMachineId.tryParse('machine-001')!,
        operations: const <MachineProductUpdateOperation>[
          MachineProductUpdateOperation.addConfirmed(
            productId: 'asahi_calpis',
            source: MachineProductUpdateSource.manual,
          ),
        ],
      ),
    );

    expect(result.valueOrNull, isNull);
    expect(result.failureOrNull, isNotNull);
  });
}

final class _FixtureSource implements MachineProductUpdateDataSource {
  _FixtureSource(this.response);

  final Map<String, Object?> response;
  Map<String, Object?>? lastRequest;

  @override
  Future<Map<String, Object?>> updateVendingMachineProducts(
    Map<String, Object?> request,
  ) async {
    lastRequest = request;
    return response;
  }
}
