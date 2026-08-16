import 'package:flutter_test/flutter_test.dart';
import 'package:vending_app/features/machine_registration/data/dtos/create_vending_machine_request_dto.dart';
import 'package:vending_app/features/machine_registration/domain/entities/machine_registration_draft.dart';
import 'package:vending_app/features/machine_registration/domain/entities/machine_registration_method.dart';
import 'package:vending_app/features/product_master/domain/value_objects/master_id.dart';
import 'package:vending_app/features/vending_machine/domain/value_objects/geo_coordinate.dart';

void main() {
  test('manufacturer登録をCallable契約へ変換する', () {
    final dto = CreateVendingMachineRequestDto.fromDraft(
      MachineRegistrationDraft(
        requestId: '123e4567-e89b-42d3-a456-426614174000',
        location: GeoCoordinate(latitude: 35.68, longitude: 139.76),
        registrationMethod: MachineRegistrationMethod.manufacturer,
        manufacturerId: ManufacturerId.parse('coca_cola'),
        confirmedProductIds: <ProductId>[
          ProductId.parse('ayataka_regular'),
          ProductId.parse('ayataka_regular'),
        ],
        name: '  駅前の自販機  ',
      ),
    );

    final map = dto.toMap();

    expect(map['requestId'], '123e4567-e89b-42d3-a456-426614174000');
    expect(map['registrationMethod'], 'manufacturer');
    expect(map['manufacturerId'], 'coca_cola');
    expect(map['confirmedProductIds'], <String>['ayataka_regular']);
    expect(map['name'], '駅前の自販機');
    expect(map['temporaryPhotoUploadId'], isNull);
  });

  test('locationOnlyはメーカー・商品・写真を含めない', () {
    final dto = CreateVendingMachineRequestDto.fromDraft(
      MachineRegistrationDraft(
        requestId: '123e4567-e89b-42d3-a456-426614174000',
        location: GeoCoordinate(latitude: 35.68, longitude: 139.76),
        registrationMethod: MachineRegistrationMethod.locationOnly,
      ),
    );

    final map = dto.toMap();

    expect(map['registrationMethod'], 'locationOnly');
    expect(map['manufacturerId'], isNull);
    expect(map['confirmedProductIds'], isEmpty);
    expect(map['temporaryPhotoUploadId'], isNull);
  });

  test('photo登録を写真・メーカー・確認済み商品込みでCallable契約へ変換する', () {
    final dto = CreateVendingMachineRequestDto.fromDraft(
      MachineRegistrationDraft(
        requestId: '123e4567-e89b-42d3-a456-426614174000',
        location: GeoCoordinate(latitude: 35.68, longitude: 139.76),
        registrationMethod: MachineRegistrationMethod.photo,
        manufacturerId: ManufacturerId.parse('asahi'),
        confirmedProductIds: <ProductId>[
          ProductId.parse('asahi_wonda_black'),
          ProductId.parse('asahi_calpis_water'),
          ProductId.parse('asahi_wonda_black'),
        ],
        temporaryPhotoUploadId: '123e4567-e89b-42d3-a456-426614174001',
      ),
    );

    final map = dto.toMap();

    expect(map['registrationMethod'], 'photo');
    expect(map['manufacturerId'], 'asahi');
    expect(map['confirmedProductIds'], <String>[
      'asahi_wonda_black',
      'asahi_calpis_water',
    ]);
    expect(
      map['temporaryPhotoUploadId'],
      '123e4567-e89b-42d3-a456-426614174001',
    );
  });

  test('manufacturer登録でmanufacturerId欠損は拒否する', () {
    expect(
      () => CreateVendingMachineRequestDto.fromDraft(
        MachineRegistrationDraft(
          requestId: '123e4567-e89b-42d3-a456-426614174000',
          location: GeoCoordinate(latitude: 35.68, longitude: 139.76),
          registrationMethod: MachineRegistrationMethod.manufacturer,
        ),
      ),
      throwsFormatException,
    );
  });
}
