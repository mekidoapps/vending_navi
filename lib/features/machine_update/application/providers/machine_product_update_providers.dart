import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/firebase/firebase_providers.dart';
import '../../data/repositories/machine_product_update_repository_impl.dart';
import '../../data/sources/callable_machine_product_update_data_source.dart';
import '../../data/sources/machine_product_update_data_source.dart';
import '../../domain/repositories/machine_product_update_repository.dart';
import '../../domain/services/machine_product_update_request_id_generator.dart';

final machineProductUpdateDataSourceProvider =
    Provider<MachineProductUpdateDataSource>(
      (ref) => CallableMachineProductUpdateDataSource(
        ref.watch(cloudFunctionsProvider),
      ),
      name: 'machineProductUpdateDataSourceProvider',
    );

final machineProductUpdateRepositoryProvider =
    Provider<MachineProductUpdateRepository>(
      (ref) => MachineProductUpdateRepositoryImpl(
        ref.watch(machineProductUpdateDataSourceProvider),
      ),
      name: 'machineProductUpdateRepositoryProvider',
    );

final machineProductUpdateRequestIdGeneratorProvider =
    Provider<MachineProductUpdateRequestIdGenerator>(
      (_) => SecureMachineProductUpdateRequestIdGenerator(),
      name: 'machineProductUpdateRequestIdGeneratorProvider',
    );
