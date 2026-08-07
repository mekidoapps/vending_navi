import 'package:flutter_test/flutter_test.dart';
import 'package:vending_app/core/errors/app_failure.dart';
import 'package:vending_app/features/product_master/data/repositories/product_repository_impl.dart';
import 'package:vending_app/features/product_master/data/sources/master_document.dart';
import 'package:vending_app/features/product_master/data/sources/master_document_source.dart';
import 'package:vending_app/features/product_master/domain/value_objects/master_id.dart';

void main() {
  group('ProductRepositoryImpl', () {
    test('activeOnly=trueでは有効商品のみ返す', () async {
      final source = _FakeMasterDocumentSource(
        collections: <String, List<MasterDocument>>{
          MasterCollections.products: <MasterDocument>[
            _productDocument(id: 'suntory_boss_black', isActive: true),
            _productDocument(id: 'suntory_old_product', isActive: false),
          ],
        },
      );
      final repository = ProductRepositoryImpl(source);

      final result = await repository.getProducts();

      expect(result.failureOrNull, isNull);
      expect(result.valueOrNull?.map((product) => product.id.value), <String>[
        'suntory_boss_black',
      ]);
    });

    test('不正なFirestore文書が混ざる場合はValidationFailureを返す', () async {
      final source = _FakeMasterDocumentSource(
        collections: <String, List<MasterDocument>>{
          MasterCollections.products: <MasterDocument>[
            const MasterDocument(id: 'invalid__id', data: <String, dynamic>{}),
          ],
        },
      );
      final repository = ProductRepositoryImpl(source);

      final result = await repository.getProducts();

      expect(result.failureOrNull, isA<ValidationFailure>());
    });

    test('存在しないProduct IDはNotFoundFailureを返す', () async {
      final repository = ProductRepositoryImpl(_FakeMasterDocumentSource());

      final result = await repository.getProduct(
        ProductId.parse('suntory_missing'),
      );

      expect(result.failureOrNull, isA<NotFoundFailure>());
    });
  });
}

MasterDocument _productDocument({required String id, required bool isActive}) {
  return MasterDocument(
    id: id,
    data: <String, dynamic>{
      'name': id == 'suntory_boss_black' ? 'BOSS ブラック' : '旧商品',
      'manufacturerId': 'suntory',
      'searchKeywords': <String>[],
      'genreIds': <String>['coffee'],
      'isActive': isActive,
      'createdAt': DateTime.utc(2026, 8, 7),
      'updatedAt': DateTime.utc(2026, 8, 7),
    },
  );
}

final class _FakeMasterDocumentSource implements MasterDocumentSource {
  _FakeMasterDocumentSource({
    this.collections = const <String, List<MasterDocument>>{},
  });

  final Map<String, List<MasterDocument>> collections;

  @override
  Future<List<MasterDocument>> fetchCollection(String collectionPath) async {
    return collections[collectionPath] ?? const <MasterDocument>[];
  }

  @override
  Future<MasterDocument?> fetchDocument(
    String collectionPath,
    String documentId,
  ) async {
    for (final document
        in collections[collectionPath] ?? const <MasterDocument>[]) {
      if (document.id == documentId) {
        return document;
      }
    }
    return null;
  }
}
