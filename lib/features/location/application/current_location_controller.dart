import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/failure_mapper.dart';
import '../domain/entities/app_location_permission.dart';
import '../domain/services/location_service.dart';
import 'current_location_state.dart';
import 'providers/location_service_provider.dart';

final currentLocationControllerProvider =
    NotifierProvider<CurrentLocationController, CurrentLocationState>(
      CurrentLocationController.new,
      name: 'currentLocationControllerProvider',
    );

final class CurrentLocationController extends Notifier<CurrentLocationState> {
  LocationService get _locationService => ref.read(locationServiceProvider);

  @override
  CurrentLocationState build() {
    return const CurrentLocationState.idle();
  }

  Future<void> locate({bool requestPermissionIfNeeded = true}) async {
    if (state.isLoading) {
      return;
    }

    state = const CurrentLocationState.loading();

    try {
      final serviceEnabled = await _locationService.isLocationServiceEnabled();

      if (!serviceEnabled) {
        state = const CurrentLocationState.serviceDisabled();
        return;
      }

      var permission = await _locationService.checkPermission();

      if (permission == AppLocationPermission.denied &&
          requestPermissionIfNeeded) {
        permission = await _locationService.requestPermission();
      }

      switch (permission) {
        case AppLocationPermission.denied:
          state = const CurrentLocationState.permissionDenied();
          return;

        case AppLocationPermission.deniedForever:
          state = const CurrentLocationState.permissionDeniedForever();
          return;

        case AppLocationPermission.unableToDetermine:
          state = const CurrentLocationState.permissionUnableToDetermine();
          return;

        case AppLocationPermission.whileInUse:
        case AppLocationPermission.always:
          break;
      }

      final result = await _locationService.getCurrentLocation();

      state = result.fold(
        onSuccess: CurrentLocationState.ready,
        onFailure: CurrentLocationState.failed,
      );
    } on Object catch (error) {
      state = CurrentLocationState.failed(FailureMapper.map(error));
    }
  }

  Future<void> retry() {
    return locate();
  }

  Future<bool> openRelevantSettings() async {
    try {
      return switch (state.phase) {
        CurrentLocationPhase.serviceDisabled =>
          _locationService.openLocationSettings(),
        CurrentLocationPhase.permissionDeniedForever =>
          _locationService.openAppSettings(),
        _ => Future<bool>.value(false),
      };
    } on Object {
      return false;
    }
  }
}
