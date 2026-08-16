import 'package:flutter_test/flutter_test.dart';

import '../../../../lib/features/machine_update/application/machine_product_update_edit_session.dart';
import '../../../../lib/features/machine_update/domain/models/machine_product_update_operation.dart';
import '../../../../lib/features/vending_machine/domain/entities/vending_machine_enums.dart';

void main() {
  test('manual product addition builds addConfirmed', () {
    final session = MachineProductUpdateEditSession(currentProducts: const []);

    expect(session.addConfirmed('asahi_calpis'), isTrue);

    expect(session.changedProductIds, <String>{'asahi_calpis'});

    expect(session.operations, hasLength(1));

    final operation = session.operations.single;
    expect(operation.type, MachineProductUpdateOperationType.addConfirmed);
    expect(operation.source, MachineProductUpdateSource.manual);
  });

  test('confirmed added product may also be marked sold out', () {
    final session = MachineProductUpdateEditSession(currentProducts: const []);

    session.addConfirmed('asahi_calpis');
    session.setSoldOut('asahi_calpis', soldOut: true);

    expect(session.operations, hasLength(2));
    expect(
      session.operations[0].type,
      MachineProductUpdateOperationType.addConfirmed,
    );
    expect(
      session.operations[1].type,
      MachineProductUpdateOperationType.setSoldOut,
    );
    expect(session.operations[1].soldOut, isTrue);
  });

  test('inferred product can be confirmed then marked sold out', () {
    final session = MachineProductUpdateEditSession(
      currentProducts: const [
        MachineProductUpdateOriginalState(
          productId: 'asahi_wonda_black',
          evidenceType: ProductEvidenceType.manufacturerInferred,
          availability: ProductAvailability.unknown,
        ),
      ],
    );

    expect(session.confirmInferred('asahi_wonda_black'), isTrue);

    expect(
      session.effectiveAvailability('asahi_wonda_black'),
      ProductAvailability.available,
    );

    expect(session.setSoldOut('asahi_wonda_black', soldOut: true), isTrue);

    expect(session.operations, hasLength(2));
    expect(
      session.operations[0].type,
      MachineProductUpdateOperationType.confirmInferred,
    );
    expect(
      session.operations[1].type,
      MachineProductUpdateOperationType.setSoldOut,
    );
  });

  test('deactivate replaces other changes for existing product', () {
    final session = MachineProductUpdateEditSession(
      currentProducts: const [
        MachineProductUpdateOriginalState(
          productId: 'asahi_calpis',
          evidenceType: ProductEvidenceType.manualConfirmed,
          availability: ProductAvailability.available,
        ),
      ],
    );

    session.setSoldOut('asahi_calpis', soldOut: true);
    session.deactivate('asahi_calpis');

    expect(session.operations, hasLength(1));
    expect(
      session.operations.single.type,
      MachineProductUpdateOperationType.deactivate,
    );
    expect(session.pendingLabel('asahi_calpis'), 'なくなったとして更新予定');
  });

  test('returning sold-out state to original removes pending operation', () {
    final session = MachineProductUpdateEditSession(
      currentProducts: const [
        MachineProductUpdateOriginalState(
          productId: 'asahi_calpis',
          evidenceType: ProductEvidenceType.manualConfirmed,
          availability: ProductAvailability.available,
        ),
      ],
    );

    session.setSoldOut('asahi_calpis', soldOut: true);

    expect(session.hasChanges, isTrue);

    session.setSoldOut('asahi_calpis', soldOut: false);

    expect(session.hasChanges, isFalse);
    expect(session.operations, isEmpty);
  });

  test('cancel removes every pending change', () {
    final session = MachineProductUpdateEditSession(
      currentProducts: const [
        MachineProductUpdateOriginalState(
          productId: 'asahi_wonda_black',
          evidenceType: ProductEvidenceType.manufacturerInferred,
          availability: ProductAvailability.unknown,
        ),
      ],
    );

    session.confirmInferred('asahi_wonda_black');
    session.setSoldOut('asahi_wonda_black', soldOut: true);

    session.cancelChanges('asahi_wonda_black');

    expect(session.hasChanges, isFalse);
    expect(session.operations, isEmpty);
    expect(
      session.effectiveAvailability('asahi_wonda_black'),
      ProductAvailability.unknown,
    );
  });

  test('operations are deterministic by product ID', () {
    final session = MachineProductUpdateEditSession(currentProducts: const []);

    session.addConfirmed('z_product');
    session.addConfirmed('a_product');

    expect(
      session.operations.map((operation) => operation.productId).toList(),
      <String>['a_product', 'z_product'],
    );
  });
}
