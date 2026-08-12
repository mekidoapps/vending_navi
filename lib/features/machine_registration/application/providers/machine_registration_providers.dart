import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/firebase/firebase_providers.dart';
import '../../data/repositories/machine_registration_repository_impl.dart';
import '../../data/sources/callable_machine_registration_data_source.dart';
import '../../data/sources/machine_registration_data_source.dart';
import '../../domain/repositories/machine_registration_repository.dart';
import '../../domain/services/registration_request_id_generator.dart';

final machineRegistrationDataSourceProvider =
    Provider<MachineRegistrationDataSource>(
      (ref) => CallableMachineRegistrationDataSource(
        ref.watch(cloudFunctionsProvider),
      ),
      name: 'machineRegistrationDataSourceProvider',
    );

final machineRegistrationRepositoryProvider =
    Provider<MachineRegistrationRepository>(
      (ref) => MachineRegistrationRepositoryImpl(
        ref.watch(machineRegistrationDataSourceProvider),
      ),
      name: 'machineRegistrationRepositoryProvider',
    );

final registrationRequestIdGeneratorProvider =
    Provider<RegistrationRequestIdGenerator>(
      (_) => RegistrationRequestIdGenerator(),
      name: 'registrationRequestIdGeneratorProvider',
    );
