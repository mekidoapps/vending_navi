import '../../domain/value_objects/master_id.dart';
import 'legacy_product_candidate.dart';

enum LegacyManufacturerResolutionKind {
  exactId,
  normalizedName,
  manualAlias,
  unresolved,
}

final class LegacyResolvedManufacturer {
  const LegacyResolvedManufacturer({
    required this.rawName,
    required this.manufacturerId,
    required this.kind,
  });

  final String? rawName;
  final ManufacturerId? manufacturerId;
  final LegacyManufacturerResolutionKind kind;

  bool get isResolved => manufacturerId != null;
}

enum LegacyProductResolutionKind {
  exactId,
  normalizedName,
  manufacturerAndName,
  manualAlias,
  unresolved,
}

final class LegacyResolvedProduct {
  const LegacyResolvedProduct({
    required this.rawName,
    required this.productId,
    required this.kind,
    required this.source,
    required this.tags,
    required this.isSoldOut,
  });

  final String rawName;
  final ProductId? productId;
  final LegacyProductResolutionKind kind;
  final LegacyProductSource source;
  final List<String> tags;
  final bool isSoldOut;

  bool get isResolved => productId != null;
}
