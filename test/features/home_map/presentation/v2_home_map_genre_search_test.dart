import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vending_app/core/result/app_result.dart';
import 'package:vending_app/features/home_map/presentation/v2_home_map_screen.dart';
import 'package:vending_app/features/location/application/providers/location_service_provider.dart';
import 'package:vending_app/features/location/domain/entities/app_location_permission.dart';
import 'package:vending_app/features/location/domain/entities/current_location.dart';
import 'package:vending_app/features/location/domain/services/location_service.dart';

void main() {
  testWidgets('ジャンルを選ぶとパネルが閉じて選択ラベルを残す', (WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          locationServiceProvider.overrideWithValue(_FakeLocationService()),
        ],
        child: MaterialApp(
          home: V2HomeMapScreen(
            autoLocate: false,
            mapBuilder: (_) =>
                const ColoredBox(key: Key('fakeMap'), color: Colors.white),
          ),
        ),
      ),
    );

    await tester.tap(find.byKey(const Key('searchMapAction')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    expect(find.byKey(const Key('genreCandidate_coffee')), findsOneWidget);

    await tester.tap(find.byKey(const Key('genreCandidate_coffee')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    expect(find.byKey(const Key('productSearchPanel')), findsNothing);
    expect(find.byKey(const Key('selectedGenreLabel')), findsOneWidget);
    expect(find.text('コーヒー'), findsOneWidget);

    await tester.tap(find.byKey(const Key('clearSelectedGenre')));
    await tester.pump();

    expect(find.byKey(const Key('selectedGenreLabel')), findsNothing);
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
        capturedAt: DateTime.utc(2026, 8, 9),
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
