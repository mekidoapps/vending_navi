import '../../../vending_machine/domain/value_objects/vending_machine_id.dart';

final class MachineCorrectionResult {
  const MachineCorrectionResult({
    required this.machineId,
    required this.correctionId,
  });

  final VendingMachineId machineId;
  final String correctionId;
}
