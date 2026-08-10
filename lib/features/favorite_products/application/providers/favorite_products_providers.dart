import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/firebase/firebase_providers.dart';
import '../../../product_master/application/providers/product_master_providers.dart';
import '../../data/repositories/favorite_products_repository_impl.dart';
import '../../data/sources/favorite_products_data_source.dart';
import '../../data/sources/firestore_favorite_products_data_source.dart';
import '../../domain/repositories/favorite_products_repository.dart';
import '../../domain/services/favorite_products_service.dart';

final favoriteProductsDataSourceProvider = Provider<FavoriteProductsDataSource>(
  (ref) => FirestoreFavoriteProductsDataSource(ref.watch(firestoreProvider)),
  name: 'favoriteProductsDataSourceProvider',
);

final favoriteProductsRepositoryProvider = Provider<FavoriteProductsRepository>(
  (ref) => FavoriteProductsRepositoryImpl(
    ref.watch(favoriteProductsDataSourceProvider),
  ),
  name: 'favoriteProductsRepositoryProvider',
);

final favoriteProductsServiceProvider = Provider<FavoriteProductsService>(
  (ref) => FavoriteProductsService(
    favoriteProductsRepository: ref.watch(favoriteProductsRepositoryProvider),
    productRepository: ref.watch(productRepositoryProvider),
  ),
  name: 'favoriteProductsServiceProvider',
);
