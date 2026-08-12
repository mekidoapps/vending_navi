import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../product_master/application/providers/product_master_providers.dart';
import '../../product_master/domain/entities/manufacturer.dart';
import 'manufacturer_selection_state.dart';

final manufacturerSelectionControllerProvider =
    NotifierProvider<
      ManufacturerSelectionController,
      ManufacturerSelectionState
    >(
      ManufacturerSelectionController.new,
      name: 'manufacturerSelectionControllerProvider',
    );

final class ManufacturerSelectionController
    extends Notifier<ManufacturerSelectionState> {
  var _requestSerial = 0;

  @override
  ManufacturerSelectionState build() {
    return const ManufacturerSelectionState();
  }

  Future<void> load() async {
    final requestId = ++_requestSerial;

    state = state.copyWith(isLoading: true, clearFailure: true);

    final result = await ref
        .read(manufacturerRepositoryProvider)
        .getManufacturers(activeOnly: true);

    if (requestId != _requestSerial) {
      return;
    }

    final failure = result.failureOrNull;
    if (failure != null) {
      state = state.copyWith(
        manufacturers: const <Manufacturer>[],
        isLoading: false,
        hasLoaded: true,
        failure: failure,
      );
      return;
    }

    final manufacturers =
        (result.valueOrNull ?? const <Manufacturer>[])
            .where((manufacturer) => manufacturer.isSelectable)
            .toList(growable: false)
          ..sort(
            (left, right) =>
                left.displayShortName.compareTo(right.displayShortName),
          );

    state = state.copyWith(
      manufacturers: List<Manufacturer>.unmodifiable(manufacturers),
      isLoading: false,
      hasLoaded: true,
      clearFailure: true,
    );
  }

  Future<void> retry() => load();

  void reset() {
    _requestSerial += 1;
    state = const ManufacturerSelectionState();
  }
}
