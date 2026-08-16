import 'package:flutter_test/flutter_test.dart';
import 'package:vending_app/features/machine_registration/data/repositories/machine_registration_repository_impl.dart';
import 'package:vending_app/features/machine_registration/data/sources/machine_registration_data_source.dart';
import 'package:vending_app/features/machine_registration/domain/entities/machine_registration_draft.dart';
import 'package:vending_app/features/machine_registration/domain/entities/machine_registration_method.dart';
import 'package:vending_app/features/product_master/domain/value_objects/master_id.dart';
import 'package:vending_app/features/vending_machine/domain/value_objects/geo_coordinate.dart';

void main() {
  test('Callable resultをDomain resultへ変換する', () async {
    final source = _FakeSource(
      response: <String, Object?>{
        'machineId': 'machine_001',
        'created': true,
        'duplicateCandidates': <Object?>[],
      },
    );
    final repository = MachineRegistrationRepositoryImpl(source);

    final result = await repository.createVendingMachine(
      MachineRegistrationDraft(
        requestId: '123e4567-e89b-42d3-a456-426614174000',
        location: GeoCoordinate(latitude: 35.68, longitude: 139.76),
        registrationMethod: MachineRegistrationMethod.manufacturer,
        manufacturerId: ManufacturerId.parse('coca_cola'),
      ),
    );

    expect(result.failureOrNull, isNull);
    expect(result.valueOrNull?.machineId.value, 'machine_001');
    expect(result.valueOrNull?.created, isTrue);
    expect(source.lastRequest?['registrationMethod'], 'manufacturer');
  });

  test('photo登録の確定内容をDataSourceまで保持する', () async {
    final source = _FakeSource(
      response: <String, Object?>{
        'machineId': 'machine_photo_001',
        'created': true,
        'duplicateCandidates': <Object?>[],
      },
    );
    final repository = MachineRegistrationRepositoryImpl(source);

    final result = await repository.createVendingMachine(
      MachineRegistrationDraft(
        requestId: '123e4567-e89b-42d3-a456-426614174000',
        location: GeoCoordinate(latitude: 35.68, longitude: 139.76),
        registrationMethod: MachineRegistrationMethod.photo,
        manufacturerId: ManufacturerId.parse('asahi'),
        confirmedProductIds: <ProductId>[
          ProductId.parse('asahi_wonda_black'),
          ProductId.parse('asahi_calpis_water'),
        ],
        temporaryPhotoUploadId: '123e4567-e89b-42d3-a456-426614174001',
      ),
    );

    expect(result.failureOrNull, isNull);
    expect(result.valueOrNull?.machineId.value, 'machine_photo_001');

    expect(source.lastRequest?['registrationMethod'], 'photo');
    expect(source.lastRequest?['manufacturerId'], 'asahi');
    expect(source.lastRequest?['confirmedProductIds'], <String>[
      'asahi_wonda_black',
      'asahi_calpis_water',
    ]);
    expect(
      source.lastRequest?['temporaryPhotoUploadId'],
      '123e4567-e89b-42d3-a456-426614174001',
    );
  });
}

final class _FakeSource implements MachineRegistrationDataSource {
  _FakeSource({required this.response});

  final Map<String, Object?> response;
  Map<String, Object?>? lastRequest;

  @override
  Future<Map<String, Object?>> createVendingMachine(
    Map<String, Object?> request,
  ) async {
    lastRequest = request;
    return response;
  }
}
