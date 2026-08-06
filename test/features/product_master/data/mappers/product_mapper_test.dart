import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vending_app/core/errors/app_failure.dart';
import 'package:vending_app/features/product_master/data/dtos/product_dto.dart';
import 'package:vending_app/features/product_master/data/mappers/product_mapper.dart';
import 'package:vending_app/features/product_master/domain/entities/product_genre.dart';

void main() {
  final createdAt = DateTime.utc(2026, 8, 1);
  final updatedAt = DateTime.utc(2026, 8, 6);

  test('DTOを正規化してProduct Domainへ変換する', () {
    final result = ProductMapper.toDomain(
      ProductDto(
        documentId: 'coca_cola_ayataka',
        name: ' 綾鷹 ',
        manufacturerId: 'coca_cola',
        searchKeywords: const <String>[' あやたか ', 'あやたか', ''],
        genreIds: const <String>['green_tea', 'green_tea'],
        imageUrl: ' ',
        createdAt: createdAt,
        updatedAt: updatedAt,
      ),
    );

    final product = result.valueOrNull;
    expect(product, isNotNull);
    expect(product!.name, '綾鷹');
    expect(product.searchKeywords, const <String>['あやたか']);
    expect(product.genres, const <ProductGenre>[ProductGenre.greenTea]);
    expect(product.imageUrl, isNull);
  });

  test('未知のジャンルIDは自動補正せずValidationFailureにする', () {
    final result = ProductMapper.toDomain(
      ProductDto(
        documentId: 'coca_cola_ayataka',
        name: '綾鷹',
        manufacturerId: 'coca_cola',
        genreIds: const <String>['unknown_genre'],
        createdAt: createdAt,
        updatedAt: updatedAt,
      ),
    );

    final failure = result.failureOrNull;
    expect(failure, isA<ValidationFailure>());
    expect((failure as ValidationFailure).field, 'product.genreIds');
  });

  test('不正なドキュメントIDは例外ではなく失敗結果にする', () {
    final result = ProductMapper.toDomain(
      ProductDto(
        documentId: 'Invalid Product',
        name: '商品',
        manufacturerId: 'coca_cola',
        createdAt: createdAt,
        updatedAt: updatedAt,
      ),
    );

    expect(result.isFailure, isTrue);
    expect((result.failureOrNull as ValidationFailure).field, 'product.id');
  });

  test('欠損したFirestoreデータでもクラッシュせず失敗結果を返す', () {
    final result = ProductMapper.fromFirestoreDocument(
      documentId: 'coca_cola_ayataka',
      data: <String, dynamic>{
        'name': '綾鷹',
        'createdAt': Timestamp.fromDate(createdAt),
        'updatedAt': Timestamp.fromDate(updatedAt),
      },
    );

    expect(result.isFailure, isTrue);
    expect(
      (result.failureOrNull as ValidationFailure).field,
      'product.document',
    );
  });

  test('DomainからDTOへ戻してIDとジャンルを保持する', () {
    final domainResult = ProductMapper.toDomain(
      ProductDto(
        documentId: 'coca_cola_ayataka',
        name: '綾鷹',
        manufacturerId: 'coca_cola',
        genreIds: const <String>['green_tea'],
        createdAt: createdAt,
        updatedAt: updatedAt,
      ),
    );

    final dto = ProductMapper.toDto(domainResult.valueOrNull!);

    expect(dto.documentId, 'coca_cola_ayataka');
    expect(dto.manufacturerId, 'coca_cola');
    expect(dto.genreIds, const <String>['green_tea']);
  });
}
