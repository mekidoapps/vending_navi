import '../../../../core/errors/app_failure.dart';
import '../../../../core/result/app_result.dart';
import '../../../product_master/domain/value_objects/master_id.dart';
import '../../domain/entities/vending_machine_enums.dart';
import '../../domain/entities/vending_machine_product.dart';
import '../dtos/vending_machine_product_dto.dart';

abstract final class VendingMachineProductMapper {
  static AppResult<VendingMachineProduct> fromFirestoreDocument({
    required String documentId,
    required Map<String, dynamic> data,
  }) {
    try {
      return toDomain(
        VendingMachineProductDto.fromFirestoreDocument(
          documentId: documentId,
          data: data,
        ),
      );
    } on Object {
      return _invalid('vendingMachineProduct.document');
    }
  }

  static AppResult<VendingMachineProduct> toDomain(
    VendingMachineProductDto dto,
  ) {
    final documentProductId = ProductId.tryParse(dto.documentId);
    final fieldProductId = ProductId.tryParse(dto.productId);

    if (documentProductId == null ||
        fieldProductId == null ||
        documentProductId != fieldProductId) {
      return _invalid('vendingMachineProduct.productId');
    }

    final evidenceType = ProductEvidenceType.tryParse(dto.evidenceType);
    if (evidenceType == null) {
      return _invalid('vendingMachineProduct.evidenceType');
    }

    final availability = ProductAvailability.tryParse(dto.availability);
    if (availability == null) {
      return _invalid('vendingMachineProduct.availability');
    }

    return AppResult<VendingMachineProduct>.success(
      VendingMachineProduct(
        productId: fieldProductId,
        evidenceType: evidenceType,
        availability: availability,
        isActive: dto.isActive,
        confirmedBy: null,
        confirmedAt: dto.confirmedAt?.toUtc(),
        createdAt: dto.createdAt.toUtc(),
        updatedAt: dto.updatedAt.toUtc(),
      ),
    );
  }

  static AppResult<VendingMachineProduct> _invalid(String field) {
    return AppResult<VendingMachineProduct>.failure(
      ValidationFailure(field: field),
    );
  }
}
