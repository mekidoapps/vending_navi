import '../../vending_machine/domain/entities/vending_machine_enums.dart';
import '../domain/models/machine_product_update_operation.dart';

final class MachineProductUpdateOriginalState {
  const MachineProductUpdateOriginalState({
    required this.productId,
    required this.evidenceType,
    required this.availability,
  });

  final String productId;
  final ProductEvidenceType? evidenceType;
  final ProductAvailability availability;

  bool get isConfirmed => evidenceType?.isConfirmed ?? false;
  bool get isInferred => evidenceType?.isInferred ?? false;
}

final class MachineProductUpdateEditSession {
  MachineProductUpdateEditSession({
    required Iterable<MachineProductUpdateOriginalState> currentProducts,
  }) : _original = <String, MachineProductUpdateOriginalState>{
         for (final product in currentProducts) product.productId: product,
       };

  final Map<String, MachineProductUpdateOriginalState> _original;
  final Set<String> _addedProductIds = <String>{};
  final Set<String> _confirmedInferredIds = <String>{};
  final Set<String> _deactivatedIds = <String>{};
  final Map<String, bool> _soldOutOverrides = <String, bool>{};

  bool get hasChanges => changedProductIds.isNotEmpty;

  Set<String> get addedProductIds => Set<String>.unmodifiable(_addedProductIds);

  Set<String> get changedProductIds {
    return <String>{
      ..._addedProductIds,
      ..._confirmedInferredIds,
      ..._deactivatedIds,
      ..._soldOutOverrides.keys,
    };
  }

  List<MachineProductUpdateOperation> get operations {
    final result = <MachineProductUpdateOperation>[];

    final ids = changedProductIds.toList()..sort();

    for (final productId in ids) {
      if (_deactivatedIds.contains(productId)) {
        result.add(
          MachineProductUpdateOperation.deactivate(productId: productId),
        );
        continue;
      }

      if (_addedProductIds.contains(productId)) {
        result.add(
          MachineProductUpdateOperation.addConfirmed(
            productId: productId,
            source: MachineProductUpdateSource.manual,
          ),
        );
      } else if (_confirmedInferredIds.contains(productId)) {
        result.add(
          MachineProductUpdateOperation.confirmInferred(productId: productId),
        );
      }

      final soldOutOverride = _soldOutOverrides[productId];
      if (soldOutOverride != null) {
        result.add(
          MachineProductUpdateOperation.setSoldOut(
            productId: productId,
            soldOut: soldOutOverride,
          ),
        );
      }
    }

    return List<MachineProductUpdateOperation>.unmodifiable(result);
  }

  bool addConfirmed(String productId) {
    final normalized = productId.trim();
    if (normalized.isEmpty || _original.containsKey(normalized)) {
      return false;
    }

    _addedProductIds.add(normalized);
    _deactivatedIds.remove(normalized);
    _confirmedInferredIds.remove(normalized);
    _soldOutOverrides.remove(normalized);
    return true;
  }

  bool confirmInferred(String productId) {
    final original = _original[productId];

    if (original == null ||
        !original.isInferred ||
        _deactivatedIds.contains(productId)) {
      return false;
    }

    _confirmedInferredIds.add(productId);
    return true;
  }

  bool setSoldOut(String productId, {required bool soldOut}) {
    if (_deactivatedIds.contains(productId)) {
      return false;
    }

    if (_addedProductIds.contains(productId)) {
      if (soldOut) {
        _soldOutOverrides[productId] = true;
      } else {
        _soldOutOverrides.remove(productId);
      }
      return true;
    }

    final original = _original[productId];
    if (original == null) {
      return false;
    }

    final effectivelyConfirmed =
        original.isConfirmed || _confirmedInferredIds.contains(productId);

    if (!effectivelyConfirmed) {
      return false;
    }

    final desiredAvailability = soldOut
        ? ProductAvailability.soldOut
        : ProductAvailability.available;

    final baselineAvailability = _confirmedInferredIds.contains(productId)
        ? ProductAvailability.available
        : original.availability;

    if (desiredAvailability == baselineAvailability) {
      _soldOutOverrides.remove(productId);
    } else {
      _soldOutOverrides[productId] = soldOut;
    }

    return true;
  }

  bool deactivate(String productId) {
    if (!_original.containsKey(productId)) {
      return false;
    }

    _deactivatedIds.add(productId);
    _confirmedInferredIds.remove(productId);
    _soldOutOverrides.remove(productId);
    return true;
  }

  void cancelChanges(String productId) {
    _addedProductIds.remove(productId);
    _confirmedInferredIds.remove(productId);
    _deactivatedIds.remove(productId);
    _soldOutOverrides.remove(productId);
  }

  bool hasPendingChange(String productId) {
    return changedProductIds.contains(productId);
  }

  bool isDeactivated(String productId) {
    return _deactivatedIds.contains(productId);
  }

  bool isEffectivelyConfirmed(String productId) {
    if (_addedProductIds.contains(productId)) {
      return true;
    }

    if (_confirmedInferredIds.contains(productId)) {
      return true;
    }

    return _original[productId]?.isConfirmed ?? false;
  }

  ProductAvailability effectiveAvailability(String productId) {
    final override = _soldOutOverrides[productId];
    if (override != null) {
      return override
          ? ProductAvailability.soldOut
          : ProductAvailability.available;
    }

    if (_addedProductIds.contains(productId)) {
      return ProductAvailability.available;
    }

    if (_confirmedInferredIds.contains(productId)) {
      return ProductAvailability.available;
    }

    return _original[productId]?.availability ?? ProductAvailability.unknown;
  }

  String? pendingLabel(String productId) {
    if (_deactivatedIds.contains(productId)) {
      return 'なくなったとして更新予定';
    }

    final labels = <String>[];

    if (_addedProductIds.contains(productId)) {
      labels.add('追加予定');
    } else if (_confirmedInferredIds.contains(productId)) {
      labels.add('確認済みに変更予定');
    }

    final soldOut = _soldOutOverrides[productId];
    if (soldOut != null) {
      labels.add(soldOut ? '売り切れに変更予定' : '販売中に変更予定');
    }

    return labels.isEmpty ? null : labels.join('・');
  }
}
