import '../../../../core/errors/app_failure.dart';
import '../../../../core/errors/failure_mapper.dart';
import '../../../../core/result/app_result.dart';
import '../../../product_master/data/legacy/legacy_master_aliases.dart';
import '../../../product_master/data/legacy/legacy_vending_machine_compatibility_mapper.dart';
import '../../../product_master/domain/entities/manufacturer.dart';
import '../../../product_master/domain/entities/product.dart';
import '../../../product_master/domain/repositories/manufacturer_repository.dart';
import '../../../product_master/domain/repositories/product_repository.dart';
import '../../domain/entities/vending_machine.dart';
import '../../domain/entities/vending_machine_product.dart';
import '../../domain/models/vending_machine_read_batch.dart';
import '../../domain/repositories/vending_machine_repository.dart';
import '../../domain/value_objects/vending_machine_id.dart';
import '../legacy/legacy_vending_machine_domain_bridge.dart';
import '../mappers/vending_machine_mapper.dart';
import '../mappers/vending_machine_product_mapper.dart';
import '../sources/vending_machine_document.dart';
import '../sources/vending_machine_document_source.dart';

final class VendingMachineRepositoryImpl implements VendingMachineRepository {
  VendingMachineRepositoryImpl({
    required VendingMachineDocumentSource source,
    required ProductRepository productRepository,
    required ManufacturerRepository manufacturerRepository,
  }) : _source = source,
       _productRepository = productRepository,
       _manufacturerRepository = manufacturerRepository;

  final VendingMachineDocumentSource _source;
  final ProductRepository _productRepository;
  final ManufacturerRepository _manufacturerRepository;

  @override
  Future<AppResult<VendingMachine>> getMachine(VendingMachineId id) async {
    try {
      final document = await _source.fetchMachineDocument(id.value);
      if (document == null) {
        return const AppResult<VendingMachine>.failure(NotFoundFailure());
      }

      if (_isV2Document(document)) {
        return _mapV2Machine(document);
      }

      final catalogResult = await _loadLegacyCatalog();
      final catalogFailure = catalogResult.failureOrNull;
      if (catalogFailure != null) {
        return AppResult<VendingMachine>.failure(catalogFailure);
      }

      final catalog = catalogResult.valueOrNull;
      if (catalog == null) {
        return const AppResult<VendingMachine>.failure(UnknownFailure());
      }

      return _mapLegacyMachine(
        document,
        catalog,
      ).map((bridge) => bridge.machine);
    } on Object catch (error) {
      return AppResult<VendingMachine>.failure(FailureMapper.map(error));
    }
  }

  @override
  Future<AppResult<VendingMachineReadBatch>> getCompatibilitySnapshot() async {
    try {
      final documents = await _source.fetchMachineDocuments();
      final hasLegacy = documents.any((document) => !_isV2Document(document));

      _LegacyCatalog? legacyCatalog;
      if (hasLegacy) {
        final catalogResult = await _loadLegacyCatalog();
        final catalogFailure = catalogResult.failureOrNull;
        if (catalogFailure != null) {
          return AppResult<VendingMachineReadBatch>.failure(catalogFailure);
        }
        legacyCatalog = catalogResult.valueOrNull;
        if (legacyCatalog == null) {
          return const AppResult<VendingMachineReadBatch>.failure(
            UnknownFailure(),
          );
        }
      }

      final machines = <VendingMachine>[];
      var skippedLegacyWithoutLocation = 0;
      var unresolvedLegacyProductCount = 0;

      for (final document in documents) {
        if (_isV2Document(document)) {
          final mapped = await _mapV2Machine(document);
          final failure = mapped.failureOrNull;
          if (failure != null) {
            return AppResult<VendingMachineReadBatch>.failure(failure);
          }

          final machine = mapped.valueOrNull;
          if (machine == null) {
            return const AppResult<VendingMachineReadBatch>.failure(
              UnknownFailure(),
            );
          }

          machines.add(machine);
          continue;
        }

        final catalog = legacyCatalog;
        if (catalog == null) {
          return const AppResult<VendingMachineReadBatch>.failure(
            UnknownFailure(),
          );
        }

        final mapped = _mapLegacyMachine(document, catalog);
        final failure = mapped.failureOrNull;

        if (failure is ValidationFailure &&
            failure.field == 'legacyVendingMachine.location') {
          skippedLegacyWithoutLocation += 1;
          continue;
        }

        if (failure != null) {
          return AppResult<VendingMachineReadBatch>.failure(failure);
        }

        final bridge = mapped.valueOrNull;
        if (bridge == null) {
          return const AppResult<VendingMachineReadBatch>.failure(
            UnknownFailure(),
          );
        }

        machines.add(bridge.machine);
        unresolvedLegacyProductCount += bridge.unresolvedProductCount;
      }

      return AppResult<VendingMachineReadBatch>.success(
        VendingMachineReadBatch(
          machines: List<VendingMachine>.unmodifiable(machines),
          skippedLegacyWithoutLocation: skippedLegacyWithoutLocation,
          unresolvedLegacyProductCount: unresolvedLegacyProductCount,
        ),
      );
    } on Object catch (error) {
      return AppResult<VendingMachineReadBatch>.failure(
        FailureMapper.map(error),
      );
    }
  }

