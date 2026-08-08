import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../product_master/application/providers/product_master_providers.dart';
import '../../domain/services/genre_machine_search_service.dart';
import 'machine_product_index_providers.dart';

final genreMachineSearchServiceProvider = Provider<GenreMachineSearchService>(
  (ref) => GenreMachineSearchService(
    productRepository: ref.watch(productRepositoryProvider),
    machineProductIndexRepository: ref.watch(
      machineProductIndexRepositoryProvider,
    ),
  ),
  name: 'genreMachineSearchServiceProvider',
);
