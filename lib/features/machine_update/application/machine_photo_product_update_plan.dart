import '../../product_master/domain/entities/product.dart';
import '../../vending_machine/application/models/vending_machine_detail_data.dart';
import '../../vending_machine/domain/value_objects/vending_machine_id.dart';
import '../domain/models/machine_product_update_draft.dart';
import '../domain/models/machine_product_update_operation.dart';

enum MachinePhotoProductUpdateAction {
  alreadyConfirmed,
  confirmInferred,
  addPhotoConfirmed,
  addManualConfirmed,
}

final class MachinePhotoProductUpdatePlanItem {
  const MachinePhotoProductUpdatePlanItem({
    required this.productId,
    required this.productName,
    required this.action,
    required this.wasAiCandidate,
  });

  final String productId;
  final String productName;
  final MachinePhotoProductUpdateAction action;
  final bool wasAiCandidate;

  bool get changesPublicData =>
      action != MachinePhotoProductUpdateAction.alreadyConfirmed;
}

final class MachinePhotoProductUpdatePlan {
  MachinePhotoProductUpdatePlan({
    required List<MachinePhotoProductUpdatePlanItem> items,
    required List<MachineProductUpdateOperation> operations,
    required Map<String, String> productNames,
  }) : items = List<MachinePhotoProductUpdatePlanItem>.unmodifiable(items),
       operations = List<MachineProductUpdateOperation>.unmodifiable(
         operations,
       ),
       productNames = Map<String, String>.unmodifiable(productNames);

  final List<MachinePhotoProductUpdatePlanItem> items;
  final List<MachineProductUpdateOperation> operations;
  final Map<String, String> productNames;

  bool get hasProductChanges => operations.isNotEmpty;

  int get changedProductCount =>
      items.where((item) => item.changesPublicData).length;

  int get unchangedConfirmedCount => items
      .where(
        (item) =>
            item.action == MachinePhotoProductUpdateAction.alreadyConfirmed,
      )
      .length;

  MachineProductUpdateDraft toDraft({
    required VendingMachineId machineId,
    required String temporaryPhotoUploadId,
  }) {
    return MachineProductUpdateDraft(
      machineId: machineId,
      operations: operations,
      temporaryPhotoUploadId: temporaryPhotoUploadId,
      productNames: productNames,
    );
  }
}

abstract final class MachinePhotoProductUpdatePlanner {
  static MachinePhotoProductUpdatePlan build({
    required Iterable<VendingMachineProductDetailItem> currentProducts,
    required Iterable<Product> productMaster,
    required Set<String> aiProductCandidateIds,
    required Set<String> selectedProductIds,
  }) {
    final currentById = <String, VendingMachineProductDetailItem>{
      for (final item in currentProducts) item.productId.value: item,
    };

    final masterById = <String, Product>{
      for (final product in productMaster)
        if (product.isSelectable) product.id.value: product,
    };

    final aiIds = aiProductCandidateIds
        .map((id) => id.trim())
        .where(masterById.containsKey)
        .toSet();

    final selectedIds =
        selectedProductIds
            .map((id) => id.trim())
            .where(masterById.containsKey)
            .toList(growable: false)
          ..sort();

    final items = <MachinePhotoProductUpdatePlanItem>[];
    final operations = <MachineProductUpdateOperation>[];
    final productNames = <String, String>{};

    for (final productId in selectedIds) {
      final current = currentById[productId];
      final master = masterById[productId]!;
      final wasAiCandidate = aiIds.contains(productId);

      final productName = current?.productName.trim().isNotEmpty == true
          ? current!.productName.trim()
          : master.name.trim();

      productNames[productId] = productName;

      if (current?.isConfirmed == true) {
        items.add(
          MachinePhotoProductUpdatePlanItem(
            productId: productId,
            productName: productName,
            action: MachinePhotoProductUpdateAction.alreadyConfirmed,
            wasAiCandidate: wasAiCandidate,
          ),
        );
        continue;
      }

      if (current?.isInferred == true) {
        items.add(
          MachinePhotoProductUpdatePlanItem(
            productId: productId,
            productName: productName,
            action: MachinePhotoProductUpdateAction.confirmInferred,
            wasAiCandidate: wasAiCandidate,
          ),
        );

        operations.add(
          MachineProductUpdateOperation.confirmInferred(productId: productId),
        );
        continue;
      }

      final action = wasAiCandidate
          ? MachinePhotoProductUpdateAction.addPhotoConfirmed
          : MachinePhotoProductUpdateAction.addManualConfirmed;

      items.add(
        MachinePhotoProductUpdatePlanItem(
          productId: productId,
          productName: productName,
          action: action,
          wasAiCandidate: wasAiCandidate,
        ),
      );

      operations.add(
        MachineProductUpdateOperation.addConfirmed(
          productId: productId,
          source: wasAiCandidate
              ? MachineProductUpdateSource.photo
              : MachineProductUpdateSource.manual,
        ),
      );
    }

    return MachinePhotoProductUpdatePlan(
      items: items,
      operations: operations,
      productNames: productNames,
    );
  }
}