  Future<AppResult<VendingMachine>> _mapV2Machine(
    VendingMachineDocument document,
  ) async {
    final rootResult = VendingMachineMapper.fromFirestoreDocument(
      documentId: document.id,
      data: document.data,
    );
    final rootFailure = rootResult.failureOrNull;
    if (rootFailure != null) {
      return AppResult<VendingMachine>.failure(rootFailure);
    }

    final root = rootResult.valueOrNull;
    if (root == null) {
      return const AppResult<VendingMachine>.failure(UnknownFailure());
    }

    final productDocuments = await _source.fetchProductDocuments(document.id);
    final products = <VendingMachineProduct>[];

    for (final productDocument in productDocuments) {
      final productResult = VendingMachineProductMapper.fromFirestoreDocument(
        documentId: productDocument.id,
        data: productDocument.data,
      );
      final failure = productResult.failureOrNull;
      if (failure != null) {
        return AppResult<VendingMachine>.failure(failure);
      }

      final product = productResult.valueOrNull;
      if (product == null) {
        return const AppResult<VendingMachine>.failure(UnknownFailure());
      }

      products.add(product);
    }

    return AppResult<VendingMachine>.success(
      root.copyWith(
        products: List<VendingMachineProduct>.unmodifiable(products),
      ),
    );
  }

  AppResult<LegacyVendingMachineBridgeResult> _mapLegacyMachine(
    VendingMachineDocument document,
    _LegacyCatalog catalog,
  ) {
    final compatibility =
        LegacyVendingMachineCompatibilityMapper.fromDocumentData(
          documentId: document.id,
          data: document.data,
          products: catalog.products,
          manufacturers: catalog.manufacturers,
          productAliases: LegacyMasterAliases.productAliases,
          manufacturerAliases: LegacyMasterAliases.manufacturerAliases,
        );

    final failure = compatibility.failureOrNull;
    if (failure != null) {
      return AppResult<LegacyVendingMachineBridgeResult>.failure(failure);
    }

    final legacy = compatibility.valueOrNull;
    if (legacy == null) {
      return const AppResult<LegacyVendingMachineBridgeResult>.failure(
        UnknownFailure(),
      );
    }

    return LegacyVendingMachineDomainBridge.toDomain(legacy);
  }

  Future<AppResult<_LegacyCatalog>> _loadLegacyCatalog() async {
    final productResult = await _productRepository.getProducts();
    final productFailure = productResult.failureOrNull;
    if (productFailure != null) {
      return AppResult<_LegacyCatalog>.failure(productFailure);
    }

    final manufacturerResult = await _manufacturerRepository.getManufacturers();
    final manufacturerFailure = manufacturerResult.failureOrNull;
    if (manufacturerFailure != null) {
      return AppResult<_LegacyCatalog>.failure(manufacturerFailure);
    }

    final products = productResult.valueOrNull;
    final manufacturers = manufacturerResult.valueOrNull;
    if (products == null || manufacturers == null) {
      return const AppResult<_LegacyCatalog>.failure(UnknownFailure());
    }

    return AppResult<_LegacyCatalog>.success(
      _LegacyCatalog(products: products, manufacturers: manufacturers),
    );
  }

  static bool _isV2Document(VendingMachineDocument document) {
    final schemaVersion = document.data['schemaVersion'];
    return switch (schemaVersion) {
      num value => value >= 2,
      String value => (int.tryParse(value.trim()) ?? 1) >= 2,
      _ => false,
    };
  }
}

final class _LegacyCatalog {
  const _LegacyCatalog({required this.products, required this.manufacturers});

  final List<Product> products;
  final List<Manufacturer> manufacturers;
}
