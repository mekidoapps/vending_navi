import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../../lib/core/errors/app_failure.dart';
import '../../../../lib/core/result/app_result.dart';
import '../../../../lib/features/machine_update/application/machine_report_controller.dart';
import '../../../../lib/features/machine_update/application/providers/machine_report_providers.dart';
import '../../../../lib/features/machine_update/domain/models/machine_report_category.dart';
import '../../../../lib/features/machine_update/domain/models/machine_report_draft.dart';
import '../../../../lib/features/machine_update/domain/models/machine_report_result.dart';
import '../../../../lib/features/machine_update/domain/repositories/machine_report_repository.dart';
import '../../../../lib/features/machine_update/domain/services/machine_product_update_request_id_generator.dart';
import '../../../../lib/features/vending_machine/domain/value_objects/vending_machine_id.dart';

void main() {
  test('failed retry reuses the same report requestId', () async {
    final repository = _QueueRepository(<AppResult<MachineReportResult>>[
      const AppResult<MachineReportResult>.failure(NetworkFailure()),
      AppResult<MachineReportResult>.success(_successResult()),
    ]);

    final generator = _SequenceRequestIdGenerator(<String>[
      '123e4567-e89b-42d3-a456-426614174000',
      '123e4567-e89b-42d3-a456-426614174001',
    ]);

    final container = _container(repository: repository, generator: generator);
    addTearDown(container.dispose);

    final controller = container.read(machineReportControllerProvider.notifier);

    controller.begin(_draft(MachineReportCategory.machineRemoved));

    expect(await controller.submit(), isFalse);
    expect(await controller.submit(), isTrue);

    expect(repository.requestIds, <String>[
      '123e4567-e89b-42d3-a456-426614174000',
      '123e4567-e89b-42d3-a456-426614174000',
    ]);

    expect(generator.callCount, 1);
  });

  test('replacing report after failure clears old requestId', () async {
    final repository = _QueueRepository(<AppResult<MachineReportResult>>[
      const AppResult<MachineReportResult>.failure(NetworkFailure()),
      AppResult<MachineReportResult>.success(_successResult()),
    ]);

    final generator = _SequenceRequestIdGenerator(<String>[
      '123e4567-e89b-42d3-a456-426614174000',
      '123e4567-e89b-42d3-a456-426614174001',
    ]);

    final container = _container(repository: repository, generator: generator);
    addTearDown(container.dispose);

    final controller = container.read(machineReportControllerProvider.notifier);

    controller.begin(_draft(MachineReportCategory.machineRemoved));

    expect(await controller.submit(), isFalse);

    controller.replaceDraft(_draft(MachineReportCategory.inaccessible));

    expect(container.read(machineReportControllerProvider).requestId, isNull);

    expect(await controller.submit(), isTrue);

    expect(repository.requestIds, <String>[
      '123e4567-e89b-42d3-a456-426614174000',
      '123e4567-e89b-42d3-a456-426614174001',
    ]);

    expect(generator.callCount, 2);
  });

  test('submit without a report draft is rejected', () async {
    final repository = _QueueRepository(<AppResult<MachineReportResult>>[]);

    final generator = _SequenceRequestIdGenerator(<String>[
      '123e4567-e89b-42d3-a456-426614174000',
    ]);

    final container = _container(repository: repository, generator: generator);
    addTearDown(container.dispose);

    final controller = container.read(machineReportControllerProvider.notifier);

    expect(await controller.submit(), isFalse);

    final state = container.read(machineReportControllerProvider);

    expect(state.failure, isA<ValidationFailure>());
    expect(state.requestId, isNull);
    expect(repository.requestIds, isEmpty);
    expect(generator.callCount, 0);
  });

  test('successful report stores result and clears failure', () async {
    final repository = _QueueRepository(<AppResult<MachineReportResult>>[
      AppResult<MachineReportResult>.success(_successResult()),
    ]);

    final generator = _SequenceRequestIdGenerator(<String>[
      '123e4567-e89b-42d3-a456-426614174000',
    ]);

    final container = _container(repository: repository, generator: generator);
    addTearDown(container.dispose);

    final controller = container.read(machineReportControllerProvider.notifier);

    controller.begin(_draft(MachineReportCategory.other));

    expect(await controller.submit(), isTrue);

    final state = container.read(machineReportControllerProvider);

    expect(state.isSubmitting, isFalse);
    expect(state.failure, isNull);
    expect(state.result?.reportId, 'r_1234567890abcdef1234567890abcd');
  });

  test(
    'second submit is rejected while first request is in progress',
    () async {
      final repository = _BlockingRepository();

      final generator = _SequenceRequestIdGenerator(<String>[
        '123e4567-e89b-42d3-a456-426614174000',
      ]);

      final container = _container(
        repository: repository,
        generator: generator,
      );
      addTearDown(container.dispose);

      final controller = container.read(
        machineReportControllerProvider.notifier,
      );

      controller.begin(_draft(MachineReportCategory.duplicate));

      final firstSubmit = controller.submit();

      await Future<void>.delayed(Duration.zero);

      expect(
        container.read(machineReportControllerProvider).isSubmitting,
        isTrue,
      );

      expect(await controller.submit(), isFalse);
      expect(repository.callCount, 1);
      expect(generator.callCount, 1);

      repository.complete(
        AppResult<MachineReportResult>.success(_successResult()),
      );

      expect(await firstSubmit, isTrue);
    },
  );
}

ProviderContainer _container({
  required MachineReportRepository repository,
  required MachineProductUpdateRequestIdGenerator generator,
}) {
  return ProviderContainer(
    overrides: [
      machineReportRepositoryProvider.overrideWithValue(repository),
      machineReportRequestIdGeneratorProvider.overrideWithValue(generator),
    ],
  );
}

MachineReportDraft _draft(MachineReportCategory category) {
  return MachineReportDraft(
    machineId: VendingMachineId.tryParse('machine-001')!,
    category: category,
  );
}

MachineReportResult _successResult() {
  return MachineReportResult(
    machineId: VendingMachineId.tryParse('machine-001')!,
    reportId: 'r_1234567890abcdef1234567890abcd',
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

final class _QueueRepository implements MachineReportRepository {
  _QueueRepository(this.responses);

  final List<AppResult<MachineReportResult>> responses;
  final List<String> requestIds = <String>[];
  var _nextResponse = 0;

  @override
  Future<AppResult<MachineReportResult>> submitReport({
    required String requestId,
    required MachineReportDraft draft,
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

final class _BlockingRepository implements MachineReportRepository {
  final Completer<AppResult<MachineReportResult>> _completer =
      Completer<AppResult<MachineReportResult>>();

  var callCount = 0;

  @override
  Future<AppResult<MachineReportResult>> submitReport({
    required String requestId,
    required MachineReportDraft draft,
  }) {
    callCount += 1;
    return _completer.future;
  }

  void complete(AppResult<MachineReportResult> result) {
    _completer.complete(result);
  }
}
