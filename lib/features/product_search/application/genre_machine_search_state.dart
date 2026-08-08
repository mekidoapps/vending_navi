import '../../../core/errors/app_failure.dart';
import '../../home_map/domain/value_objects/map_viewport_bounds.dart';
import '../../product_master/domain/entities/product_genre.dart';
import '../../product_master/domain/value_objects/master_id.dart';
import '../../vending_machine/domain/value_objects/vending_machine_id.dart';
import '../domain/entities/machine_product_index_entry.dart';

final class GenreMachineSearchState {
  const GenreMachineSearchState({
    this.genre,
    this.viewport,
    this.productIds = const <ProductId>{},
    this.entries = const <MachineProductIndexEntry>[],
    this.failure,
    this.isLoading = false,
    this.hasSearched = false,
  });

  final ProductGenre? genre;
  final MapViewportBounds? viewport;
  final Set<ProductId> productIds;
  final List<MachineProductIndexEntry> entries;
  final AppFailure? failure;
  final bool isLoading;
  final bool hasSearched;

  bool get isEmptyResult =>
      genre != null &&
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
    required ProductGenre genre,
    required MapViewportBounds viewport,
  }) {
    final currentGenre = this.genre;
    final currentViewport = this.viewport;

    return currentGenre == genre &&
        currentViewport != null &&
        currentViewport.roughlyEquals(viewport);
  }

  GenreMachineSearchState copyWith({
    ProductGenre? genre,
    MapViewportBounds? viewport,
    Set<ProductId>? productIds,
    List<MachineProductIndexEntry>? entries,
    AppFailure? failure,
    bool clearFailure = false,
    bool? isLoading,
    bool? hasSearched,
  }) {
    return GenreMachineSearchState(
      genre: genre ?? this.genre,
      viewport: viewport ?? this.viewport,
      productIds: productIds ?? this.productIds,
      entries: entries ?? this.entries,
      failure: clearFailure ? null : failure ?? this.failure,
      isLoading: isLoading ?? this.isLoading,
      hasSearched: hasSearched ?? this.hasSearched,
    );
  }
}
