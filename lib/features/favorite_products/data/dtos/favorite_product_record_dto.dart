final class FavoriteProductRecordDto {
  const FavoriteProductRecordDto({
    required this.productId,
    required this.sortOrder,
  });

  factory FavoriteProductRecordDto.fromFirestore({
    required String documentId,
    required Map<String, dynamic> data,
  }) {
    final productId = data['productId'];
    final sortOrder = data['sortOrder'];

    if (productId is! String || productId.trim().isEmpty) {
      throw const FormatException('favorite productId is required');
    }
    if (productId != documentId) {
      throw const FormatException('favorite productId must match document id');
    }
    if (sortOrder is! int || sortOrder < 0) {
      throw const FormatException(
        'favorite sortOrder must be a non-negative int',
      );
    }

    return FavoriteProductRecordDto(productId: productId, sortOrder: sortOrder);
  }

  final String productId;
  final int sortOrder;
}
