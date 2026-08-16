import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../../lib/core/errors/app_failure.dart';
import '../../../../lib/core/result/app_result.dart';
import '../../../../lib/features/machine_update/application/machine_product_update_controller.dart';
import '../../../../lib/features/machine_update/application/providers/machine_product_update_providers.dart';
import '../../../../lib/features/machine_update/domain/models/machine_product_update_draft.dart';
import '../../../../lib/features/machine_update/domain/models/machine_product_update_operation.dart';
import '../../../../lib/features/machine_update/domain/models/machine_product_update_result.dart';
import '../../../../lib/features/machine_update/domain/repositories/machine_product_update_repository.dart';
import '../../../../lib/features/machine_update/domain/services/machine_product_update_request_id_generator.dart';
import '../../../../lib/features/vending_machine/domain/value_objects/vending_machine_id.dart';

void main() {
  test('failed retry reuses the same requestId', () async {
    final repository = _QueueRepository(<AppResult<MachineProductUpdateResult>>[
      const AppResult<MachineProductUpdateResult>.failure(NetworkFailure()),
      AppResult<MachineProductUpdateResult>.success(_successResult()),
    ]);

    final generator = _SequenceRequestIdGenerator(<String>[
      '123e4567-e89b-42d3-a456-426614174000',
      '123e4567-e89b-42d3-a456-426614174001',
    ]);

    final container = _container(repository: repository, generator: generator);
    addTearDown(container.dispose);

    final controller = container.read(
      machineProductUpdateControllerProvider.notifier,
    );

    controller.begin(_draft(soldOut: true));

    expect(await controller.submit(), isFalse);

    final afterFailure = container.read(machineProductUpdateControllerProvider);

    expect(afterFailure.requestId, '123e4567-e89b-42d3-a456-426614174000');
    expect(afterFailure.failure, isA<NetworkFailure>());

    expect(await controller.submit(), isTrue);

    expect(repository.requestIds, <String>[
      '123e4567-e89b-42d3-a456-426614174000',
      '123e4567-e89b-42d3-a456-426614174000',
    ]);
    expect(generator.callCount, 1);
  });

  test('editing after failure clears old requestId', () async {
    final repository = _QueueRepository(<AppResult<MachineProductUpdateResult>>[
      const AppResult<MachineProductUpdateResult>.failure(NetworkFailure()),
      AppResult<MachineProductUpdateResult>.success(_successResult()),
    ]);

    final generator = _SequenceRequestIdGenerator(<String>[
      '123e4567-e89b-42d3-a456-426614174000',
      '123e4567-e89b-42d3-a456-426614174001',
    ]);

    final container = _container(repository: repository, generator: generator);
    addTearDown(container.dispose);

    final controller = container.read(
      machineProductUpdateControllerProvider.notifier,
    );

    controller.begin(_draft(soldOut: true));

    expect(await controller.submit(), isFalse);

    controller.replaceDraft(_draft(soldOut: false));

    expect(
      container.read(machineProductUpdateControllerProvider).requestId,
      isNull,
    );

    expect(await controller.submit(), isTrue);

    expect(repository.requestIds, <String>[
      '123e4567-e89b-42d3-a456-426614174000',
      '123e4567-e89b-42d3-a456-426614174001',
    ]);
    expect(generator.callCount, 2);
  });

  test('empty operation draft is rejected before repository call', () async {
    final repository = _QueueRepository(
      <AppResult<MachineProductUpdateResult>>[],
    );

    final generator = _SequenceRequestIdGenerator(<String>[
      '123e4567-e89b-42d3-a456-426614174000',
    ]);

    final container = _container(repository: repository, generator: generator);
    addTearDown(container.dispose);

    final controller = container.read(
      machineProductUpdateControllerProvider.notifier,
    );

    controller.begin(
      MachineProductUpdateDraft(
        machineId: VendingMachineId.tryParse('machine-001')!,
        operations: const <MachineProductUpdateOperation>[],
      ),
    );

    expect(await controller.submit(), isFalse);

    final state = container.read(machineProductUpdateControllerProvider);

    expect(state.failure, isA<ValidationFailure>());
    expect(state.requestId, isNull);
    expect(repository.requestIds, isEmpty);
    expect(generator.callCount, 0);
  });

  test('successful submission stores result and clears failure', () async {
    final repository = _QueueRepository(<AppResult<MachineProductUpdateResult>>[
      AppResult<MachineProductUpdateResult>.success(_successResult()),
    ]);

    final generator = _SequenceRequestIdGenerator(<String>[
      '123e4567-e89b-42d3-a456-426614174000',
    ]);

    final container = _container(repository: repository, generator: generator);
    addTearDown(container.dispose);

    final controller = container.read(
      machineProductUpdateControllerProvider.notifier,
    );

    controller.begin(_draft(soldOut: true));

    expect(await controller.submit(), isTrue);

    final state = container.read(machineProductUpdateControllerProvider);

    expect(state.isSubmitting, isFalse);
    expect(state.failure, isNull);
    expect(state.result?.updated, isTrue);
    expect(state.result?.changedProductIds, <String>['asahi_calpis']);
  });
}

ProviderContainer _container({
  required MachineProductUpdateRepository repository,
  required MachineProductUpdateRequestIdGenerator generator,
}) {
  return ProviderContainer(
    overrides: [
      machineProductUpdateRepositoryProvider.overrideWithValue(repository),
      machineProductUpdateRequestIdGeneratorProvider.overrideWithValue(
        generator,
      ),
    ],
  );
}

MachineProductUpdateDraft _draft({required bool soldOut}) {
  return MachineProductUpdateDraft(
    machineId: VendingMachineId.tryParse('machine-001')!,
    operations: <MachineProductUpdateOperation>[
      MachineProductUpdateOperation.setSoldOut(
        productId: 'asahi_calpis',
        soldOut: soldOut,
      ),
    ],
  );
}

MachineProductUpdateResult _successResult() {
  return MachineProductUpdateResult(
    machineId: VendingMachineId.tryParse('machine-001')!,
    updated: true,
    changedProductIds: <String>['asahi_calpis'],
  );
}

final class _SequenceRequestIdGenerator
    implements MachineProductUpdateRequestIdGenerator {
  _SequenceRequestIdGenerator(this.values);

  final List<String> values;
  var callCount = 0;

  @override
  String next() {
    if (callCount >= values.length) {
      throw StateError('No requestId fixture remains.');
    }

    final value = values[callCount];
    callCount += 1;
    return value;
  }
}

final class _QueueRepository implements MachineProductUpdateRepository {
  _QueueRepository(this.responses);

  final List<AppResult<MachineProductUpdateResult>> responses;
  final List<String> requestIds = <String>[];
  var _nextResponse = 0;

  @override
  Future<AppResult<MachineProductUpdateResult>> updateProducts({
    required String requestId,
    required MachineProductUpdateDraft draft,
  }) async {
    requestIds.add(requestId);

    if (_nextResponse >= responses.length) {
      throw StateError('No repository response fixture remains.');
    }

    final response = responses[_nextResponse];
    _nextResponse += 1;
    return response;
  }
}
