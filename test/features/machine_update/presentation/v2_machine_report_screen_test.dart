import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../../lib/features/machine_update/application/machine_report_controller.dart';
import '../../../../lib/features/machine_update/domain/models/machine_report_category.dart';
import '../../../../lib/features/machine_update/presentation/v2_machine_report_screen.dart';
import '../../../../lib/features/vending_machine/domain/value_objects/vending_machine_id.dart';

void main() {
  testWidgets('category and message create report draft', (tester) async {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    var reviewed = 0;

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          home: V2MachineReportScreen(
            machineId: VendingMachineId.tryParse('machine-001')!,
            onReviewPressed: () {
              reviewed += 1;
            },
          ),
        ),
      ),
    );

    await tester.tap(
      find.byKey(const Key('machineReportCategory_machineRemoved')),
    );

    await tester.enterText(
      find.byKey(const Key('machineReportMessageField')),
      '撤去されていました',
    );

    await tester.ensureVisible(
      find.byKey(const Key('machineReportReviewButton')),
    );

    await tester.tap(find.byKey(const Key('machineReportReviewButton')));

    await tester.pump();

    final state = container.read(machineReportControllerProvider);

    expect(reviewed, 1);
    expect(state.draft?.category, MachineReportCategory.machineRemoved);
    expect(state.draft?.message, '撤去されていました');
    expect(state.draft?.photoId, isNull);
  });

  testWidgets('review requires a report category', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: V2MachineReportScreen(
            machineId: VendingMachineId.tryParse('machine-001')!,
            onReviewPressed: () {},
          ),
        ),
      ),
    );

    await tester.ensureVisible(
      find.byKey(const Key('machineReportReviewButton')),
    );

    await tester.tap(find.byKey(const Key('machineReportReviewButton')));

    await tester.pump();

    expect(find.text('問題の種類を選んでください。'), findsOneWidget);
  });
}
