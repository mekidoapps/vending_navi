import '../../../product_master/domain/value_objects/master_id.dart';
import '../../domain/entities/vending_machine.dart';
import '../../domain/entities/vending_machine_enums.dart';

final class VendingMachineDetailData {
  const VendingMachineDetailData({
    required this.machine,
    required this.manufacturerName,
    required this.products,
  });

  final VendingMachine machine;
  final String manufacturerName;
  final List<VendingMachineProductDetailItem> products;

  bool get hasConfirmedProducts =>
      products.any((product) => product.isConfirmed);

  bool get hasInferredProducts => products.any((product) => product.isInferred);
}

final class VendingMachineProductDetailItem {
  const VendingMachineProductDetailItem({
    required this.productId,
    required this.productName,
    required this.evidenceType,
    required this.availability,
  });

  final ProductId productId;
  final String productName;
  final ProductEvidenceType? evidenceType;
  final ProductAvailability availability;

  bool get isConfirmed => evidenceType?.isConfirmed ?? false;

  bool get isInferred => evidenceType?.isInferred ?? false;
}
