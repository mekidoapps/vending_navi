import '../../product_master/domain/entities/product.dart';
import '../../product_search/application/product_machine_search_state.dart';
import '../../product_search/application/product_search_map_filter.dart';
import '../../vending_machine/domain/entities/vending_machine.dart';
import '../../vending_machine/domain/value_objects/vending_machine_id.dart';
import 'vending_machine_marker_kind.dart';

abstract final class ProductSearchMarkerKindResolver {
  static VendingMachineMarkerKind resolve({
    required VendingMachine machine,
    required VendingMachineId? selectedMachineId,
    required Product? selectedProduct,
    required ProductMachineSearchState searchState,
  }) {
    if (machine.id == selectedMachineId) {
      return VendingMachineMarkerKind.selected;
    }

    final product = selectedProduct;
    if (product == null) {
      return VendingMachineMarkerKindResolver.resolve(
        machine: machine,
        selectedMachineId: selectedMachineId,
      );
    }

    final evidence = ProductSearchMapFilter.evidenceForMachine(
      machine: machine,
      selectedProduct: product,
      searchState: searchState,
    );

    if (evidence?.isConfirmed ?? false) {
      return VendingMachineMarkerKind.confirmedProducts;
    }

    if (evidence?.isInferred ?? false) {
      return VendingMachineMarkerKind.inferredProducts;
    }

    return VendingMachineMarkerKind.locationOnly;
  }
}
