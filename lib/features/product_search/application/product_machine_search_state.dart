import '../../../core/errors/app_failure.dart';
import '../../home_map/domain/value_objects/map_viewport_bounds.dart';
import '../../product_master/domain/value_objects/master_id.dart';
import '../../vending_machine/domain/value_objects/vending_machine_id.dart';
import '../domain/entities/machine_product_index_entry.dart';

final class ProductMachineSearchState {
  const ProductMachineSearchState({
    this.productId,
    this.viewport,
    this.entries = const <MachineProductIndexEntry>[],
    this.failure,
    this.isLoading = false,
    this.hasSearched = false,
  });

  final ProductId? productId;
  final MapViewportBounds? viewport;
  final List<MachineProductIndexEntry> entries;
  final AppFailure? failure;
  final bool isLoading;
  final bool hasSearched;

  bool get isEmptyResult =>
      productId != null &&
      hasSearched &&
      !isLoading &&
      failure == null &&
      entries.isEmpty;

  Set<VendingMachineId> get indexedMachineIds =>
      Set<VendingMachineId>.unmodifiable(
        entries.map((entry) => entry.machineId),
      );

  MachineProductIndexEntry? entryForMachine(VendingMachineId machineId) {
    for (final entry in entries) {
      if (entry.machineId == machineId) {
        return entry;
      }
    }
    return null;
  }

  bool represents({
    required ProductId productId,
    required MapViewportBounds viewport,
  }) {
    final currentProductId = this.productId;
    final currentViewport = this.viewport;

    return currentProductId == productId &&
        currentViewport != null &&
        currentViewport.roughlyEquals(viewport);
  }

  ProductMachineSearchState copyWith({
    ProductId? productId,
    bool clearProductId = false,
    MapViewportBounds? viewport,
    bool clearViewport = false,
    List<MachineProductIndexEntry>? entries,
    AppFailure? failure,
    bool clearFailure = false,
    bool? isLoading,
    bool? hasSearched,
  }) {
    return ProductMachineSearchState(
      productId: clearProductId ? null : productId ?? this.productId,
      viewport: clearViewport ? null : viewport ?? this.viewport,
      entries: entries ?? this.entries,
      failure: clearFailure ? null : failure ?? this.failure,
      isLoading: isLoading ?? this.isLoading,
      hasSearched: hasSearched ?? this.hasSearched,
    );
  }
}
