import '../../../../core/result/app_result.dart';
import '../../../home_map/domain/value_objects/map_viewport_bounds.dart';
import '../../../product_master/domain/entities/product_genre.dart';
import '../../../product_master/domain/repositories/product_repository.dart';
import '../../../product_master/domain/value_objects/master_id.dart';
import '../entities/machine_product_index_entry.dart';
import '../models/genre_machine_search_result.dart';
import '../repositories/machine_product_index_repository.dart';

final class GenreMachineSearchService {
  const GenreMachineSearchService({
    required ProductRepository productRepository,
    required MachineProductIndexRepository machineProductIndexRepository,
  }) : _productRepository = productRepository,
       _machineProductIndexRepository = machineProductIndexRepository;

  final ProductRepository _productRepository;
  final MachineProductIndexRepository _machineProductIndexRepository;

  Future<AppResult<GenreMachineSearchResult>> search({
    required ProductGenre genre,
    required MapViewportBounds viewport,
  }) async {
    final productsResult = await _productRepository.getProducts();
    final productFailure = productsResult.failureOrNull;
    if (productFailure != null) {
      return AppResult<GenreMachineSearchResult>.failure(productFailure);
    }

    final productIds = <ProductId>{
      for (final product in productsResult.valueOrNull ?? const [])
        if (product.isSelectable && product.genres.contains(genre)) product.id,
    };

    if (productIds.isEmpty) {
      return AppResult<GenreMachineSearchResult>.success(
        GenreMachineSearchResult(
          productIds: const <ProductId>{},
          entries: const <MachineProductIndexEntry>[],
        ),
      );
    }

    final indexResults = await Future.wait(
      productIds.map(
        (productId) => _machineProductIndexRepository.findByProductInViewport(
          productId: productId,
          viewport: viewport,
        ),
      ),
    );

    final entriesByMachine = <String, MachineProductIndexEntry>{};

    for (final result in indexResults) {
      final failure = result.failureOrNull;
      if (failure != null) {
        return AppResult<GenreMachineSearchResult>.failure(failure);
      }

      for (final entry
          in result.valueOrNull ?? const <MachineProductIndexEntry>[]) {
        final key = entry.machineId.value;
        final previous = entriesByMachine[key];

        if (previous == null ||
            _evidencePriority(entry) > _evidencePriority(previous)) {
          entriesByMachine[key] = entry;
        }
      }
    }

    final entries = entriesByMachine.values.toList(growable: false)
      ..sort(
        (left, right) => left.machineId.value.compareTo(right.machineId.value),
      );

    return AppResult<GenreMachineSearchResult>.success(
      GenreMachineSearchResult(
        productIds: Set<ProductId>.unmodifiable(productIds),
        entries: List<MachineProductIndexEntry>.unmodifiable(entries),
      ),
    );
  }

  static int _evidencePriority(MachineProductIndexEntry entry) {
    if (entry.isConfirmed) {
      return 2;
    }
    if (entry.isInferred) {
      return 1;
    }
    return 0;
  }
}
