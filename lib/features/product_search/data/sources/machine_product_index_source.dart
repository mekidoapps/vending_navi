import '../../../product_master/domain/value_objects/master_id.dart';
import 'machine_product_index_document.dart';

abstract interface class MachineProductIndexSource {
  Future<List<MachineProductIndexDocument>> fetchByProductAndGeohashPrefixes({
    required ProductId productId,
    required Set<String> geohashPrefixes,
  });
}
