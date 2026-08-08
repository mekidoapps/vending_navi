import '../../product_master/domain/entities/product.dart';
import '../../vending_machine/domain/entities/vending_machine.dart';
import '../../vending_machine/domain/entities/vending_machine_product.dart';
import '../../product_master/domain/value_objects/master_id.dart';
import '../../vending_machine/domain/entities/vending_machine_enums.dart';
import '../../vending_machine/domain/value_objects/vending_machine_id.dart';
import '../domain/entities/machine_product_index_entry.dart';
import 'product_machine_search_state.dart';

abstract final class ProductSearchMapFilter {
  static List<VendingMachine> visibleMachines({
    required List<VendingMachine> machines,
    required Product? selectedProduct,
    required ProductMachineSearchState searchState,
  }) {
    if (selectedProduct == null) {
      return List<VendingMachine>.unmodifiable(machines);
    }

    if (searchState.productId != selectedProduct.id ||
        searchState.isLoading ||
        searchState.failure != null ||
        !searchState.hasSearched) {
      return const <VendingMachine>[];
    }

    final indexedIds = searchState.indexedMachineIds;

    return List<VendingMachine>.unmodifiable(
      machines.where((machine) {
        if (machine.isLegacy) {
          return _legacyProduct(machine, selectedProduct.id) != null;
        }

        return indexedIds.contains(machine.id);
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
    required Product selectedProduct,
    required ProductMachineSearchState searchState,
  }) {
    if (machine.isLegacy) {
      return _legacyProduct(machine, selectedProduct.id)?.evidenceType;
    }

    return searchState.entryForMachine(machine.id)?.evidenceType;
  }

  static MachineProductIndexEntry? indexedEntryForMachine({
    required VendingMachine machine,
    required ProductMachineSearchState searchState,
  }) {
    if (machine.isLegacy) {
      return null;
    }
    return searchState.entryForMachine(machine.id);
  }

  static VendingMachineProduct? _legacyProduct(
    VendingMachine machine,
    ProductId productId,
  ) {
    for (final product in machine.activeProducts) {
      if (product.productId == productId) {
        return product;
      }
    }
    return null;
  }
}
