import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/firebase/firebase_providers.dart';
import '../../../product_master/application/providers/product_master_providers.dart';
import '../../data/repositories/vending_machine_repository_impl.dart';
import '../../data/sources/firestore_vending_machine_document_source.dart';
import '../../data/sources/vending_machine_document_source.dart';
import '../../domain/repositories/vending_machine_repository.dart';

final vendingMachineDocumentSourceProvider =
    Provider<VendingMachineDocumentSource>(
      (ref) =>
          FirestoreVendingMachineDocumentSource(ref.watch(firestoreProvider)),
      name: 'vendingMachineDocumentSourceProvider',
    );

final vendingMachineRepositoryProvider = Provider<VendingMachineRepository>(
  (ref) => VendingMachineRepositoryImpl(
    source: ref.watch(vendingMachineDocumentSourceProvider),
    productRepository: ref.watch(productRepositoryProvider),
    manufacturerRepository: ref.watch(manufacturerRepositoryProvider),
  ),
  name: 'vendingMachineRepositoryProvider',
);
