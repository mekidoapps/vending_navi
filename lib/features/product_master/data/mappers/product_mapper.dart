import '../../../../core/errors/app_failure.dart';
import '../../../../core/result/app_result.dart';
import '../../domain/entities/product.dart';
import '../../domain/entities/product_genre.dart';
import '../../domain/value_objects/master_id.dart';
import '../dtos/product_dto.dart';
import 'master_mapper_utils.dart';

abstract final class ProductMapper {
  static AppResult<Product> fromFirestoreDocument({
    required String documentId,
    required Map<String, dynamic> data,
  }) {
    try {
      final dto = ProductDto.fromFirestoreDocument(
        documentId: documentId,
        data: data,
      );
      return toDomain(dto);
    } on Object {
      return _invalid('product.document');
    }
  }

  static AppResult<Product> toDomain(ProductDto dto) {
    final id = ProductId.tryParse(dto.documentId);
    if (id == null) {
      return _invalid('product.id');
    }

    final manufacturerId = ManufacturerId.tryParse(dto.manufacturerId.trim());
    if (manufacturerId == null) {
      return _invalid('product.manufacturerId');
    }

    final name = dto.name.trim();
    if (name.isEmpty) {
      return _invalid('product.name');
    }

    final genres = <ProductGenre>[];
    final seenGenres = <ProductGenre>{};
    for (final rawGenreId in dto.genreIds) {
      final genre = ProductGenre.tryFromId(rawGenreId.trim());
      if (genre == null) {
        return _invalid('product.genreIds');
      }
      if (seenGenres.add(genre)) {
        genres.add(genre);
      }
    }

    return AppResult<Product>.success(
      Product(
        id: id,
        name: name,
        manufacturerId: manufacturerId,
        searchKeywords: normalizeMasterStrings(dto.searchKeywords),
        genres: List<ProductGenre>.unmodifiable(genres),
        imageUrl: normalizeOptionalMasterString(dto.imageUrl),
        isActive: dto.isActive,
        createdAt: dto.createdAt.toUtc(),
        updatedAt: dto.updatedAt.toUtc(),
      ),
    );
  }

  static ProductDto toDto(Product product) {
    return ProductDto(
      documentId: product.id.value,
      name: product.name,
      manufacturerId: product.manufacturerId.value,
      searchKeywords: product.searchKeywords,
      genreIds: product.genres.map((genre) => genre.id).toList(growable: false),
      imageUrl: product.imageUrl,
      isActive: product.isActive,
      createdAt: product.createdAt.toUtc(),
      updatedAt: product.updatedAt.toUtc(),
    );
  }

  static AppResult<Product> _invalid(String field) {
    return AppResult<Product>.failure(ValidationFailure(field: field));
  }
}
