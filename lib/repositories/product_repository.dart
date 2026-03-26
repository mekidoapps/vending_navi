import 'package:cloud_firestore/cloud_firestore.dart';

import '../core/enums/app_enums.dart';
import '../models/product.dart';
import '../services/firestore_service.dart';

class ProductRepository {
  ProductRepository({
    FirestoreService? firestoreService,
  }) : _firestoreService = firestoreService ?? FirestoreService();

  final FirestoreService _firestoreService;

  Future<List<Product>> fetchProducts({
    String? keyword,
    ProductCategory? category,
    ProductStatus status = ProductStatus.active,
    int limit = 50,
  }) async {
    Query<Map<String, dynamic>> query =
    _firestoreService.productMaster().limit(limit);

    query = query.where(
      'status',
      isEqualTo: _statusToFirestore(status),
    );

    if (category != null) {
      query = query.where(
        'category',
        isEqualTo: _categoryToFirestore(category),
      );
    }

    final QuerySnapshot<Map<String, dynamic>> snapshot = await query.get();

    List<Product> items = snapshot.docs
        .map((QueryDocumentSnapshot<Map<String, dynamic>> doc) {
      return Product.fromMap(doc.id, doc.data());
    }).toList();

    if (keyword != null && keyword.trim().isNotEmpty) {
      items = items.where((Product product) {
        return product.matchesKeyword(keyword);
      }).toList();
    }

    items.sort((Product a, Product b) => a.displayName.compareTo(b.displayName));
    return items;
  }

  Future<Product?> fetchProductById(String productId) async {
    final DocumentSnapshot<Map<String, dynamic>> doc =
    await _firestoreService.productMaster().doc(productId).get();

    if (!doc.exists || doc.data() == null) {
      return null;
    }

    return Product.fromMap(doc.id, doc.data()!);
  }

  Future<List<Product>> searchSuggestions({
    required String keyword,
    int limit = 10,
  }) async {
    if (keyword.trim().isEmpty) {
      return fetchProducts(limit: limit);
    }

    final List<Product> products = await fetchProducts(limit: 100);

    final List<Product> filtered = products.where((Product product) {
      return product.matchesKeyword(keyword);
    }).toList();

    filtered.sort((Product a, Product b) {
      final bool aStarts =
      a.displayName.toLowerCase().startsWith(keyword.toLowerCase());
      final bool bStarts =
      b.displayName.toLowerCase().startsWith(keyword.toLowerCase());

      if (aStarts && !bStarts) return -1;
      if (!aStarts && bStarts) return 1;
      return a.displayName.compareTo(b.displayName);
    });

    return filtered.take(limit).toList();
  }

  Future<void> saveProduct(Product product) {
    return _firestoreService.productMaster().doc(product.id).set(
      product.toMap(),
      SetOptions(merge: true),
    );
  }

  String _categoryToFirestore(ProductCategory category) {
    switch (category) {
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

  String _statusToFirestore(ProductStatus status) {
    switch (status) {
      case ProductStatus.active:
        return 'active';
      case ProductStatus.tentative:
        return 'tentative';
      case ProductStatus.archived:
        return 'archived';
    }
  }
}