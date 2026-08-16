import 'package:flutter_test/flutter_test.dart';

import '../../../../lib/features/machine_update/application/machine_product_update_review.dart';
import '../../../../lib/features/machine_update/domain/models/machine_product_update_draft.dart';
import '../../../../lib/features/machine_update/domain/models/machine_product_update_operation.dart';
import '../../../../lib/features/vending_machine/domain/value_objects/vending_machine_id.dart';

void main() {
  test('groups multiple changes by product for review', () {
    final draft = MachineProductUpdateDraft(
      machineId: VendingMachineId.tryParse('machine-001')!,
      productNames: const <String, String>{'asahi_calpis': 'カルピス'},
      operations: const <MachineProductUpdateOperation>[
        MachineProductUpdateOperation.addConfirmed(
          productId: 'asahi_calpis',
          source: MachineProductUpdateSource.manual,
        ),
        MachineProductUpdateOperation.setSoldOut(
          productId: 'asahi_calpis',
          soldOut: true,
        ),
      ],
    );

    final items = buildMachineProductUpdateReviewItems(draft);

    expect(items, hasLength(1));
    expect(items.single.productId, 'asahi_calpis');
    expect(items.single.productName, 'カルピス');
    expect(items.single.changes, <String>['商品を追加', '売り切れに変更']);
  });

  test('shows inferred confirmation and sold-out change together', () {
    final draft = MachineProductUpdateDraft(
      machineId: VendingMachineId.tryParse('machine-001')!,
      productNames: const <String, String>{'asahi_wonda_black': 'ワンダ ブラック'},
      operations: const <MachineProductUpdateOperation>[
        MachineProductUpdateOperation.confirmInferred(
          productId: 'asahi_wonda_black',
        ),
        MachineProductUpdateOperation.setSoldOut(
          productId: 'asahi_wonda_black',
          soldOut: true,
        ),
      ],
    );

    final item = buildMachineProductUpdateReviewItems(draft).single;

    expect(item.productName, 'ワンダ ブラック');
    expect(item.changes, <String>['置いてあったとして確認済みに変更', '売り切れに変更']);
  });

  test('falls back to product ID when UI label is unavailable', () {
    final draft = MachineProductUpdateDraft(
      machineId: VendingMachineId.tryParse('machine-001')!,
      operations: const <MachineProductUpdateOperation>[
        MachineProductUpdateOperation.deactivate(productId: 'unknown_product'),
      ],
    );

    final item = buildMachineProductUpdateReviewItems(draft).single;

    expect(item.productName, 'unknown_product');
    expect(item.changes, <String>['なくなった']);
  });
}
