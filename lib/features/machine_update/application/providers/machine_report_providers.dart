import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/firebase/firebase_providers.dart';
import '../../data/repositories/machine_report_repository_impl.dart';
import '../../data/sources/callable_machine_report_data_source.dart';
import '../../data/sources/machine_report_data_source.dart';
import '../../domain/repositories/machine_report_repository.dart';
import '../../domain/services/machine_product_update_request_id_generator.dart';

final machineReportDataSourceProvider = Provider<MachineReportDataSource>(
  (ref) => CallableMachineReportDataSource(ref.watch(cloudFunctionsProvider)),
  name: 'machineReportDataSourceProvider',
);

final machineReportRepositoryProvider = Provider<MachineReportRepository>(
  (ref) =>
      MachineReportRepositoryImpl(ref.watch(machineReportDataSourceProvider)),
  name: 'machineReportRepositoryProvider',
);

final machineReportRequestIdGeneratorProvider =
    Provider<MachineProductUpdateRequestIdGenerator>(
      (_) => SecureMachineProductUpdateRequestIdGenerator(),
      name: 'machineReportRequestIdGeneratorProvider',
    );
