import '../../../../core/result/app_result.dart';
import '../../../vending_machine/domain/entities/vending_machine.dart';
import '../value_objects/map_viewport_bounds.dart';

abstract interface class VendingMachineMapRepository {
  Future<AppResult<List<VendingMachine>>> getMachinesInViewport(
    MapViewportBounds bounds,
  );
}
