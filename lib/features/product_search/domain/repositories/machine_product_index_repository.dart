import '../../../../core/result/app_result.dart';
import '../../../home_map/domain/value_objects/map_viewport_bounds.dart';
import '../../../product_master/domain/value_objects/master_id.dart';
import '../entities/machine_product_index_entry.dart';

abstract interface class MachineProductIndexRepository {
  Future<AppResult<List<MachineProductIndexEntry>>> findByProductInViewport({
    required ProductId productId,
    required MapViewportBounds viewport,
  });
}
