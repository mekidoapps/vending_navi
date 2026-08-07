import 'package:freezed_annotation/freezed_annotation.dart';

import '../../../product_master/domain/value_objects/master_id.dart';
import 'vending_machine_enums.dart';

part 'vending_machine_product.freezed.dart';

@freezed
abstract class VendingMachineProduct with _$VendingMachineProduct {
  const VendingMachineProduct._();

  const factory VendingMachineProduct({
    required ProductId productId,

    /// Null is reserved for legacy read compatibility.
    ///
    /// Every schemaVersion=2 Firestore product document must have a valid
    /// evidence type.
    ProductEvidenceType? evidenceType,
    required ProductAvailability availability,
    @Default(true) bool isActive,
    String? confirmedBy,
    DateTime? confirmedAt,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) = _VendingMachineProduct;

  bool get isConfirmed => evidenceType?.isConfirmed ?? false;

  bool get isInferred => evidenceType?.isInferred ?? false;

  bool get isSoldOut => availability == ProductAvailability.soldOut;
}
