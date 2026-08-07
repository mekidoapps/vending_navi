import '../../../product_master/domain/entities/product.dart';

enum ProductSearchMatchKind {
  productIdExact,
  nameExact,
  keywordExact,
  namePrefix,
  keywordPrefix,
  nameContains,
  keywordContains,
}

final class ProductSearchCandidate {
  const ProductSearchCandidate({
    required this.product,
    required this.matchKind,
    required this.score,
  });

  final Product product;
  final ProductSearchMatchKind matchKind;
  final int score;
}
