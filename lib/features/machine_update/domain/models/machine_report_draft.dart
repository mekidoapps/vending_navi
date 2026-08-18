import '../../../vending_machine/domain/value_objects/vending_machine_id.dart';
import 'machine_report_category.dart';

final class MachineReportDraft {
  const MachineReportDraft({
    required this.machineId,
    required this.category,
    this.photoId,
    this.message,
  });

  final VendingMachineId machineId;
  final MachineReportCategory category;

  /// Formal vending-machine photo ID.
  ///
  /// Null means the report targets the vending machine itself rather
  /// than a specific photo.
  final String? photoId;

  final String? message;
}
