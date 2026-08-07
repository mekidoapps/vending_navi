import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/failure_mapper.dart';
import '../../vending_machine/domain/value_objects/vending_machine_id.dart';
import '../domain/repositories/vending_machine_map_repository.dart';
import '../domain/value_objects/map_viewport_bounds.dart';
import 'providers/vending_machine_map_providers.dart';
import 'vending_machine_map_state.dart';

final vendingMachineMapControllerProvider =
    NotifierProvider<VendingMachineMapController, VendingMachineMapState>(
      VendingMachineMapController.new,
      name: 'vendingMachineMapControllerProvider',
    );

final class VendingMachineMapController
    extends Notifier<VendingMachineMapState> {
  var _requestSerial = 0;

  VendingMachineMapRepository get _repository =>
      ref.read(vendingMachineMapRepositoryProvider);

  @override
  VendingMachineMapState build() {
    return const VendingMachineMapState();
  }

  Future<void> loadViewport(
    MapViewportBounds bounds, {
    bool force = false,
  }) async {
    final previousViewport = state.lastViewport;
    if (!force &&
        previousViewport != null &&
        previousViewport.roughlyEquals(bounds) &&
        state.hasLoaded &&
        !state.isLoading) {
      return;
    }

    final requestId = ++_requestSerial;

    state = state.copyWith(
      lastViewport: bounds,
      isLoading: true,
      clearFailure: true,
    );

    try {
      final result = await _repository.getMachinesInViewport(bounds);

      if (requestId != _requestSerial) {
        return;
      }

      final failure = result.failureOrNull;
      if (failure != null) {
        state = state.copyWith(
          failure: failure,
          isLoading: false,
          hasLoaded: true,
        );
        return;
      }

      final machines = result.valueOrNull ?? const [];
      final selectedId = state.selectedMachineId;
      final selectionStillVisible =
          selectedId != null &&
          machines.any((machine) => machine.id == selectedId);

      state = state.copyWith(
        machines: machines,
        clearSelection: !selectionStillVisible,
        isLoading: false,
        hasLoaded: true,
        clearFailure: true,
      );
    } on Object catch (error) {
      if (requestId != _requestSerial) {
        return;
      }

      state = state.copyWith(
        failure: FailureMapper.map(error),
        isLoading: false,
        hasLoaded: true,
      );
    }
  }

  void selectMachine(VendingMachineId id) {
    if (!state.machines.any((machine) => machine.id == id)) {
      return;
    }

    state = state.copyWith(selectedMachineId: id);
  }

  void clearSelection() {
    state = state.copyWith(clearSelection: true);
  }

  Future<void> retry() async {
    final viewport = state.lastViewport;
    if (viewport == null) {
      return;
    }

    await loadViewport(viewport, force: true);
  }
}
