import 'package:flutter_test/flutter_test.dart';

import '../../../../../lib/features/machine_update/data/repositories/machine_report_repository_impl.dart';
import '../../../../../lib/features/machine_update/data/sources/machine_report_data_source.dart';
import '../../../../../lib/features/machine_update/domain/models/machine_report_category.dart';
import '../../../../../lib/features/machine_update/domain/models/machine_report_draft.dart';
import '../../../../../lib/features/vending_machine/domain/value_objects/vending_machine_id.dart';

void main() {
  test('maps callable response to machine report result', () async {
    final source = _FixtureSource(<String, Object?>{
      'machineId': 'machine-001',
      'reportId': 'r_1234567890abcdef1234567890abcd',
      'submitted': true,
    });

    final repository = MachineReportRepositoryImpl(source);

    final result = await repository.submitReport(
      requestId: '123e4567-e89b-42d3-a456-426614174000',
      draft: MachineReportDraft(
        machineId: VendingMachineId.tryParse('machine-001')!,
        category: MachineReportCategory.inaccessible,
        message: '利用できません',
      ),
    );

    expect(result.failureOrNull, isNull);
    expect(result.valueOrNull?.reportId, 'r_1234567890abcdef1234567890abcd');

    expect(source.lastRequest?['machineId'], 'machine-001');
    expect(source.lastRequest?['category'], 'inaccessible');
    expect(source.lastRequest?['message'], '利用できません');
    expect(
      source.lastRequest?['requestId'],
      '123e4567-e89b-42d3-a456-426614174000',
    );
  });

  test('passes formal photo id to callable request', () async {
    final source = _FixtureSource(<String, Object?>{
      'machineId': 'machine-001',
      'reportId': 'r_1234567890abcdef1234567890abcd',
      'submitted': true,
    });

    final repository = MachineReportRepositoryImpl(source);

    final result = await repository.submitReport(
      requestId: '123e4567-e89b-42d3-a456-426614174000',
      draft: MachineReportDraft(
        machineId: VendingMachineId.tryParse('machine-001')!,
        category: MachineReportCategory.inappropriatePhoto,
        photoId: 'p_1234567890abcdef1234567890abcd',
      ),
    );

    expect(result.failureOrNull, isNull);
    expect(source.lastRequest?['photoId'], 'p_1234567890abcdef1234567890abcd');
  });

  test('rejects response for a different machine', () async {
    final repository = MachineReportRepositoryImpl(
      _FixtureSource(<String, Object?>{
        'machineId': 'machine-999',
        'reportId': 'r_1234567890abcdef1234567890abcd',
        'submitted': true,
      }),
    );

    final result = await repository.submitReport(
      requestId: '123e4567-e89b-42d3-a456-426614174000',
      draft: MachineReportDraft(
        machineId: VendingMachineId.tryParse('machine-001')!,
        category: MachineReportCategory.other,
      ),
    );

    expect(result.valueOrNull, isNull);
    expect(result.failureOrNull, isNotNull);
  });

  test('rejects malformed callable response', () async {
    final repository = MachineReportRepositoryImpl(
      _FixtureSource(<String, Object?>{
        'machineId': 'machine-001',
        'reportId': 'bad-report-id',
        'submitted': true,
      }),
    );

    final result = await repository.submitReport(
      requestId: '123e4567-e89b-42d3-a456-426614174000',
      draft: MachineReportDraft(
        machineId: VendingMachineId.tryParse('machine-001')!,
        category: MachineReportCategory.other,
      ),
    );

    expect(result.valueOrNull, isNull);
    expect(result.failureOrNull, isNotNull);
  });
}

final class _FixtureSource implements MachineReportDataSource {
  _FixtureSource(this.response);

  final Map<String, Object?> response;
  Map<String, Object?>? lastRequest;

  @override
  Future<Map<String, Object?>> submitMachineReport(
    Map<String, Object?> request,
  ) async {
    lastRequest = request;
    return response;
  }
}
