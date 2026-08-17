import 'package:flutter_test/flutter_test.dart';

import '../../../../lib/features/machine_update/application/machine_photo_product_update_plan.dart';
import '../../../../lib/features/machine_update/domain/models/machine_product_update_operation.dart';
import '../../../../lib/features/product_master/domain/entities/product.dart';
import '../../../../lib/features/product_master/domain/value_objects/master_id.dart';
import '../../../../lib/features/vending_machine/application/models/vending_machine_detail_data.dart';
import '../../../../lib/features/vending_machine/domain/entities/vending_machine_enums.dart';
import '../../../../lib/features/vending_machine/domain/value_objects/vending_machine_id.dart';

void main() {
  final confirmed = _product(id: 'product_confirmed', name: '確認済み商品');

  final inferred = _product(id: 'product_inferred', name: '推定商品');

  final aiNew = _product(id: 'product_ai_new', name: 'AI新規商品');

  final manualNew = _product(id: 'product_manual_new', name: '手動追加商品');

  final untouched = _product(id: 'product_untouched', name: '写真に写らなかった商品');

  test('confirmed AI candidate produces no operation', () {
    final plan = MachinePhotoProductUpdatePlanner.build(
      currentProducts: <VendingMachineProductDetailItem>[
        _detail(confirmed, evidenceType: ProductEvidenceType.photoConfirmed),
      ],
      productMaster: <Product>[confirmed],
      aiProductCandidateIds: <String>{confirmed.id.value},
      selectedProductIds: <String>{confirmed.id.value},
    );

    expect(plan.operations, isEmpty);
    expect(plan.items, hasLength(1));
    expect(
      plan.items.single.action,
      MachinePhotoProductUpdateAction.alreadyConfirmed,
    );
    expect(plan.hasProductChanges, isFalse);
  });

  test('selected inferred product becomes confirmInferred', () {
    final plan = MachinePhotoProductUpdatePlanner.build(
      currentProducts: <VendingMachineProductDetailItem>[
        _detail(
          inferred,
          evidenceType: ProductEvidenceType.manufacturerInferred,
          availability: ProductAvailability.unknown,
        ),
      ],
      productMaster: <Product>[inferred],
      aiProductCandidateIds: <String>{inferred.id.value},
      selectedProductIds: <String>{inferred.id.value},
    );

    expect(plan.operations, hasLength(1));

    final operation = plan.operations.single;

    expect(operation.type, MachineProductUpdateOperationType.confirmInferred);
    expect(operation.productId, inferred.id.value);
    expect(operation.source, isNull);
  });

  test('new AI candidate uses photo source', () {
    final plan = MachinePhotoProductUpdatePlanner.build(
      currentProducts: const <VendingMachineProductDetailItem>[],
      productMaster: <Product>[aiNew],
      aiProductCandidateIds: <String>{aiNew.id.value},
      selectedProductIds: <String>{aiNew.id.value},
    );

    final operation = plan.operations.single;

    expect(operation.type, MachineProductUpdateOperationType.addConfirmed);
    expect(operation.source, MachineProductUpdateSource.photo);
  });

  test('user-added non-AI product uses manual source', () {
    final plan = MachinePhotoProductUpdatePlanner.build(
      currentProducts: const <VendingMachineProductDetailItem>[],
      productMaster: <Product>[manualNew],
      aiProductCandidateIds: const <String>{},
      selectedProductIds: <String>{manualNew.id.value},
    );

    final operation = plan.operations.single;

    expect(operation.type, MachineProductUpdateOperationType.addConfirmed);
    expect(operation.source, MachineProductUpdateSource.manual);

    expect(
      plan.items.single.action,
      MachinePhotoProductUpdateAction.addManualConfirmed,
    );
  });

  test('existing product absent from photo selection is never deactivated', () {
    final plan = MachinePhotoProductUpdatePlanner.build(
      currentProducts: <VendingMachineProductDetailItem>[
        _detail(untouched, evidenceType: ProductEvidenceType.manualConfirmed),
      ],
      productMaster: <Product>[untouched, aiNew],
      aiProductCandidateIds: <String>{aiNew.id.value},
      selectedProductIds: <String>{aiNew.id.value},
    );

    expect(
      plan.operations.any(
        (operation) =>
            operation.type == MachineProductUpdateOperationType.deactivate &&
            operation.productId == untouched.id.value,
      ),
      isFalse,
    );

    expect(
      plan.items.any((item) => item.productId == untouched.id.value),
      isFalse,
    );
  });

  test('mixed plan is deterministic and builds photo draft', () {
    final plan = MachinePhotoProductUpdatePlanner.build(
      currentProducts: <VendingMachineProductDetailItem>[
        _detail(confirmed, evidenceType: ProductEvidenceType.manualConfirmed),
        _detail(
          inferred,
          evidenceType: ProductEvidenceType.manufacturerInferred,
          availability: ProductAvailability.unknown,
        ),
        _detail(untouched, evidenceType: ProductEvidenceType.manualConfirmed),
      ],
      productMaster: <Product>[
        confirmed,
        inferred,
        aiNew,
        manualNew,
        untouched,
      ],
      aiProductCandidateIds: <String>{
        confirmed.id.value,
        inferred.id.value,
        aiNew.id.value,
      },
      selectedProductIds: <String>{
        manualNew.id.value,
        aiNew.id.value,
        inferred.id.value,
        confirmed.id.value,
      },
    );

    expect(plan.items, hasLength(4));
    expect(plan.operations, hasLength(3));
    expect(plan.changedProductCount, 3);
    expect(plan.unchangedConfirmedCount, 1);

    final byProductId = <String, MachineProductUpdateOperation>{
      for (final operation in plan.operations) operation.productId: operation,
    };

    expect(
      byProductId[inferred.id.value]!.type,
      MachineProductUpdateOperationType.confirmInferred,
    );

    expect(
      byProductId[aiNew.id.value]!.source,
      MachineProductUpdateSource.photo,
    );

    expect(
      byProductId[manualNew.id.value]!.source,
      MachineProductUpdateSource.manual,
    );

    final draft = plan.toDraft(
      machineId: VendingMachineId.tryParse('machine_001')!,
      temporaryPhotoUploadId: '123e4567-e89b-42d3-a456-426614174000',
    );

    expect(draft.machineId.value, 'machine_001');
    expect(
      draft.temporaryPhotoUploadId,
      '123e4567-e89b-42d3-a456-426614174000',
    );
    expect(draft.operations, hasLength(3));
    expect(draft.productNames[aiNew.id.value], aiNew.name);
    expect(draft.productNames[manualNew.id.value], manualNew.name);
  });

  test('unknown selected IDs are never converted into operations', () {
    final plan = MachinePhotoProductUpdatePlanner.build(
      currentProducts: const <VendingMachineProductDetailItem>[],
      productMaster: <Product>[aiNew],
      aiProductCandidateIds: <String>{aiNew.id.value, 'not_in_master'},
      selectedProductIds: <String>{aiNew.id.value, 'not_in_master'},
    );

    expect(plan.operations, hasLength(1));
    expect(plan.operations.single.productId, aiNew.id.value);
  });
}

Product _product({required String id, required String name}) {
  return Product(
    id: ProductId.tryParse(id)!,
    name: name,
    manufacturerId: ManufacturerId.tryParse('asahi')!,
    createdAt: DateTime.utc(2026, 1, 1),
    updatedAt: DateTime.utc(2026, 1, 1),
  );
}

VendingMachineProductDetailItem _detail(
  Product product, {
  required ProductEvidenceType evidenceType,
  ProductAvailability availability = ProductAvailability.available,
}) {
  return VendingMachineProductDetailItem(
    productId: product.id,
    productName: product.name,
    evidenceType: evidenceType,
    availability: availability,
  );
}
