class DrinkItem {
  final String id;
  final String name;
  final String brand;
  final String category;
  final String imageUrl;
  final List<String> searchKeywords;
  final bool isHotCompatible;

  const DrinkItem({
    required this.id,
    required this.name,
    required this.brand,
    required this.category,
    this.imageUrl = '',
    this.searchKeywords = const <String>[],
    this.isHotCompatible = false,
  });

  factory DrinkItem.fromMap(
      Map<String, dynamic> data, {
        String? documentId,
      }) {
    return DrinkItem(
      id: (documentId ?? data['id'] ?? '').toString(),
      name: (data['name'] ?? '名称未設定').toString(),
      brand: (data['brand'] ?? '').toString(),
      category: (data['category'] ?? '').toString(),
      imageUrl: (data['imageUrl'] ?? '').toString(),
      searchKeywords: (data['searchKeywords'] as List?)
          ?.map((e) => e.toString())
          .toList() ??
          const <String>[],
      isHotCompatible: data['isHotCompatible'] == true,
    );
  }

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'id': id,
      'name': name,
      'brand': brand,
      'category': category,
      'imageUrl': imageUrl,
      'searchKeywords': searchKeywords,
      'isHotCompatible': isHotCompatible,
    };
  }

  DrinkItem copyWith({
    String? id,
    String? name,
    String? brand,
    String? category,
    String? imageUrl,
    List<String>? searchKeywords,
    bool? isHotCompatible,
  }) {
    return DrinkItem(
      id: id ?? this.id,
      name: name ?? this.name,
      brand: brand ?? this.brand,
      category: category ?? this.category,
      imageUrl: imageUrl ?? this.imageUrl,
      searchKeywords: searchKeywords ?? this.searchKeywords,
      isHotCompatible: isHotCompatible ?? this.isHotCompatible,
    );
  }

  bool matches(String query) {
    final normalized = query.trim().toLowerCase();
    if (normalized.isEmpty) return true;

    return name.toLowerCase().contains(normalized) ||
        brand.toLowerCase().contains(normalized) ||
        category.toLowerCase().contains(normalized) ||
        searchKeywords.any((k) => k.toLowerCase().contains(normalized));
  }
}