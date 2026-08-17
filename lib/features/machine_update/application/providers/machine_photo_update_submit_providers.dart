import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/firebase/firebase_providers.dart';
import '../../data/repositories/machine_photo_finalization_repository_impl.dart';
import '../../data/sources/callable_machine_photo_finalization_data_source.dart';
import '../../data/sources/machine_photo_finalization_data_source.dart';
import '../../domain/repositories/machine_photo_finalization_repository.dart';
import '../../domain/services/machine_product_update_request_id_generator.dart';

final machinePhotoFinalizationDataSourceProvider =
    Provider<MachinePhotoFinalizationDataSource>(
      (ref) => CallableMachinePhotoFinalizationDataSource(
        ref.watch(cloudFunctionsProvider),
      ),
      name: 'machinePhotoFinalizationDataSourceProvider',
    );

final machinePhotoFinalizationRepositoryProvider =
    Provider<MachinePhotoFinalizationRepository>(
      (ref) => MachinePhotoFinalizationRepositoryImpl(
        ref.watch(machinePhotoFinalizationDataSourceProvider),
      ),
      name: 'machinePhotoFinalizationRepositoryProvider',
    );

final machinePhotoFinalizationRequestIdGeneratorProvider =
    Provider<MachineProductUpdateRequestIdGenerator>(
      (_) => SecureMachineProductUpdateRequestIdGenerator(),
      name: 'machinePhotoFinalizationRequestIdGeneratorProvider',
    );
