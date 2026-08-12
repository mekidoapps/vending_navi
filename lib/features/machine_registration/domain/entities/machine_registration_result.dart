import '../../../vending_machine/domain/value_objects/vending_machine_id.dart';

final class MachineRegistrationResult {
  const MachineRegistrationResult({
    required this.machineId,
    required this.created,
  });

  final VendingMachineId machineId;
  final bool created;
}
