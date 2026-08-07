import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/firebase/firebase_providers.dart';
import '../../data/repositories/machine_product_index_repository_impl.dart';
import '../../data/sources/firestore_machine_product_index_source.dart';
import '../../data/sources/machine_product_index_source.dart';
import '../../domain/repositories/machine_product_index_repository.dart';

final machineProductIndexSourceProvider = Provider<MachineProductIndexSource>(
  (ref) => FirestoreMachineProductIndexSource(ref.watch(firestoreProvider)),
  name: 'machineProductIndexSourceProvider',
);

final machineProductIndexRepositoryProvider =
    Provider<MachineProductIndexRepository>(
      (ref) => MachineProductIndexRepositoryImpl(
        source: ref.watch(machineProductIndexSourceProvider),
      ),
      name: 'machineProductIndexRepositoryProvider',
    );
