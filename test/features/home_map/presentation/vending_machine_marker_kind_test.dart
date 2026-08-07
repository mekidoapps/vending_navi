import 'package:flutter_test/flutter_test.dart';
import 'package:vending_app/features/product_master/domain/value_objects/master_id.dart';
import 'package:vending_app/features/vending_machine/domain/entities/vending_machine.dart';
import 'package:vending_app/features/vending_machine/domain/entities/vending_machine_enums.dart';
import 'package:vending_app/features/vending_machine/domain/entities/vending_machine_product.dart';
import 'package:vending_app/features/vending_machine/domain/value_objects/geo_coordinate.dart';
import 'package:vending_app/features/vending_machine/domain/value_objects/vending_machine_id.dart';
import 'package:vending_app/features/home_map/presentation/vending_machine_marker_kind.dart';

void main() {
  test('選択中を最優先にする', () {
    final machine = _machine(
      products: <VendingMachineProduct>[
        _product(ProductEvidenceType.manualConfirmed),
      ],
    );

    expect(
      VendingMachineMarkerKindResolver.resolve(
        machine: machine,
        selectedMachineId: machine.id,
      ),
      VendingMachineMarkerKind.selected,
    );
  });

  test('確認済み商品ありをconfirmedProductsにする', () {
    final machine = _machine(
      products: <VendingMachineProduct>[
        _product(ProductEvidenceType.manualConfirmed),
      ],
    );

    expect(
      VendingMachineMarkerKindResolver.resolve(
        machine: machine,
        selectedMachineId: null,
      ),
      VendingMachineMarkerKind.confirmedProducts,
    );
  });

  test('推定商品だけならinferredProductsにする', () {
    final machine = _machine(
      products: <VendingMachineProduct>[
        _product(ProductEvidenceType.manufacturerInferred),
      ],
    );

    expect(
      VendingMachineMarkerKindResolver.resolve(
        machine: machine,
        selectedMachineId: null,
      ),
      VendingMachineMarkerKind.inferredProducts,
    );
  });

  test('商品情報なしはlocationOnlyにする', () {
    final machine = _machine();

    expect(
      VendingMachineMarkerKindResolver.resolve(
        machine: machine,
        selectedMachineId: null,
      ),
      VendingMachineMarkerKind.locationOnly,
    );
  });
}

VendingMachine _machine({
  List<VendingMachineProduct> products = const <VendingMachineProduct>[],
}) {
  return VendingMachine(
    id: VendingMachineId.parse('machine_test'),
    schemaVersion: 2,
    name: 'テスト自販機',
    manufacturerStatus: ManufacturerStatus.unknown,
    location: GeoCoordinate(latitude: 35.68, longitude: 139.76),
    geohash: 'xn76',
    installationType: InstallationType.outdoor,
    status: VendingMachineStatus.active,
    dataLevel: VendingMachineDataLevel.locationOnly,
    createdBy: 'test',
    products: products,
  );
}

VendingMachineProduct _product(ProductEvidenceType evidenceType) {
  return VendingMachineProduct(
    productId: ProductId.parse('suntory_boss_black'),
    evidenceType: evidenceType,
    availability: ProductAvailability.available,
  );
}
