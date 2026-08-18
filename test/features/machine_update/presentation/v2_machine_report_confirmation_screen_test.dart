import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../../lib/core/result/app_result.dart';
import '../../../../lib/features/machine_update/application/machine_report_controller.dart';
import '../../../../lib/features/machine_update/application/providers/machine_report_providers.dart';
import '../../../../lib/features/machine_update/domain/models/machine_report_category.dart';
import '../../../../lib/features/machine_update/domain/models/machine_report_draft.dart';
import '../../../../lib/features/machine_update/domain/models/machine_report_result.dart';
import '../../../../lib/features/machine_update/domain/repositories/machine_report_repository.dart';
import '../../../../lib/features/machine_update/presentation/v2_machine_report_confirmation_screen.dart';
import '../../../../lib/features/vending_machine/domain/value_objects/vending_machine_id.dart';

void main() {
  testWidgets('report confirmation submits and explains moderation', (
    tester,
  ) async {
    final machineId = VendingMachineId.tryParse('machine-001')!;
    final repository = _SuccessRepository(machineId);

    final container = ProviderContainer(
      overrides: [
        machineReportRepositoryProvider.overrideWithValue(repository),
      ],
    );
    addTearDown(container.dispose);

    container
        .read(machineReportControllerProvider.notifier)
        .begin(
          MachineReportDraft(
            machineId: machineId,
            category: MachineReportCategory.machineRemoved,
            message: '撤去を確認',
          ),
        );

    var completed = 0;

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          home: V2MachineReportConfirmationScreen(
            machineId: machineId,
            onCompleted: () {
              completed += 1;
            },
          ),
        ),
      ),
    );

    expect(find.text('自販機が撤去されている'), findsOneWidget);
    expect(find.text('撤去を確認'), findsOneWidget);
    expect(
      find.byKey(const Key('machineReportModerationNotice')),
      findsOneWidget,
    );

    await tester.ensureVisible(
      find.byKey(const Key('submitMachineReportButton')),
    );

    await tester.tap(find.byKey(const Key('submitMachineReportButton')));

    await tester.pumpAndSettle();

    expect(completed, 1);
    expect(repository.callCount, 1);
  });
}

final class _SuccessRepository implements MachineReportRepository {
  _SuccessRepository(this.machineId);

  final VendingMachineId machineId;
  var callCount = 0;

  @override
  Future<AppResult<MachineReportResult>> submitReport({
    required String requestId,
    required MachineReportDraft draft,
  }) async {
    callCount += 1;

    return AppResult<MachineReportResult>.success(
      MachineReportResult(
        machineId: machineId,
        reportId: 'r_1234567890abcdef1234567890abcd',
      ),
    );
  }
}
