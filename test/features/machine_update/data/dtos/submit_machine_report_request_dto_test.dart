import 'package:flutter_test/flutter_test.dart';

import '../../../../../lib/features/machine_update/data/dtos/submit_machine_report_request_dto.dart';
import '../../../../../lib/features/machine_update/domain/models/machine_report_category.dart';
import '../../../../../lib/features/machine_update/domain/models/machine_report_draft.dart';
import '../../../../../lib/features/vending_machine/domain/value_objects/vending_machine_id.dart';

void main() {
  test('serializes machine report and normalizes message', () {
    final dto = SubmitMachineReportRequestDto(
      requestId: '123e4567-e89b-42d3-a456-426614174000',
      draft: MachineReportDraft(
        machineId: VendingMachineId.tryParse('machine-001')!,
        category: MachineReportCategory.machineRemoved,
        message: ' 撤去されていました ',
      ),
    );

    expect(dto.toMap(), <String, Object?>{
      'requestId': '123e4567-e89b-42d3-a456-426614174000',
      'machineId': 'machine-001',
      'photoId': null,
      'category': 'machineRemoved',
      'message': '撤去されていました',
    });
  });

  test('serializes formal photo report', () {
    const photoId = 'p_1234567890abcdef1234567890abcd';

    final dto = SubmitMachineReportRequestDto(
      requestId: '123e4567-e89b-42d3-a456-426614174000',
      draft: MachineReportDraft(
        machineId: VendingMachineId.tryParse('machine-001')!,
        category: MachineReportCategory.inappropriatePhoto,
        photoId: photoId,
      ),
    );

    final map = dto.toMap();

    expect(map['photoId'], photoId);
    expect(map['category'], 'inappropriatePhoto');
    expect(map['message'], isNull);
  });

  test('rejects invalid formal photo id', () {
    final dto = SubmitMachineReportRequestDto(
      requestId: '123e4567-e89b-42d3-a456-426614174000',
      draft: MachineReportDraft(
        machineId: VendingMachineId.tryParse('machine-001')!,
        category: MachineReportCategory.inappropriatePhoto,
        photoId: 'photo-001',
      ),
    );

    expect(dto.toMap, throwsFormatException);
  });

  test('empty message is normalized to null', () {
    final dto = SubmitMachineReportRequestDto(
      requestId: '123e4567-e89b-42d3-a456-426614174000',
      draft: MachineReportDraft(
        machineId: VendingMachineId.tryParse('machine-001')!,
        category: MachineReportCategory.other,
        message: '   ',
      ),
    );

    expect(dto.toMap()['message'], isNull);
  });

  test('message longer than 500 characters is rejected', () {
    final dto = SubmitMachineReportRequestDto(
      requestId: '123e4567-e89b-42d3-a456-426614174000',
      draft: MachineReportDraft(
        machineId: VendingMachineId.tryParse('machine-001')!,
        category: MachineReportCategory.other,
        message: 'a' * 501,
      ),
    );

    expect(dto.toMap, throwsFormatException);
  });
}
