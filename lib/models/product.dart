import '../core/enums/app_enums.dart';
import '../core/utils/search_normalizer.dart';

class Product {
  final String id;
  final String displayName;
  final String normalizedName;
  final String brandName;
  final String makerName;
  final ProductCategory category;
  final String? subcategory;
  final List<String> searchAliases;
  final List<String> defaultTags;
  final ProductStatus status;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const Product({
    required this.id,
    required this.displayName,
    required this.normalizedName,
    required this.brandName,
    required this.makerName,
    required this.category,
    this.subcategory,
    this.searchAliases = const <String>[],
    this.defaultTags = const <String>[],
    this.status = ProductStatus.active,
    this.createdAt,
    this.updatedAt,
  });

  bool matchesKeyword(String keyword) {
    if (keyword.trim().isEmpty) return true;

    if (SearchNormalizer.containsNormalized(
      source: displayName,
      query: keyword,
    )) {
      return true;
    }

    if (SearchNormalizer.containsNormalized(
      source: brandName,
      query: keyword,
    )) {
      return true;
    }

    for (final String alias in searchAliases) {
      if (SearchNormalizer.containsNormalized(
        source: alias,
        query: keyword,
      )) {
        return true;
      }
    }

    return false;
  }

  Product copyWith({
    String? id,
    String? displayName,
    String? normalizedName,
    String? brandName,
    String? makerName,
    ProductCategory? category,
    String? subcategory,
    List<String>? searchAliases,
    List<String>? defaultTags,
    ProductStatus? status,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Product(
      id: id ?? this.id,
      displayName: displayName ?? this.displayName,
      normalizedName: normalizedName ?? this.normalizedName,
      brandName: brandName ?? this.brandName,
      makerName: makerName ?? this.makerName,
      category: category ?? this.category,
      subcategory: subcategory ?? this.subcategory,
      searchAliases: searchAliases ?? this.searchAliases,
      defaultTags: defaultTags ?? this.defaultTags,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'display_name': displayName,
      'normalized_name': normalizedName,
      'brand_name': brandName,
      'maker_name': makerName,
      'category': _categoryToFirestore(category),
      'subcategory': subcategory,
      'search_aliases': searchAliases,
      'default_tags': defaultTags,
      'status': _statusToFirestore(status),
      'created_at': createdAt,
      'updated_at': updatedAt,
    };
  }

  factory Product.fromMap(String id, Map<String, dynamic> map) {
    return Product(
      id: id,
      displayName: (map['display_name'] ?? '') as String,
      normalizedName: (map['normalized_name'] ?? '') as String,
      brandName: (map['brand_name'] ?? '') as String,
      makerName: (map['maker_name'] ?? '') as String,
      category: _categoryFromFirestore((map['category'] ?? 'other') as String),
      subcategory: map['subcategory'] as String?,
      searchAliases: List<String>.from(map['search_aliases'] ?? const <String>[]),
      defaultTags: List<String>.from(map['default_tags'] ?? const <String>[]),
      status: _statusFromFirestore((map['status'] ?? 'active') as String),
      createdAt: _toDateTime(map['created_at']),
      updatedAt: _toDateTime(map['updated_at']),
    );
  }

  static ProductCategory _categoryFromFirestore(String value) {
    switch (value) {
      case 'tea':
        return ProductCategory.tea;
      case 'water':
        return ProductCategory.water;
      case 'coffee':
        return ProductCategory.coffee;
      case 'black_tea':
        return ProductCategory.blackTea;
      case 'soda':
        return ProductCategory.soda;
      case 'juice':
        return ProductCategory.juice;
      case 'sports_drink':
        return ProductCategory.sportsDrink;
      case 'energy_drink':
        return ProductCategory.energyDrink;
      case 'milk_beverage':
        return ProductCategory.milkBeverage;
      case 'soup':
        return ProductCategory.soup;
      default:
        return ProductCategory.other;
    }
  }

  static String _categoryToFirestore(ProductCategory value) {
    switch (value) {
      case ProductCategory.tea:
        return 'tea';
      case ProductCategory.water:
        return 'water';
      case ProductCategory.coffee:
        return 'coffee';
      case ProductCategory.blackTea:
        return 'black_tea';
      case ProductCategory.soda:
        return 'soda';
      case ProductCategory.juice:
        return 'juice';
      case ProductCategory.sportsDrink:
        return 'sports_drink';
      case ProductCategory.energyDrink:
        return 'energy_drink';
      case ProductCategory.milkBeverage:
        return 'milk_beverage';
      case ProductCategory.soup:
        return 'soup';
      case ProductCategory.other:
        return 'other';
    }
  }

  static ProductStatus _statusFromFirestore(String value) {
    switch (value) {
      case 'tentative':
        return ProductStatus.tentative;
      case 'archived':
        return ProductStatus.archived;
      default:
        return ProductStatus.active;
    }
  }

  static String _statusToFirestore(ProductStatus value) {
    switch (value) {
      case ProductStatus.active:
        return 'active';
      case ProductStatus.tentative:
        return 'tentative';
      case ProductStatus.archived:
        return 'archived';
    }
  }

  static DateTime? _toDateTime(dynamic value) {
    if (value == null) return null;
    if (value is DateTime) return value;
    if (value is String) return DateTime.tryParse(value);
    try {
      return value.toDate() as DateTime;
    } catch (_) {
      return null;
    }
  }
}