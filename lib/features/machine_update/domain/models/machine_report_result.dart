import '../../../vending_machine/domain/value_objects/vending_machine_id.dart';

final class MachineReportResult {
  const MachineReportResult({required this.machineId, required this.reportId});

  final VendingMachineId machineId;
  final String reportId;
}
