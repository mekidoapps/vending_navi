import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:vending_app/features/location/application/providers/location_service_provider.dart';
import 'package:vending_app/features/location/domain/entities/app_location_permission.dart';
import 'package:vending_app/features/location/domain/entities/current_location.dart';
import 'package:vending_app/features/location/domain/services/location_service.dart';
import 'package:vending_app/features/machine_registration/application/machine_registration_controller.dart';
import 'package:vending_app/features/machine_registration/presentation/v2_registration_position_screen.dart';
import 'package:vending_app/core/result/app_result.dart';
import 'package:vending_app/features/vending_machine/domain/value_objects/geo_coordinate.dart';

void main() {
  testWidgets('地図中心を選ぶと次へ進める', (WidgetTester tester) async {
    var continued = false;

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          locationServiceProvider.overrideWithValue(_FakeLocationService()),
        ],
        child: MaterialApp(
          home: V2RegistrationPositionScreen(
            autoLocate: false,
            mapBuilder: (_, initialTarget, onCameraMove, onCameraIdle) {
              return Center(
                child: FilledButton(
                  key: const Key('fakeMoveMap'),
                  onPressed: () {
                    onCameraMove(const LatLng(35.68123, 139.76789));
                    onCameraIdle();
                  },
                  child: const Text('move'),
                ),
              );
            },
            onContinue: () {
              continued = true;
            },
          ),
        ),
      ),
    );

    expect(
      tester
          .widget<FilledButton>(
            find.byKey(const Key('registrationPositionContinueButton')),
          )
          .onPressed,
      isNull,
    );

    await tester.tap(find.byKey(const Key('fakeMoveMap')));
    await tester.pump();

    expect(find.textContaining('35.68123'), findsOneWidget);

    await tester.tap(
      find.byKey(const Key('registrationPositionContinueButton')),
    );
    await tester.pump();

    expect(continued, isTrue);
  });

  testWidgets('既存draftの位置を保持して戻ってこられる', (WidgetTester tester) async {
    late ProviderContainer container;

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container = ProviderContainer(
          overrides: [
            locationServiceProvider.overrideWithValue(_FakeLocationService()),
          ],
        ),
        child: MaterialApp(
          home: V2RegistrationPositionScreen(
            autoLocate: false,
            mapBuilder: (_, initialTarget, onCameraMove, onCameraIdle) {
              return Text(
                'initial:${initialTarget.latitude.toStringAsFixed(2)},'
                '${initialTarget.longitude.toStringAsFixed(2)}',
              );
            },
          ),
        ),
      ),
    );
    addTearDown(container.dispose);

    container
        .read(machineRegistrationControllerProvider.notifier)
        .setLocation(GeoCoordinate(latitude: 35.68, longitude: 139.76));
    await tester.pump();

    expect(find.text('initial:35.68,139.76'), findsOneWidget);
  });
}

final class _FakeLocationService implements LocationService {
  @override
  Future<AppLocationPermission> checkPermission() async {
    return AppLocationPermission.whileInUse;
  }

  @override
  Future<AppResult<CurrentLocation>> getCurrentLocation() async {
    return AppResult<CurrentLocation>.success(
      CurrentLocation(
        latitude: 35.68,
        longitude: 139.76,
        accuracyMeters: 10,
        capturedAt: DateTime.utc(2026, 8, 11),
      ),
    );
  }

  @override
  Future<bool> isLocationServiceEnabled() async => true;

  @override
  Future<bool> openAppSettings() async => true;

  @override
  Future<bool> openLocationSettings() async => true;

  @override
  Future<AppLocationPermission> requestPermission() async {
    return AppLocationPermission.whileInUse;
  }
}
