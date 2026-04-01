class DrinkItem {
  const DrinkItem({
    required this.id,
    required this.name,
    required this.brand,
    required this.category,
    this.imageUrl,
    this.searchKeywords = const <String>[],
    this.isHotCompatible = false,
    this.isColdCompatible = true,
  });

  final String id;
  final String name;
  final String brand;
  final String category;
  final String? imageUrl;
  final List<String> searchKeywords;
  final bool isHotCompatible;
  final bool isColdCompatible;

  bool matches(String query) {
    final normalized = query.trim().toLowerCase();
    if (normalized.isEmpty) return true;

    if (name.toLowerCase().contains(normalized)) return true;
    if (brand.toLowerCase().contains(normalized)) return true;
    if (category.toLowerCase().contains(normalized)) return true;

    for (final keyword in searchKeywords) {
      if (keyword.toLowerCase().contains(normalized)) {
        return true;
      }
    }
    return false;
  }

  factory DrinkItem.fromMap(
      Map<String, dynamic> map, {
        String? documentId,
      }) {
    return DrinkItem(
      id: (map['id'] as String?)?.trim().isNotEmpty == true
          ? map['id'] as String
          : (documentId ?? ''),
      name: (map['name'] as String?) ?? '',
      brand: (map['brand'] as String?) ?? '',
      category: (map['category'] as String?) ?? '',
      imageUrl: map['imageUrl'] as String?,
      searchKeywords: ((map['searchKeywords'] as List<dynamic>?) ?? const [])
          .map((e) => e.toString())
          .toList(),
      isHotCompatible: (map['isHotCompatible'] as bool?) ?? false,
      isColdCompatible: (map['isColdCompatible'] as bool?) ?? true,
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
      'isColdCompatible': isColdCompatible,
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
    bool? isColdCompatible,
  }) {
    return DrinkItem(
      id: id ?? this.id,
      name: name ?? this.name,
      brand: brand ?? this.brand,
      category: category ?? this.category,
      imageUrl: imageUrl ?? this.imageUrl,
      searchKeywords: searchKeywords ?? this.searchKeywords,
      isHotCompatible: isHotCompatible ?? this.isHotCompatible,
      isColdCompatible: isColdCompatible ?? this.isColdCompatible,
    );
  }
}