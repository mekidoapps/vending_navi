class DrinkSlot {
  final int position; // 0〜11
  final String? drinkId;
  final String? drinkName;
  final String? brand;
  final bool isHot;
  final int? price;
  final String? imageUrl;

  const DrinkSlot({
    required this.position,
    this.drinkId,
    this.drinkName,
    this.brand,
    this.isHot = false,
    this.price,
    this.imageUrl,
  });

  bool get isEmpty => drinkId == null;

  factory DrinkSlot.empty({required int position}) {
    return DrinkSlot(
      position: position,
    );
  }

  factory DrinkSlot.fromMap(Map<String, dynamic> map) {
    return DrinkSlot(
      position: map['position'] ?? 0,
      drinkId: map['drinkId'],
      drinkName: map['drinkName'],
      brand: map['brand'],
      isHot: map['isHot'] ?? false,
      price: map['price'],
      imageUrl: map['imageUrl'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'position': position,
      'drinkId': drinkId,
      'drinkName': drinkName,
      'brand': brand,
      'isHot': isHot,
      'price': price,
      'imageUrl': imageUrl,
    };
  }

  DrinkSlot copyWith({
    int? position,
    String? drinkId,
    String? drinkName,
    String? brand,
    bool? isHot,
    int? price,
    String? imageUrl,
  }) {
    return DrinkSlot(
      position: position ?? this.position,
      drinkId: drinkId ?? this.drinkId,
      drinkName: drinkName ?? this.drinkName,
      brand: brand ?? this.brand,
      isHot: isHot ?? this.isHot,
      price: price ?? this.price,
      imageUrl: imageUrl ?? this.imageUrl,
    );
  }
}