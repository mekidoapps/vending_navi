import '../../../vending_machine/domain/value_objects/vending_machine_id.dart';
import 'machine_product_update_operation.dart';

final class MachineProductUpdateDraft {
  MachineProductUpdateDraft({
    required this.machineId,
    required List<MachineProductUpdateOperation> operations,
    this.temporaryPhotoUploadId,
    Map<String, String> productNames = const <String, String>{},
  }) : operations = List<MachineProductUpdateOperation>.unmodifiable(
         operations,
       ),
       productNames = Map<String, String>.unmodifiable(productNames);

  final VendingMachineId machineId;
  final List<MachineProductUpdateOperation> operations;
  final String? temporaryPhotoUploadId;

  /// UI-only labels used by the review screen.
  /// They are intentionally not serialized into the Callable request.
  final Map<String, String> productNames;
}
