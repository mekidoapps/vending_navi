import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vending_app/core/errors/app_failure.dart';
import 'package:vending_app/core/result/app_result.dart';
import 'package:vending_app/features/location/application/current_location_controller.dart';
import 'package:vending_app/features/location/application/current_location_state.dart';
import 'package:vending_app/features/location/application/providers/location_service_provider.dart';
import 'package:vending_app/features/location/domain/entities/app_location_permission.dart';
import 'package:vending_app/features/location/domain/entities/current_location.dart';
import 'package:vending_app/features/location/domain/services/location_service.dart';

void main() {
  group('CurrentLocationController', () {
    test('位置情報サービスOFFではpermissionを確認しない', () async {
      final service = _FakeLocationService(serviceEnabled: false);
      final container = _container(service);
      addTearDown(container.dispose);

      await container.read(currentLocationControllerProvider.notifier).locate();

      final state = container.read(currentLocationControllerProvider);

      expect(state.phase, CurrentLocationPhase.serviceDisabled);
      expect(service.checkPermissionCalls, 0);
      expect(service.getLocationCalls, 0);
    });

    test('deniedは1回だけrequestし再度deniedなら拒否状態にする', () async {
      final service = _FakeLocationService(
        permission: AppLocationPermission.denied,
        requestedPermission: AppLocationPermission.denied,
      );
      final container = _container(service);
      addTearDown(container.dispose);

      await container.read(currentLocationControllerProvider.notifier).locate();

      final state = container.read(currentLocationControllerProvider);

      expect(state.phase, CurrentLocationPhase.permissionDenied);
      expect(service.requestPermissionCalls, 1);
      expect(service.getLocationCalls, 0);
    });

    test('deniedForeverは権限requestを繰り返さず設定画面対象にする', () async {
      final service = _FakeLocationService(
        permission: AppLocationPermission.deniedForever,
      );
      final container = _container(service);
      addTearDown(container.dispose);

      final controller = container.read(
        currentLocationControllerProvider.notifier,
      );
      await controller.locate();

      final state = container.read(currentLocationControllerProvider);
      expect(state.phase, CurrentLocationPhase.permissionDeniedForever);
      expect(state.shouldOpenAppSettings, isTrue);
      expect(service.requestPermissionCalls, 0);

      expect(await controller.openRelevantSettings(), isTrue);
      expect(service.openAppSettingsCalls, 1);
    });

    test('サービスOFFでは位置設定画面を開く', () async {
      final service = _FakeLocationService(serviceEnabled: false);
      final container = _container(service);
      addTearDown(container.dispose);

      final controller = container.read(
        currentLocationControllerProvider.notifier,
      );
      await controller.locate();

      expect(await controller.openRelevantSettings(), isTrue);
      expect(service.openLocationSettingsCalls, 1);
    });

    test('whileInUseでは現在地取得成功をreadyへ反映する', () async {
      final location = CurrentLocation(
        latitude: 35.681236,
        longitude: 139.767125,
        accuracyMeters: 12,
        capturedAt: DateTime.utc(2026, 8, 7),
      );
      final service = _FakeLocationService(
        permission: AppLocationPermission.whileInUse,
        locationResult: AppResult<CurrentLocation>.success(location),
      );
      final container = _container(service);
      addTearDown(container.dispose);

      await container.read(currentLocationControllerProvider.notifier).locate();

      final state = container.read(currentLocationControllerProvider);
      expect(state.phase, CurrentLocationPhase.ready);
      expect(state.location, location);
      expect(service.getLocationCalls, 1);
    });

    test('現在地取得Failureをfailedへ保持する', () async {
      final service = _FakeLocationService(
        permission: AppLocationPermission.always,
        locationResult: const AppResult<CurrentLocation>.failure(
          LocationUnavailableFailure(),
        ),
      );
      final container = _container(service);
      addTearDown(container.dispose);

      await container.read(currentLocationControllerProvider.notifier).locate();

      final state = container.read(currentLocationControllerProvider);
      expect(state.phase, CurrentLocationPhase.failed);
      expect(state.failure, isA<LocationUnavailableFailure>());
    });

    test('requestPermissionIfNeeded=falseではdenied時にrequestしない', () async {
      final service = _FakeLocationService(
        permission: AppLocationPermission.denied,
      );
      final container = _container(service);
      addTearDown(container.dispose);

      await container
          .read(currentLocationControllerProvider.notifier)
          .locate(requestPermissionIfNeeded: false);

      final state = container.read(currentLocationControllerProvider);
      expect(state.phase, CurrentLocationPhase.permissionDenied);
      expect(service.requestPermissionCalls, 0);
    });

    test('unableToDetermineを別状態として保持する', () async {
      final service = _FakeLocationService(
        permission: AppLocationPermission.unableToDetermine,
      );
      final container = _container(service);
      addTearDown(container.dispose);

      await container.read(currentLocationControllerProvider.notifier).locate();

      expect(
        container.read(currentLocationControllerProvider).phase,
        CurrentLocationPhase.permissionUnableToDetermine,
      );
    });
  });
}

ProviderContainer _container(LocationService service) {
  return ProviderContainer(
    overrides: [locationServiceProvider.overrideWithValue(service)],
  );
}

final class _FakeLocationService implements LocationService {
  _FakeLocationService({
    this.serviceEnabled = true,
    this.permission = AppLocationPermission.whileInUse,
    AppLocationPermission? requestedPermission,
    AppResult<CurrentLocation>? locationResult,
  }) : requestedPermission = requestedPermission ?? permission,
       locationResult =
           locationResult ??
           AppResult<CurrentLocation>.success(
             CurrentLocation(
               latitude: 35.681236,
               longitude: 139.767125,
               accuracyMeters: 10,
               capturedAt: DateTime.utc(2026, 8, 7),
             ),
           );

  final bool serviceEnabled;
  final AppLocationPermission permission;
  final AppLocationPermission requestedPermission;
  final AppResult<CurrentLocation> locationResult;

  int checkPermissionCalls = 0;
  int requestPermissionCalls = 0;
  int getLocationCalls = 0;
  int openAppSettingsCalls = 0;
  int openLocationSettingsCalls = 0;

  @override
  Future<bool> isLocationServiceEnabled() async => serviceEnabled;

  @override
  Future<AppLocationPermission> checkPermission() async {
    checkPermissionCalls += 1;
    return permission;
  }

  @override
  Future<AppLocationPermission> requestPermission() async {
    requestPermissionCalls += 1;
    return requestedPermission;
  }

  @override
  Future<AppResult<CurrentLocation>> getCurrentLocation() async {
    getLocationCalls += 1;
    return locationResult;
  }

  @override
  Future<bool> openAppSettings() async {
    openAppSettingsCalls += 1;
    return true;
  }

  @override
  Future<bool> openLocationSettings() async {
    openLocationSettingsCalls += 1;
    return true;
  }
}
