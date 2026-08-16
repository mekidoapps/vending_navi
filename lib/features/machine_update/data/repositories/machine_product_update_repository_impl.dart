import '../../../../core/errors/app_failure.dart';
import '../../../../core/errors/failure_mapper.dart';
import '../../../../core/result/app_result.dart';
import '../../../vending_machine/domain/value_objects/vending_machine_id.dart';
import '../../domain/models/machine_product_update_draft.dart';
import '../../domain/models/machine_product_update_result.dart';
import '../../domain/repositories/machine_product_update_repository.dart';
import '../dtos/update_vending_machine_products_request_dto.dart';
import '../dtos/update_vending_machine_products_response_dto.dart';
import '../sources/machine_product_update_data_source.dart';

final class MachineProductUpdateRepositoryImpl
    implements MachineProductUpdateRepository {
  const MachineProductUpdateRepositoryImpl(this._source);

  final MachineProductUpdateDataSource _source;

  @override
  Future<AppResult<MachineProductUpdateResult>> updateProducts({
    required String requestId,
    required MachineProductUpdateDraft draft,
  }) async {
    try {
      final request = UpdateVendingMachineProductsRequestDto(
        requestId: requestId,
        draft: draft,
      );

      final rawResponse = await _source.updateVendingMachineProducts(
        request.toMap(),
      );

      final response = UpdateVendingMachineProductsResponseDto.fromMap(
        rawResponse,
      );

      final machineId = VendingMachineId.tryParse(response.machineId);

      if (machineId == null) {
        return const AppResult<MachineProductUpdateResult>.failure(
          ValidationFailure(field: 'machineId'),
        );
      }

      if (machineId != draft.machineId) {
        return const AppResult<MachineProductUpdateResult>.failure(
          ValidationFailure(field: 'machineId'),
        );
      }

      return AppResult<MachineProductUpdateResult>.success(
        MachineProductUpdateResult(
          machineId: machineId,
          updated: response.updated,
          changedProductIds: response.changedProductIds,
        ),
      );
    } on Object catch (error) {
      return AppResult<MachineProductUpdateResult>.failure(
        FailureMapper.map(error),
      );
    }
  }
}
