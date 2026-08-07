import '../../domain/entities/manufacturer.dart';
import '../../domain/entities/product.dart';
import '../../domain/value_objects/master_id.dart';
import 'legacy_master_resolution.dart';
import 'legacy_name_normalizer.dart';
import 'legacy_product_candidate.dart';

abstract final class LegacyMasterResolver {
  static LegacyResolvedManufacturer resolveManufacturer({
    required String? legacyName,
    required Iterable<Manufacturer> manufacturers,
    Map<String, ManufacturerId> manualAliases =
        const <String, ManufacturerId>{},
  }) {
    final raw = legacyName?.trim();
    if (raw == null || raw.isEmpty || _isUnknownManufacturerToken(raw)) {
      return LegacyResolvedManufacturer(
        rawName: legacyName,
        manufacturerId: null,
        kind: LegacyManufacturerResolutionKind.unresolved,
      );
    }

    final byId = ManufacturerId.tryParse(raw);
    if (byId != null && _containsManufacturerId(manufacturers, byId)) {
      return LegacyResolvedManufacturer(
        rawName: raw,
        manufacturerId: byId,
        kind: LegacyManufacturerResolutionKind.exactId,
      );
    }

    final normalized = LegacyNameNormalizer.normalize(raw);
    final nameMatches = manufacturers
        .where((manufacturer) {
          return LegacyNameNormalizer.normalize(manufacturer.name) ==
                  normalized ||
              LegacyNameNormalizer.normalize(manufacturer.displayShortName) ==
                  normalized;
        })
        .toList(growable: false);
    if (nameMatches.length == 1) {
      return LegacyResolvedManufacturer(
        rawName: raw,
        manufacturerId: nameMatches.single.id,
        kind: LegacyManufacturerResolutionKind.normalizedName,
      );
    }

    final aliasedId = _findManufacturerAlias(raw, manualAliases);
    if (aliasedId != null &&
        _containsManufacturerId(manufacturers, aliasedId)) {
      return LegacyResolvedManufacturer(
        rawName: raw,
        manufacturerId: aliasedId,
        kind: LegacyManufacturerResolutionKind.manualAlias,
      );
    }

    return LegacyResolvedManufacturer(
      rawName: raw,
      manufacturerId: null,
      kind: LegacyManufacturerResolutionKind.unresolved,
    );
  }

  static LegacyResolvedProduct resolveProduct({
    required LegacyProductCandidate candidate,
    required Iterable<Product> products,
    required LegacyResolvedManufacturer manufacturer,
    Map<String, ProductId> manualAliases = const <String, ProductId>{},
  }) {
    final catalog = products.toList(growable: false);
    final rawExplicitId = candidate.explicitProductId?.trim();

    if (rawExplicitId != null && rawExplicitId.isNotEmpty) {
      final exactId = ProductId.tryParse(rawExplicitId);
      if (exactId != null && _containsProductId(catalog, exactId)) {
        return _resolvedProduct(
          candidate,
          exactId,
          LegacyProductResolutionKind.exactId,
        );
      }
    }

    final normalizedName = LegacyNameNormalizer.normalize(candidate.rawName);
    final nameMatches = catalog
        .where((product) {
          return LegacyNameNormalizer.normalize(product.name) == normalizedName;
        })
        .toList(growable: false);

    if (nameMatches.length == 1) {
      return _resolvedProduct(
        candidate,
        nameMatches.single.id,
        LegacyProductResolutionKind.normalizedName,
      );
    }

    final manufacturerId = manufacturer.manufacturerId;
    if (manufacturerId != null) {
      final manufacturerMatches = nameMatches
          .where((product) {
            return product.manufacturerId == manufacturerId;
          })
          .toList(growable: false);
      if (manufacturerMatches.length == 1) {
        return _resolvedProduct(
          candidate,
          manufacturerMatches.single.id,
          LegacyProductResolutionKind.manufacturerAndName,
        );
      }
    }

    final aliasedId = _findProductAlias(
      candidate: candidate,
      manufacturer: manufacturer,
      aliases: manualAliases,
    );
    if (aliasedId != null && _containsProductId(catalog, aliasedId)) {
      return _resolvedProduct(
        candidate,
        aliasedId,
        LegacyProductResolutionKind.manualAlias,
      );
    }

    return LegacyResolvedProduct(
      rawName: candidate.rawName,
      productId: null,
      kind: LegacyProductResolutionKind.unresolved,
      source: candidate.source,
      tags: candidate.tags,
      isSoldOut: candidate.isSoldOut,
    );
  }

  static LegacyResolvedProduct _resolvedProduct(
    LegacyProductCandidate candidate,
    ProductId productId,
    LegacyProductResolutionKind kind,
  ) {
    return LegacyResolvedProduct(
      rawName: candidate.rawName,
      productId: productId,
      kind: kind,
      source: candidate.source,
      tags: candidate.tags,
      isSoldOut: candidate.isSoldOut,
    );
  }

  static bool _containsManufacturerId(
    Iterable<Manufacturer> manufacturers,
    ManufacturerId id,
  ) {
    return manufacturers.any((manufacturer) => manufacturer.id == id);
  }

  static bool _containsProductId(Iterable<Product> products, ProductId id) {
    return products.any((product) => product.id == id);
  }

  static ManufacturerId? _findManufacturerAlias(
    String raw,
    Map<String, ManufacturerId> aliases,
  ) {
    final normalized = LegacyNameNormalizer.normalize(raw);
    for (final entry in aliases.entries) {
      if (LegacyNameNormalizer.normalize(entry.key) == normalized) {
        return entry.value;
      }
    }
    return null;
  }

  static ProductId? _findProductAlias({
    required LegacyProductCandidate candidate,
    required LegacyResolvedManufacturer manufacturer,
    required Map<String, ProductId> aliases,
  }) {
    final keys = <String>{LegacyNameNormalizer.normalize(candidate.rawName)};
    final explicitId = candidate.explicitProductId;
    if (explicitId != null) {
      keys.add(LegacyNameNormalizer.normalize(explicitId));
    }
    final manufacturerName = manufacturer.rawName;
    if (manufacturerName != null) {
      keys.add(
        LegacyNameNormalizer.normalize(
          '$manufacturerName|${candidate.rawName}',
        ),
      );
    }

    for (final entry in aliases.entries) {
      if (keys.contains(LegacyNameNormalizer.normalize(entry.key))) {
        return entry.value;
      }
    }
    return null;
  }

  static bool _isUnknownManufacturerToken(String raw) {
    final normalized = LegacyNameNormalizer.normalize(raw);
    return const <String>{
      '不明',
      '未設定',
      'unknown',
      'none',
      'null',
    }.contains(normalized);
  }
}
