import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/firebase/firebase_providers.dart';
import '../../data/repositories/machine_correction_repository_impl.dart';
import '../../data/sources/callable_machine_correction_data_source.dart';
import '../../data/sources/machine_correction_data_source.dart';
import '../../domain/repositories/machine_correction_repository.dart';
import '../../domain/services/machine_product_update_request_id_generator.dart';

final machineCorrectionDataSourceProvider =
    Provider<MachineCorrectionDataSource>(
      (ref) => CallableMachineCorrectionDataSource(
        ref.watch(cloudFunctionsProvider),
      ),
      name: 'machineCorrectionDataSourceProvider',
    );

final machineCorrectionRepositoryProvider =
    Provider<MachineCorrectionRepository>(
      (ref) => MachineCorrectionRepositoryImpl(
        ref.watch(machineCorrectionDataSourceProvider),
      ),
      name: 'machineCorrectionRepositoryProvider',
    );

final machineCorrectionRequestIdGeneratorProvider =
    Provider<MachineProductUpdateRequestIdGenerator>(
      (_) => SecureMachineProductUpdateRequestIdGenerator(),
      name: 'machineCorrectionRequestIdGeneratorProvider',
    );
