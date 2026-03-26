class NearbyFavoriteMatch {
  final String productId;
  final String productName;
  final String machineId;
  final String machineName;
  final String? placeNote;
  final int? price;
  final double distanceKm;
  final DateTime? lastSeenAt;
  final bool isFresh;

  const NearbyFavoriteMatch({
    required this.productId,
    required this.productName,
    required this.machineId,
    required this.machineName,
    this.placeNote,
    this.price,
    required this.distanceKm,
    this.lastSeenAt,
    this.isFresh = false,
  });

  String get priceLabel => price == null ? '価格不明' : '$price円';

  NearbyFavoriteMatch copyWith({
    String? productId,
    String? productName,
    String? machineId,
    String? machineName,
    String? placeNote,
    int? price,
    double? distanceKm,
    DateTime? lastSeenAt,
    bool? isFresh,
  }) {
    return NearbyFavoriteMatch(
      productId: productId ?? this.productId,
      productName: productName ?? this.productName,
      machineId: machineId ?? this.machineId,
      machineName: machineName ?? this.machineName,
      placeNote: placeNote ?? this.placeNote,
      price: price ?? this.price,
      distanceKm: distanceKm ?? this.distanceKm,
      lastSeenAt: lastSeenAt ?? this.lastSeenAt,
      isFresh: isFresh ?? this.isFresh,
    );
  }
}