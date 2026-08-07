import 'package:flutter_test/flutter_test.dart';
import 'package:vending_app/core/errors/app_failure.dart';
import 'package:vending_app/features/product_master/data/repositories/manufacturer_repository_impl.dart';
import 'package:vending_app/features/product_master/data/sources/master_document.dart';
import 'package:vending_app/features/product_master/data/sources/master_document_source.dart';
import 'package:vending_app/features/product_master/domain/value_objects/master_id.dart';

void main() {
  group('ManufacturerRepositoryImpl', () {
    test('Firestore文書をManufacturer Domainへ変換して返す', () async {
      final source = _FakeMasterDocumentSource(
        collections: <String, List<MasterDocument>>{
          MasterCollections.manufacturers: <MasterDocument>[
            _manufacturerDocument(id: 'suntory'),
          ],
        },
      );
      final repository = ManufacturerRepositoryImpl(source);

      final result = await repository.getManufacturers();

      expect(result.failureOrNull, isNull);
      expect(result.valueOrNull?.single.id.value, 'suntory');
      expect(result.valueOrNull?.single.name, 'サントリー');
    });

    test('存在しないManufacturer IDはNotFoundFailureを返す', () async {
      final repository = ManufacturerRepositoryImpl(
        _FakeMasterDocumentSource(),
      );

      final result = await repository.getManufacturer(
        ManufacturerId.parse('missing_manufacturer'),
      );

      expect(result.failureOrNull, isA<NotFoundFailure>());
    });
  });
}

MasterDocument _manufacturerDocument({required String id}) {
  return MasterDocument(
    id: id,
    data: <String, dynamic>{
      'name': 'サントリー',
      'displayShortName': 'サントリー',
      'searchKeywords': <String>['suntory'],
      'presetProductIds': <String>['suntory_boss_black'],
      'isActive': true,
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
