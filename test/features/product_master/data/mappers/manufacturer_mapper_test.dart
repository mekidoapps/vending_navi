import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vending_app/core/errors/app_failure.dart';
import 'package:vending_app/features/product_master/data/dtos/manufacturer_dto.dart';
import 'package:vending_app/features/product_master/data/mappers/manufacturer_mapper.dart';

void main() {
  final createdAt = DateTime.utc(2026, 8, 1);
  final updatedAt = DateTime.utc(2026, 8, 6);

  test('DTOを正規化してManufacturer Domainへ変換する', () {
    final result = ManufacturerMapper.toDomain(
      ManufacturerDto(
        documentId: 'coca_cola',
        name: ' コカ・コーラ ボトラーズジャパン ',
        displayShortName: ' コカ・コーラ ',
        searchKeywords: const <String>[' コカコーラ ', 'コカコーラ', ''],
        presetProductIds: const <String>[
          'coca_cola_ayataka',
          'coca_cola_ayataka',
        ],
        createdAt: createdAt,
        updatedAt: updatedAt,
      ),
    );

    final manufacturer = result.valueOrNull;
    expect(manufacturer, isNotNull);
    expect(manufacturer!.name, 'コカ・コーラ ボトラーズジャパン');
    expect(manufacturer.displayShortName, 'コカ・コーラ');
    expect(manufacturer.searchKeywords, const <String>['コカコーラ']);
    expect(manufacturer.presetProductIds, hasLength(1));
  });

  test('不正なプリセット商品IDは自動補正せず失敗結果にする', () {
    final result = ManufacturerMapper.toDomain(
      ManufacturerDto(
        documentId: 'coca_cola',
        name: 'コカ・コーラ ボトラーズジャパン',
        displayShortName: 'コカ・コーラ',
        presetProductIds: const <String>['Invalid Product'],
        createdAt: createdAt,
        updatedAt: updatedAt,
      ),
    );

    final failure = result.failureOrNull;
    expect(failure, isA<ValidationFailure>());
    expect(
      (failure as ValidationFailure).field,
      'manufacturer.presetProductIds',
    );
  });

  test('欠損したFirestoreデータでもクラッシュせず失敗結果を返す', () {
    final result = ManufacturerMapper.fromFirestoreDocument(
      documentId: 'coca_cola',
      data: <String, dynamic>{
        'name': 'コカ・コーラ ボトラーズジャパン',
        'createdAt': Timestamp.fromDate(createdAt),
        'updatedAt': Timestamp.fromDate(updatedAt),
      },
    );

    expect(result.isFailure, isTrue);
    expect(
      (result.failureOrNull as ValidationFailure).field,
      'manufacturer.document',
    );
  });

  test('DomainからDTOへ戻してプリセット商品IDを保持する', () {
    final domainResult = ManufacturerMapper.toDomain(
      ManufacturerDto(
        documentId: 'coca_cola',
        name: 'コカ・コーラ ボトラーズジャパン',
        displayShortName: 'コカ・コーラ',
        presetProductIds: const <String>['coca_cola_ayataka'],
        createdAt: createdAt,
        updatedAt: updatedAt,
      ),
    );

    final dto = ManufacturerMapper.toDto(domainResult.valueOrNull!);

    expect(dto.documentId, 'coca_cola');
    expect(dto.presetProductIds, const <String>['coca_cola_ayataka']);
  });
}
