import '../../product_master/domain/entities/product_genre.dart';
import '../../vending_machine/domain/entities/vending_machine.dart';
import '../../vending_machine/domain/entities/vending_machine_enums.dart';
import '../../vending_machine/domain/value_objects/vending_machine_id.dart';
import 'genre_machine_search_state.dart';

abstract final class GenreSearchMapFilter {
  static List<VendingMachine> visibleMachines({
    required List<VendingMachine> machines,
    required ProductGenre? selectedGenre,
    required GenreMachineSearchState searchState,
  }) {
    if (selectedGenre == null) {
      return List<VendingMachine>.unmodifiable(machines);
    }

    if (searchState.genre != selectedGenre ||
        searchState.isLoading ||
        searchState.failure != null ||
        !searchState.hasSearched) {
      return const <VendingMachine>[];
    }

    final indexedIds = searchState.indexedMachineIds;

    return List<VendingMachine>.unmodifiable(
      machines.where((machine) {
        if (!machine.isLegacy) {
          return indexedIds.contains(machine.id);
        }

        return machine.activeProducts.any(
          (product) => searchState.productIds.contains(product.productId),
        );
      }),
    );
  }

  static bool containsMachine({
    required VendingMachineId machineId,
    required List<VendingMachine> visibleMachines,
  }) {
    return visibleMachines.any((machine) => machine.id == machineId);
  }

  static ProductEvidenceType? evidenceForMachine({
    required VendingMachine machine,
    required GenreMachineSearchState searchState,
  }) {
    if (!machine.isLegacy) {
      return searchState.entryForMachine(machine.id)?.evidenceType;
    }

    ProductEvidenceType? best;

    for (final product in machine.activeProducts) {
      if (!searchState.productIds.contains(product.productId)) {
        continue;
      }

      final evidence = product.evidenceType;
      if (evidence == null) {
        continue;
      }

      if (evidence.isConfirmed) {
        return evidence;
      }

      if (best == null && evidence.isInferred) {
        best = evidence;
      }
    }

    return best;
  }
}
