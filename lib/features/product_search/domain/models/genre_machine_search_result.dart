import '../../../product_master/domain/value_objects/master_id.dart';
import '../entities/machine_product_index_entry.dart';

final class GenreMachineSearchResult {
  const GenreMachineSearchResult({
    required this.productIds,
    required this.entries,
  });

  final Set<ProductId> productIds;
  final List<MachineProductIndexEntry> entries;
}
