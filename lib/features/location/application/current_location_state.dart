import '../../../core/errors/app_failure.dart';
import '../domain/entities/current_location.dart';

enum CurrentLocationPhase {
  idle,
  loading,
  ready,
  serviceDisabled,
  permissionDenied,
  permissionDeniedForever,
  permissionUnableToDetermine,
  failed,
}

final class CurrentLocationState {
  const CurrentLocationState._({
    required this.phase,
    this.location,
    this.failure,
  });

  const CurrentLocationState.idle() : this._(phase: CurrentLocationPhase.idle);

  const CurrentLocationState.loading()
    : this._(phase: CurrentLocationPhase.loading);

  const CurrentLocationState.ready(CurrentLocation location)
    : this._(phase: CurrentLocationPhase.ready, location: location);

  const CurrentLocationState.serviceDisabled()
    : this._(phase: CurrentLocationPhase.serviceDisabled);

  const CurrentLocationState.permissionDenied()
    : this._(phase: CurrentLocationPhase.permissionDenied);

  const CurrentLocationState.permissionDeniedForever()
    : this._(phase: CurrentLocationPhase.permissionDeniedForever);

  const CurrentLocationState.permissionUnableToDetermine()
    : this._(phase: CurrentLocationPhase.permissionUnableToDetermine);

  const CurrentLocationState.failed(AppFailure failure)
    : this._(phase: CurrentLocationPhase.failed, failure: failure);

  final CurrentLocationPhase phase;
  final CurrentLocation? location;
  final AppFailure? failure;

  bool get isLoading => phase == CurrentLocationPhase.loading;

  bool get hasLocation =>
      phase == CurrentLocationPhase.ready && location != null;

  bool get shouldOpenAppSettings =>
      phase == CurrentLocationPhase.permissionDeniedForever;

  bool get shouldOpenLocationSettings =>
      phase == CurrentLocationPhase.serviceDisabled;
}
