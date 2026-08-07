import '../../../../core/result/app_result.dart';
import '../entities/product.dart';
import '../value_objects/master_id.dart';

abstract interface class ProductRepository {
  Future<AppResult<List<Product>>> getProducts({bool activeOnly = true});

  Future<AppResult<Product>> getProduct(ProductId id);
}
