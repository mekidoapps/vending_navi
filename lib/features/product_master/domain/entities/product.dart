import 'package:freezed_annotation/freezed_annotation.dart';

import '../value_objects/master_id.dart';
import 'product_genre.dart';

part 'product.freezed.dart';

@freezed
abstract class Product with _$Product {
  const Product._();

  const factory Product({
    required ProductId id,
    required String name,
    required ManufacturerId manufacturerId,
    @Default(<String>[]) List<String> searchKeywords,
    @Default(<ProductGenre>[]) List<ProductGenre> genres,
    String? imageUrl,
    @Default(true) bool isActive,
    required DateTime createdAt,
    required DateTime updatedAt,
  }) = _Product;

  bool get isSelectable => isActive && name.trim().isNotEmpty;

  Set<String> get searchTerms {
    return <String>{
      name.trim(),
      for (final keyword in searchKeywords)
        if (keyword.trim().isNotEmpty) keyword.trim(),
    };
  }
}
