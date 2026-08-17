import 'package:flutter_test/flutter_test.dart';

import '../../../../../lib/features/machine_update/data/repositories/machine_correction_repository_impl.dart';
import '../../../../../lib/features/machine_update/data/sources/machine_correction_data_source.dart';
import '../../../../../lib/features/machine_update/domain/models/machine_correction_draft.dart';
import '../../../../../lib/features/machine_update/domain/models/machine_correction_field.dart';
import '../../../../../lib/features/vending_machine/domain/value_objects/vending_machine_id.dart';

void main() {
  test('maps callable response to correction result', () async {
    final source = _FixtureSource(<String, Object?>{
      'machineId': 'machine-001',
      'correctionId': 'c_1234567890abcdef1234567890abcd',
      'submitted': true,
    });

    final repository = MachineCorrectionRepositoryImpl(source);

    final result = await repository.submitCorrection(
      requestId: '123e4567-e89b-42d3-a456-426614174000',
      draft: MachineCorrectionDraft(
        machineId: VendingMachineId.tryParse('machine-001')!,
        name: const MachineCorrectionField<String>.changed('新しい名前'),
      ),
    );

    expect(result.failureOrNull, isNull);
    expect(
      result.valueOrNull?.correctionId,
      'c_1234567890abcdef1234567890abcd',
    );
    expect(source.lastRequest?['machineId'], 'machine-001');
    expect(
      source.lastRequest?['requestId'],
      '123e4567-e89b-42d3-a456-426614174000',
    );
  });

  test('rejects response for a different machine', () async {
    final repository = MachineCorrectionRepositoryImpl(
      _FixtureSource(<String, Object?>{
        'machineId': 'machine-999',
        'correctionId': 'c_1234567890abcdef1234567890abcd',
        'submitted': true,
      }),
    );

    final result = await repository.submitCorrection(
      requestId: '123e4567-e89b-42d3-a456-426614174000',
      draft: MachineCorrectionDraft(
        machineId: VendingMachineId.tryParse('machine-001')!,
        name: const MachineCorrectionField<String>.changed('新しい名前'),
      ),
    );

    expect(result.valueOrNull, isNull);
    expect(result.failureOrNull, isNotNull);
  });
}

final class _FixtureSource implements MachineCorrectionDataSource {
  _FixtureSource(this.response);

  final Map<String, Object?> response;
  Map<String, Object?>? lastRequest;

  @override
  Future<Map<String, Object?>> submitMachineCorrection(
    Map<String, Object?> request,
  ) async {
    lastRequest = request;
    return response;
  }
}
