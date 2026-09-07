import '../../product_master/domain/entities/product.dart';
import '../../product_master/domain/entities/product_genre.dart';
import '../../product_search/application/genre_machine_search_state.dart';
import '../../product_search/application/genre_search_map_filter.dart';
import '../../product_search/application/product_machine_search_state.dart';
import '../../product_search/application/product_search_map_filter.dart';
import '../../vending_machine/domain/entities/vending_machine.dart';

/// Produces the same machine candidates for map content and marker creation.
/// Photo IDs deliberately do not participate in this map-level contract.
abstract final class VendingMachineMapBlockFilter {
  static List<VendingMachine> visibleMachines({
    required List<VendingMachine> machines,
    required Product? selectedProduct,
    required ProductGenre? selectedGenre,
    required ProductMachineSearchState productSearchState,
    required GenreMachineSearchState genreSearchState,
    Set<String> blockedMachineIds = const <String>{},
    Set<String> blockedProductIds = const <String>{},
  }) {
    final searchCandidates = _searchCandidates(
      machines: machines,
      selectedProduct: selectedProduct,
      selectedGenre: selectedGenre,
      productSearchState: productSearchState,
      genreSearchState: genreSearchState,
      blockedProductIds: blockedProductIds,
    );

    return List<VendingMachine>.unmodifiable(
      searchCandidates.where(
        (machine) => !blockedMachineIds.contains(machine.id.value),
      ),
    );
  }

  static List<VendingMachine> _searchCandidates({
    required List<VendingMachine> machines,
    required Product? selectedProduct,
    required ProductGenre? selectedGenre,
    required ProductMachineSearchState productSearchState,
    required GenreMachineSearchState genreSearchState,
    required Set<String> blockedProductIds,
  }) {
    if (selectedProduct != null) {
      if (blockedProductIds.contains(selectedProduct.id.value)) {
        return const <VendingMachine>[];
      }
      return ProductSearchMapFilter.visibleMachines(
        machines: machines,
        selectedProduct: selectedProduct,
        searchState: productSearchState,
      );
    }

    if (selectedGenre != null) {
      final allowedMachineIds = genreSearchState.entries
          .where((entry) => !blockedProductIds.contains(entry.productId.value))
          .map((entry) => entry.machineId)
          .toSet();
      return GenreSearchMapFilter.visibleMachines(
        machines: machines,
        selectedGenre: selectedGenre,
        searchState: genreSearchState,
      ).where((machine) => allowedMachineIds.contains(machine.id)).toList();
    }

    return List<VendingMachine>.unmodifiable(machines);
  }
}
