import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../../lib/core/result/app_result.dart';
import '../../../../lib/features/machine_update/application/machine_product_update_controller.dart';
import '../../../../lib/features/machine_update/application/providers/machine_product_update_providers.dart';
import '../../../../lib/features/machine_update/domain/models/machine_product_update_draft.dart';
import '../../../../lib/features/machine_update/domain/models/machine_product_update_operation.dart';
import '../../../../lib/features/machine_update/domain/models/machine_product_update_result.dart';
import '../../../../lib/features/machine_update/domain/repositories/machine_product_update_repository.dart';
import '../../../../lib/features/machine_update/domain/services/machine_product_update_request_id_generator.dart';
import '../../../../lib/features/machine_update/presentation/v2_product_update_confirmation_screen.dart';
import '../../../../lib/features/vending_machine/domain/value_objects/vending_machine_id.dart';

void main() {
  testWidgets('shows review and submits through controller', (tester) async {
    final machineId = VendingMachineId.tryParse('machine-001')!;

    final repository = _SuccessRepository(
      MachineProductUpdateResult(
        machineId: machineId,
        updated: true,
        changedProductIds: const <String>['asahi_calpis'],
      ),
    );

    var completed = 0;

    final container = ProviderContainer(
      overrides: [
        machineProductUpdateRepositoryProvider.overrideWithValue(repository),
        machineProductUpdateRequestIdGeneratorProvider.overrideWithValue(
          const _RequestIdGenerator(),
        ),
      ],
    );
    addTearDown(container.dispose);

    container
        .read(machineProductUpdateControllerProvider.notifier)
        .begin(
          MachineProductUpdateDraft(
            machineId: machineId,
            productNames: const <String, String>{'asahi_calpis': 'カルピス'},
            operations: const <MachineProductUpdateOperation>[
              MachineProductUpdateOperation.addConfirmed(
                productId: 'asahi_calpis',
                source: MachineProductUpdateSource.manual,
              ),
            ],
          ),
        );

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          home: V2ProductUpdateConfirmationScreen(
            machineId: machineId,
            onCompleted: () {
              completed += 1;
            },
          ),
        ),
      ),
    );

    expect(
      find.byKey(const Key('productUpdateConfirmationScreen')),
      findsOneWidget,
    );
    expect(find.text('カルピス'), findsOneWidget);
    expect(find.text('商品を追加'), findsOneWidget);

    await tester.tap(find.byKey(const Key('submitMachineProductUpdateButton')));

    await tester.pumpAndSettle();

    expect(repository.callCount, 1);
    expect(repository.lastRequestId, '123e4567-e89b-42d3-a456-426614174000');
    expect(completed, 1);
  });

  testWidgets('does not allow submission without a valid draft', (
    tester,
  ) async {
    final machineId = VendingMachineId.tryParse('machine-001')!;

    final container = ProviderContainer();
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          home: V2ProductUpdateConfirmationScreen(
            machineId: machineId,
            onCompleted: () {},
          ),
        ),
      ),
    );

    expect(find.byKey(const Key('missingProductUpdateDraft')), findsOneWidget);
    expect(
      find.byKey(const Key('submitMachineProductUpdateButton')),
      findsNothing,
    );
  });
}

final class _SuccessRepository implements MachineProductUpdateRepository {
  _SuccessRepository(this.result);

  final MachineProductUpdateResult result;

  int callCount = 0;
  String? lastRequestId;

  @override
  Future<AppResult<MachineProductUpdateResult>> updateProducts({
    required String requestId,
    required MachineProductUpdateDraft draft,
  }) async {
    callCount += 1;
    lastRequestId = requestId;

    return AppResult<MachineProductUpdateResult>.success(result);
  }
}

final class _RequestIdGenerator
    implements MachineProductUpdateRequestIdGenerator {
  const _RequestIdGenerator();

  @override
  String next() => '123e4567-e89b-42d3-a456-426614174000';
}
