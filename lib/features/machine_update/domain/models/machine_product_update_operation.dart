enum MachineProductUpdateOperationType {
  addConfirmed,
  deactivate,
  setSoldOut,
  confirmInferred,
}

enum MachineProductUpdateSource { manual, photo }

final class MachineProductUpdateOperation {
  const MachineProductUpdateOperation.addConfirmed({
    required this.productId,
    required this.source,
  }) : type = MachineProductUpdateOperationType.addConfirmed,
       soldOut = null;

  const MachineProductUpdateOperation.deactivate({required this.productId})
    : type = MachineProductUpdateOperationType.deactivate,
      source = null,
      soldOut = null;

  const MachineProductUpdateOperation.setSoldOut({
    required this.productId,
    required this.soldOut,
  }) : type = MachineProductUpdateOperationType.setSoldOut,
       source = null;

  const MachineProductUpdateOperation.confirmInferred({required this.productId})
    : type = MachineProductUpdateOperationType.confirmInferred,
      source = null,
      soldOut = null;

  final MachineProductUpdateOperationType type;
  final String productId;
  final MachineProductUpdateSource? source;
  final bool? soldOut;
}
