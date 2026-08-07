import '../entities/vending_machine.dart';

final class VendingMachineReadBatch {
  const VendingMachineReadBatch({
    required this.machines,
    required this.skippedLegacyWithoutLocation,
    required this.unresolvedLegacyProductCount,
  });

  final List<VendingMachine> machines;
  final int skippedLegacyWithoutLocation;
  final int unresolvedLegacyProductCount;
}
