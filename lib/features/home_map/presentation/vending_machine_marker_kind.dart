import '../../vending_machine/domain/entities/vending_machine.dart';
import '../../vending_machine/domain/value_objects/vending_machine_id.dart';

enum VendingMachineMarkerKind {
  selected,
  confirmedProducts,
  inferredProducts,
  locationOnly,
}

abstract final class VendingMachineMarkerKindResolver {
  static VendingMachineMarkerKind resolve({
    required VendingMachine machine,
    required VendingMachineId? selectedMachineId,
  }) {
    if (machine.id == selectedMachineId) {
      return VendingMachineMarkerKind.selected;
    }

    if (machine.confirmedProducts.isNotEmpty) {
      return VendingMachineMarkerKind.confirmedProducts;
    }

    if (machine.inferredProducts.isNotEmpty) {
      return VendingMachineMarkerKind.inferredProducts;
    }

    return VendingMachineMarkerKind.locationOnly;
  }
}
