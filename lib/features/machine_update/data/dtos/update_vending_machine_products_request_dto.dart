import '../../domain/models/machine_product_update_draft.dart';
import '../../domain/models/machine_product_update_operation.dart';

final class UpdateVendingMachineProductsRequestDto {
  const UpdateVendingMachineProductsRequestDto({
    required this.requestId,
    required this.draft,
  });

  final String requestId;
  final MachineProductUpdateDraft draft;

  Map<String, Object?> toMap() {
    return <String, Object?>{
      'requestId': requestId,
      'machineId': draft.machineId.value,
      'operations': draft.operations
          .map<Map<String, Object?>>(_operationToMap)
          .toList(growable: false),
      'temporaryPhotoUploadId': draft.temporaryPhotoUploadId,
    };
  }

  static Map<String, Object?> _operationToMap(
    MachineProductUpdateOperation operation,
  ) {
    switch (operation.type) {
      case MachineProductUpdateOperationType.addConfirmed:
        final source = operation.source;
        if (source == null) {
          throw const FormatException('addConfirmed requires a source');
        }

        return <String, Object?>{
          'type': 'addConfirmed',
          'productId': operation.productId,
          'source': switch (source) {
            MachineProductUpdateSource.manual => 'manual',
            MachineProductUpdateSource.photo => 'photo',
          },
        };

      case MachineProductUpdateOperationType.deactivate:
        return <String, Object?>{
          'type': 'deactivate',
          'productId': operation.productId,
        };

      case MachineProductUpdateOperationType.setSoldOut:
        final soldOut = operation.soldOut;
        if (soldOut == null) {
          throw const FormatException('setSoldOut requires soldOut');
        }

        return <String, Object?>{
          'type': 'setSoldOut',
          'productId': operation.productId,
          'soldOut': soldOut,
        };

      case MachineProductUpdateOperationType.confirmInferred:
        return <String, Object?>{
          'type': 'confirmInferred',
          'productId': operation.productId,
        };
    }
  }
}
