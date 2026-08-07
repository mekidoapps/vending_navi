import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/firebase/firebase_providers.dart';
import '../../data/repositories/manufacturer_repository_impl.dart';
import '../../data/repositories/product_repository_impl.dart';
import '../../data/sources/firestore_master_document_source.dart';
import '../../data/sources/master_document_source.dart';
import '../../domain/repositories/manufacturer_repository.dart';
import '../../domain/repositories/product_repository.dart';

final masterDocumentSourceProvider = Provider<MasterDocumentSource>(
  (ref) => FirestoreMasterDocumentSource(ref.watch(firestoreProvider)),
  name: 'masterDocumentSourceProvider',
);

final productRepositoryProvider = Provider<ProductRepository>(
  (ref) => ProductRepositoryImpl(ref.watch(masterDocumentSourceProvider)),
  name: 'productRepositoryProvider',
);

final manufacturerRepositoryProvider = Provider<ManufacturerRepository>(
  (ref) => ManufacturerRepositoryImpl(ref.watch(masterDocumentSourceProvider)),
  name: 'manufacturerRepositoryProvider',
);
