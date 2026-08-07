import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../product_master/application/providers/product_master_providers.dart';
import '../../domain/services/product_candidate_search_service.dart';

final productCandidateSearchServiceProvider =
    Provider<ProductCandidateSearchService>(
      (ref) => ProductCandidateSearchService(
        productRepository: ref.watch(productRepositoryProvider),
      ),
      name: 'productCandidateSearchServiceProvider',
    );
