import '../../../core/errors/app_failure.dart';
import '../../vending_machine/domain/entities/vending_machine.dart';
import '../../vending_machine/domain/value_objects/vending_machine_id.dart';
import '../domain/value_objects/map_viewport_bounds.dart';

final class VendingMachineMapState {
  const VendingMachineMapState({
    this.machines = const <VendingMachine>[],
    this.selectedMachineId,
    this.lastViewport,
    this.failure,
    this.isLoading = false,
    this.hasLoaded = false,
  });

  final List<VendingMachine> machines;
  final VendingMachineId? selectedMachineId;
  final MapViewportBounds? lastViewport;
  final AppFailure? failure;
  final bool isLoading;
  final bool hasLoaded;

  VendingMachine? get selectedMachine {
    final selectedId = selectedMachineId;
    if (selectedId == null) {
      return null;
    }

    for (final machine in machines) {
      if (machine.id == selectedId) {
        return machine;
      }
    }

    return null;
  }

  bool get isEmpty =>
      hasLoaded && !isLoading && failure == null && machines.isEmpty;

  VendingMachineMapState copyWith({
    List<VendingMachine>? machines,
    VendingMachineId? selectedMachineId,
    bool clearSelection = false,
    MapViewportBounds? lastViewport,
    AppFailure? failure,
    bool clearFailure = false,
    bool? isLoading,
    bool? hasLoaded,
  }) {
    return VendingMachineMapState(
      machines: machines ?? this.machines,
      selectedMachineId: clearSelection
          ? null
          : selectedMachineId ?? this.selectedMachineId,
      lastViewport: lastViewport ?? this.lastViewport,
      failure: clearFailure ? null : failure ?? this.failure,
      isLoading: isLoading ?? this.isLoading,
      hasLoaded: hasLoaded ?? this.hasLoaded,
    );
  }
}
