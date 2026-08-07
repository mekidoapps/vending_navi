import '../../../../core/errors/app_failure.dart';
import '../../../../core/errors/failure_mapper.dart';
import '../../../../core/result/app_result.dart';
import '../../domain/entities/product.dart';
import '../../domain/repositories/product_repository.dart';
import '../../domain/value_objects/master_id.dart';
import '../mappers/product_mapper.dart';
import '../sources/master_document.dart';
import '../sources/master_document_source.dart';

final class ProductRepositoryImpl implements ProductRepository {
  ProductRepositoryImpl(this._source);

  final MasterDocumentSource _source;

  @override
  Future<AppResult<List<Product>>> getProducts({bool activeOnly = true}) async {
    try {
      final documents = await _source.fetchCollection(
        MasterCollections.products,
      );
      final products = <Product>[];

      for (final document in documents) {
        final mapped = _mapDocument(document);
        final failure = mapped.failureOrNull;
        if (failure != null) {
          return AppResult<List<Product>>.failure(failure);
        }

        final product = mapped.valueOrNull;
        if (product == null) {
          return const AppResult<List<Product>>.failure(UnknownFailure());
        }

        if (!activeOnly || product.isActive) {
          products.add(product);
        }
      }

      products.sort((left, right) => left.name.compareTo(right.name));

      return AppResult<List<Product>>.success(
        List<Product>.unmodifiable(products),
      );
    } on Object catch (error) {
      return AppResult<List<Product>>.failure(FailureMapper.map(error));
    }
  }

  @override
  Future<AppResult<Product>> getProduct(ProductId id) async {
    try {
      final document = await _source.fetchDocument(
        MasterCollections.products,
        id.value,
      );

      if (document == null) {
        return const AppResult<Product>.failure(NotFoundFailure());
      }

      return _mapDocument(document);
    } on Object catch (error) {
      return AppResult<Product>.failure(FailureMapper.map(error));
    }
  }

  AppResult<Product> _mapDocument(MasterDocument document) {
    return ProductMapper.fromFirestoreDocument(
      documentId: document.id,
      data: document.data,
    );
  }
}
