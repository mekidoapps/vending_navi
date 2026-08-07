import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/firebase/firebase_providers.dart';
import '../../../vending_machine/application/providers/vending_machine_providers.dart';
import '../../data/repositories/vending_machine_map_repository_impl.dart';
import '../../data/sources/firestore_vending_machine_viewport_source.dart';
import '../../data/sources/vending_machine_viewport_source.dart';
import '../../domain/repositories/vending_machine_map_repository.dart';

final vendingMachineViewportSourceProvider =
    Provider<VendingMachineViewportSource>(
      (ref) =>
          FirestoreVendingMachineViewportSource(ref.watch(firestoreProvider)),
      name: 'vendingMachineViewportSourceProvider',
    );

final vendingMachineMapRepositoryProvider =
    Provider<VendingMachineMapRepository>(
      (ref) => VendingMachineMapRepositoryImpl(
        viewportSource: ref.watch(vendingMachineViewportSourceProvider),
        machineRepository: ref.watch(vendingMachineRepositoryProvider),
      ),
      name: 'vendingMachineMapRepositoryProvider',
    );
