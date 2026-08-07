import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/result/app_result.dart';
import '../../../product_master/application/providers/product_master_providers.dart';
import '../../../product_master/domain/value_objects/master_id.dart';
import '../../domain/value_objects/vending_machine_id.dart';
import '../models/vending_machine_detail_data.dart';
import '../services/vending_machine_detail_loader.dart';
import 'vending_machine_providers.dart';

final vendingMachineDetailLoaderProvider = Provider<VendingMachineDetailLoader>(
  (ref) => VendingMachineDetailLoader(
    machineRepository: ref.watch(vendingMachineRepositoryProvider),
    productRepository: ref.watch(productRepositoryProvider),
    manufacturerRepository: ref.watch(manufacturerRepositoryProvider),
  ),
  name: 'vendingMachineDetailLoaderProvider',
);

final vendingMachineDetailProvider =
    FutureProvider.family<
      AppResult<VendingMachineDetailData>,
      VendingMachineId
    >((ref, machineId) {
      return ref.watch(vendingMachineDetailLoaderProvider).load(machineId);
    }, name: 'vendingMachineDetailProvider');

final manufacturerDisplayNameProvider =
    FutureProvider.family<String, ManufacturerId?>((ref, manufacturerId) async {
      if (manufacturerId == null) {
        return 'メーカー不明';
      }

      final result = await ref
          .watch(manufacturerRepositoryProvider)
          .getManufacturer(manufacturerId);
      final manufacturer = result.valueOrNull;

      if (manufacturer == null) {
        return manufacturerId.value;
      }

      final shortName = manufacturer.displayShortName.trim();
      if (shortName.isNotEmpty) {
        return shortName;
      }

      final name = manufacturer.name.trim();
      return name.isEmpty ? manufacturerId.value : name;
    }, name: 'manufacturerDisplayNameProvider');
