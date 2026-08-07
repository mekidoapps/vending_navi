import '../../../../core/result/app_result.dart';
import '../../../product_master/domain/entities/product.dart';
import '../../../product_master/domain/repositories/product_repository.dart';
import '../models/product_search_candidate.dart';
import '../value_objects/product_search_query.dart';

final class ProductCandidateSearchService {
  const ProductCandidateSearchService({
    required ProductRepository productRepository,
  }) : _productRepository = productRepository;

  final ProductRepository _productRepository;

  Future<AppResult<List<ProductSearchCandidate>>> search(
    ProductSearchQuery query,
  ) async {
    if (query.isEmpty) {
      return const AppResult<List<ProductSearchCandidate>>.success(
        <ProductSearchCandidate>[],
      );
    }

    final productsResult = await _productRepository.getProducts();
    final failure = productsResult.failureOrNull;
    if (failure != null) {
      return AppResult<List<ProductSearchCandidate>>.failure(failure);
    }

    final products = productsResult.valueOrNull ?? const <Product>[];
    final candidates = <ProductSearchCandidate>[];

    for (final product in products) {
      if (!product.isSelectable) {
        continue;
      }

      final match = _matchProduct(product, query);
      if (match != null) {
        candidates.add(match);
      }
    }

    candidates.sort(_compareCandidates);

    return AppResult<List<ProductSearchCandidate>>.success(
      List<ProductSearchCandidate>.unmodifiable(candidates),
    );
  }

  static ProductSearchCandidate? _matchProduct(
    Product product,
    ProductSearchQuery query,
  ) {
    final idText = product.id.value.toLowerCase();
    if (query.trimmedText.toLowerCase() == idText) {
      return ProductSearchCandidate(
        product: product,
        matchKind: ProductSearchMatchKind.productIdExact,
        score: 1000,
      );
    }

    final normalizedName = ProductSearchNormalizer.normalize(product.name);
    if (normalizedName == query.normalizedText) {
      return ProductSearchCandidate(
        product: product,
        matchKind: ProductSearchMatchKind.nameExact,
        score: 900,
      );
    }

    final normalizedKeywords = <String>[
      for (final keyword in product.searchKeywords)
        ProductSearchNormalizer.normalize(keyword),
    ];

    if (normalizedKeywords.contains(query.normalizedText)) {
      return ProductSearchCandidate(
        product: product,
        matchKind: ProductSearchMatchKind.keywordExact,
        score: 850,
      );
    }

    if (normalizedName.startsWith(query.normalizedText)) {
      return ProductSearchCandidate(
        product: product,
        matchKind: ProductSearchMatchKind.namePrefix,
        score: 700,
      );
    }

    if (normalizedKeywords.any(
      (keyword) => keyword.startsWith(query.normalizedText),
    )) {
      return ProductSearchCandidate(
        product: product,
        matchKind: ProductSearchMatchKind.keywordPrefix,
        score: 650,
      );
    }

    if (normalizedName.contains(query.normalizedText)) {
      return ProductSearchCandidate(
        product: product,
        matchKind: ProductSearchMatchKind.nameContains,
        score: 500,
      );
    }

    if (normalizedKeywords.any(
      (keyword) => keyword.contains(query.normalizedText),
    )) {
      return ProductSearchCandidate(
        product: product,
        matchKind: ProductSearchMatchKind.keywordContains,
        score: 450,
      );
    }

    return null;
  }

  static int _compareCandidates(
    ProductSearchCandidate left,
    ProductSearchCandidate right,
  ) {
    final scoreOrder = right.score.compareTo(left.score);
    if (scoreOrder != 0) {
      return scoreOrder;
    }

    final nameOrder = left.product.name.compareTo(right.product.name);
    if (nameOrder != 0) {
      return nameOrder;
    }

    return left.product.id.value.compareTo(right.product.id.value);
  }
}
