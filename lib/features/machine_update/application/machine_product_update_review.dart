import '../domain/models/machine_product_update_draft.dart';
import '../domain/models/machine_product_update_operation.dart';

final class MachineProductUpdateReviewItem {
  MachineProductUpdateReviewItem({
    required this.productId,
    required this.productName,
    required List<String> changes,
  }) : changes = List<String>.unmodifiable(changes);

  final String productId;
  final String productName;
  final List<String> changes;
}

List<MachineProductUpdateReviewItem> buildMachineProductUpdateReviewItems(
  MachineProductUpdateDraft draft,
) {
  final grouped = <String, List<String>>{};

  for (final operation in draft.operations) {
    final changes = grouped.putIfAbsent(operation.productId, () => <String>[]);

    switch (operation.type) {
      case MachineProductUpdateOperationType.addConfirmed:
        changes.add('商品を追加');

      case MachineProductUpdateOperationType.deactivate:
        changes.add('なくなった');

      case MachineProductUpdateOperationType.setSoldOut:
        changes.add(operation.soldOut == true ? '売り切れに変更' : '販売中に変更');

      case MachineProductUpdateOperationType.confirmInferred:
        changes.add('置いてあったとして確認済みに変更');
    }
  }

  final productIds = grouped.keys.toList()..sort();

  return List<MachineProductUpdateReviewItem>.unmodifiable(
    productIds.map(
      (productId) => MachineProductUpdateReviewItem(
        productId: productId,
        productName: draft.productNames[productId]?.trim().isNotEmpty == true
            ? draft.productNames[productId]!.trim()
            : productId,
        changes: grouped[productId]!,
      ),
    ),
  );
}
