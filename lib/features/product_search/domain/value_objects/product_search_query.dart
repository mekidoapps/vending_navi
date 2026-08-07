final class ProductSearchQuery {
  ProductSearchQuery(String rawText)
    : rawText = rawText,
      trimmedText = rawText.trim(),
      normalizedText = ProductSearchNormalizer.normalize(rawText);

  final String rawText;
  final String trimmedText;
  final String normalizedText;

  bool get isEmpty => normalizedText.isEmpty;

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is ProductSearchQuery &&
            other.trimmedText == trimmedText &&
            other.normalizedText == normalizedText;
  }

  @override
  int get hashCode => Object.hash(trimmedText, normalizedText);

  @override
  String toString() => 'ProductSearchQuery(length: ${trimmedText.length})';
}

abstract final class ProductSearchNormalizer {
  static final RegExp _separatorPattern = RegExp(
    r'''[\s\u3000・･._\-‐‑‒–—―~〜～'"“”]+''',
  );

  static String normalize(String value) {
    return value.trim().toLowerCase().replaceAll(_separatorPattern, '');
  }
}
