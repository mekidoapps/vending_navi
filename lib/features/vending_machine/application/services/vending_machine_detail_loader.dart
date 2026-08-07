import '../../../../core/errors/app_failure.dart';
import '../../../../core/result/app_result.dart';
import '../../../product_master/domain/entities/product.dart';
import '../../../product_master/domain/repositories/manufacturer_repository.dart';
import '../../../product_master/domain/repositories/product_repository.dart';
import '../../../product_master/domain/value_objects/master_id.dart';
import '../../domain/repositories/vending_machine_repository.dart';
import '../../domain/value_objects/vending_machine_id.dart';
import '../models/vending_machine_detail_data.dart';

final class VendingMachineDetailLoader {
  const VendingMachineDetailLoader({
    required VendingMachineRepository machineRepository,
    required ProductRepository productRepository,
    required ManufacturerRepository manufacturerRepository,
  }) : _machineRepository = machineRepository,
       _productRepository = productRepository,
       _manufacturerRepository = manufacturerRepository;

  final VendingMachineRepository _machineRepository;
  final ProductRepository _productRepository;
  final ManufacturerRepository _manufacturerRepository;

  Future<AppResult<VendingMachineDetailData>> load(
    VendingMachineId machineId,
  ) async {
    final machineResult = await _machineRepository.getMachine(machineId);
    final machineFailure = machineResult.failureOrNull;
    if (machineFailure != null) {
      return AppResult<VendingMachineDetailData>.failure(machineFailure);
    }

    final machine = machineResult.valueOrNull;
    if (machine == null) {
      return const AppResult<VendingMachineDetailData>.failure(
        NotFoundFailure(),
      );
    }

    final manufacturerName = await _manufacturerName(machine.manufacturerId);
    final productNames = await _productNames();

    final products =
        machine.activeProducts
            .map((product) {
              return VendingMachineProductDetailItem(
                productId: product.productId,
                productName:
                    productNames[product.productId] ?? product.productId.value,
                evidenceType: product.evidenceType,
                availability: product.availability,
              );
            })
            .toList(growable: false)
          ..sort(_compareProducts);

    return AppResult<VendingMachineDetailData>.success(
      VendingMachineDetailData(
        machine: machine,
        manufacturerName: manufacturerName,
        products: List<VendingMachineProductDetailItem>.unmodifiable(products),
      ),
    );
  }

  Future<String> _manufacturerName(ManufacturerId? id) async {
    if (id == null) {
      return 'メーカー不明';
    }

    final result = await _manufacturerRepository.getManufacturer(id);
    final manufacturer = result.valueOrNull;

    if (manufacturer == null) {
      return id.value;
    }

    final shortName = manufacturer.displayShortName.trim();
    if (shortName.isNotEmpty) {
      return shortName;
    }

    final name = manufacturer.name.trim();
    return name.isEmpty ? id.value : name;
  }

  Future<Map<ProductId, String>> _productNames() async {
    final result = await _productRepository.getProducts(activeOnly: false);
    final products = result.valueOrNull ?? const <Product>[];

    return <ProductId, String>{
      for (final product in products)
        product.id: product.name.trim().isEmpty
            ? product.id.value
            : product.name.trim(),
    };
  }

  static int _compareProducts(
    VendingMachineProductDetailItem left,
    VendingMachineProductDetailItem right,
  ) {
    final evidenceOrder = _evidenceOrder(left).compareTo(_evidenceOrder(right));
    if (evidenceOrder != 0) {
      return evidenceOrder;
    }

    return left.productName.compareTo(right.productName);
  }

  static int _evidenceOrder(VendingMachineProductDetailItem item) {
    if (item.isConfirmed) {
      return 0;
    }
    if (item.isInferred) {
      return 1;
    }
    return 2;
  }
}
