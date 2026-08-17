import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../../lib/core/errors/app_failure.dart';
import '../../../../lib/core/result/app_result.dart';
import '../../../../lib/features/machine_update/application/machine_correction_controller.dart';
import '../../../../lib/features/machine_update/application/providers/machine_correction_providers.dart';
import '../../../../lib/features/machine_update/domain/models/machine_correction_draft.dart';
import '../../../../lib/features/machine_update/domain/models/machine_correction_field.dart';
import '../../../../lib/features/machine_update/domain/models/machine_correction_result.dart';
import '../../../../lib/features/machine_update/domain/repositories/machine_correction_repository.dart';
import '../../../../lib/features/machine_update/domain/services/machine_product_update_request_id_generator.dart';
import '../../../../lib/features/vending_machine/domain/value_objects/vending_machine_id.dart';

void main() {
  test('failed retry reuses the same correction requestId', () async {
    final repository = _QueueRepository(<AppResult<MachineCorrectionResult>>[
      const AppResult<MachineCorrectionResult>.failure(NetworkFailure()),
      AppResult<MachineCorrectionResult>.success(_successResult()),
    ]);

    final generator = _SequenceRequestIdGenerator(<String>[
      '123e4567-e89b-42d3-a456-426614174000',
      '123e4567-e89b-42d3-a456-426614174001',
    ]);

    final container = _container(repository: repository, generator: generator);
    addTearDown(container.dispose);

    final controller = container.read(
      machineCorrectionControllerProvider.notifier,
    );

    controller.begin(_draft('修正1'));

    expect(await controller.submit(), isFalse);
    expect(await controller.submit(), isTrue);

    expect(repository.requestIds, <String>[
      '123e4567-e89b-42d3-a456-426614174000',
      '123e4567-e89b-42d3-a456-426614174000',
    ]);
    expect(generator.callCount, 1);
  });

  test('editing after failure clears old correction requestId', () async {
    final repository = _QueueRepository(<AppResult<MachineCorrectionResult>>[
      const AppResult<MachineCorrectionResult>.failure(NetworkFailure()),
      AppResult<MachineCorrectionResult>.success(_successResult()),
    ]);

    final generator = _SequenceRequestIdGenerator(<String>[
      '123e4567-e89b-42d3-a456-426614174000',
      '123e4567-e89b-42d3-a456-426614174001',
    ]);

    final container = _container(repository: repository, generator: generator);
    addTearDown(container.dispose);

    final controller = container.read(
      machineCorrectionControllerProvider.notifier,
    );

    controller.begin(_draft('修正1'));

    expect(await controller.submit(), isFalse);

    controller.replaceDraft(_draft('修正2'));

    expect(
      container.read(machineCorrectionControllerProvider).requestId,
      isNull,
    );

    expect(await controller.submit(), isTrue);

    expect(repository.requestIds, <String>[
      '123e4567-e89b-42d3-a456-426614174000',
      '123e4567-e89b-42d3-a456-426614174001',
    ]);
    expect(generator.callCount, 2);
  });

  test('draft without changes is rejected before repository call', () async {
    final repository = _QueueRepository(<AppResult<MachineCorrectionResult>>[]);

    final generator = _SequenceRequestIdGenerator(<String>[
      '123e4567-e89b-42d3-a456-426614174000',
    ]);

    final container = _container(repository: repository, generator: generator);
    addTearDown(container.dispose);

    final controller = container.read(
      machineCorrectionControllerProvider.notifier,
    );

    controller.begin(
      MachineCorrectionDraft(
        machineId: VendingMachineId.tryParse('machine-001')!,
      ),
    );

    expect(await controller.submit(), isFalse);

    final state = container.read(machineCorrectionControllerProvider);

    expect(state.failure, isA<ValidationFailure>());
    expect(state.requestId, isNull);
    expect(repository.requestIds, isEmpty);
    expect(generator.callCount, 0);
  });

  test('successful correction stores result and clears failure', () async {
    final repository = _QueueRepository(<AppResult<MachineCorrectionResult>>[
      AppResult<MachineCorrectionResult>.success(_successResult()),
    ]);

    final generator = _SequenceRequestIdGenerator(<String>[
      '123e4567-e89b-42d3-a456-426614174000',
    ]);

    final container = _container(repository: repository, generator: generator);
    addTearDown(container.dispose);

    final controller = container.read(
      machineCorrectionControllerProvider.notifier,
    );

    controller.begin(_draft('修正1'));

    expect(await controller.submit(), isTrue);

    final state = container.read(machineCorrectionControllerProvider);

    expect(state.isSubmitting, isFalse);
    expect(state.failure, isNull);
    expect(state.result?.correctionId, 'c_1234567890abcdef1234567890abcd');
  });
}

ProviderContainer _container({
  required MachineCorrectionRepository repository,
  required MachineProductUpdateRequestIdGenerator generator,
}) {
  return ProviderContainer(
    overrides: [
      machineCorrectionRepositoryProvider.overrideWithValue(repository),
      machineCorrectionRequestIdGeneratorProvider.overrideWithValue(generator),
    ],
  );
}

MachineCorrectionDraft _draft(String name) {
  return MachineCorrectionDraft(
    machineId: VendingMachineId.tryParse('machine-001')!,
    name: MachineCorrectionField<String>.changed(name),
  );
}

MachineCorrectionResult _successResult() {
  return MachineCorrectionResult(
    machineId: VendingMachineId.tryParse('machine-001')!,
    correctionId: 'c_1234567890abcdef1234567890abcd',
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

final class _QueueRepository implements MachineCorrectionRepository {
  _QueueRepository(this.responses);

  final List<AppResult<MachineCorrectionResult>> responses;
  final List<String> requestIds = <String>[];
  var _nextResponse = 0;

  @override
  Future<AppResult<MachineCorrectionResult>> submitCorrection({
    required String requestId,
    required MachineCorrectionDraft draft,
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
