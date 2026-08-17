import 'package:flutter_test/flutter_test.dart';

import '../../../../../lib/core/errors/app_failure.dart';
import '../../../../../lib/features/machine_update/data/repositories/machine_photo_finalization_repository_impl.dart';
import '../../../../../lib/features/machine_update/data/sources/machine_photo_finalization_data_source.dart';
import '../../../../../lib/features/vending_machine/domain/value_objects/vending_machine_id.dart';

void main() {
  final machineId = VendingMachineId.tryParse('machine_001')!;

  test('valid callable response becomes domain result', () async {
    final source = _Source(
      response: <String, Object?>{
        'machineId': 'machine_001',
        'photoId': 'p_123',
        'added': true,
        'primaryPhotoChanged': true,
      },
    );

    final repository = MachinePhotoFinalizationRepositoryImpl(source);

    final result = await repository.addPhoto(
      requestId: '11111111-1111-4111-8111-111111111111',
      machineId: machineId,
      temporaryPhotoUploadId: '22222222-2222-4222-8222-222222222222',
    );

    expect(result.isSuccess, isTrue);
    expect(result.valueOrNull?.photoId, 'p_123');
    expect(result.valueOrNull?.primaryPhotoChanged, isTrue);

    expect(source.lastRequest?['machineId'], 'machine_001');
  });

  test('response for another machine is rejected', () async {
    final source = _Source(
      response: <String, Object?>{
        'machineId': 'machine_002',
        'photoId': 'p_123',
        'added': true,
        'primaryPhotoChanged': false,
      },
    );

    final repository = MachinePhotoFinalizationRepositoryImpl(source);

    final result = await repository.addPhoto(
      requestId: '11111111-1111-4111-8111-111111111111',
      machineId: machineId,
      temporaryPhotoUploadId: '22222222-2222-4222-8222-222222222222',
    );

    expect(result.isFailure, isTrue);
    expect(result.failureOrNull, isA<ValidationFailure>());
  });
}

final class _Source implements MachinePhotoFinalizationDataSource {
  _Source({required this.response});

  final Map<String, Object?> response;
  Map<String, Object?>? lastRequest;

  @override
  Future<Map<String, Object?>> addVendingMachinePhoto(
    Map<String, Object?> request,
  ) async {
    lastRequest = request;
    return response;
  }
}
