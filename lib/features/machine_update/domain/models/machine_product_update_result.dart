import '../../../vending_machine/domain/value_objects/vending_machine_id.dart';

final class MachineProductUpdateResult {
  MachineProductUpdateResult({
    required this.machineId,
    required this.updated,
    required List<String> changedProductIds,
  }) : changedProductIds = List<String>.unmodifiable(changedProductIds);

  final VendingMachineId machineId;
  final bool updated;
  final List<String> changedProductIds;
}
