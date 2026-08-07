import '../../../../core/result/app_result.dart';
import '../entities/manufacturer.dart';
import '../value_objects/master_id.dart';

abstract interface class ManufacturerRepository {
  Future<AppResult<List<Manufacturer>>> getManufacturers({
    bool activeOnly = true,
  });

  Future<AppResult<Manufacturer>> getManufacturer(ManufacturerId id);
}
