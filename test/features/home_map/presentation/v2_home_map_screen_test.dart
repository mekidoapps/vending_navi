import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vending_app/core/result/app_result.dart';
import 'package:vending_app/features/auth/application/providers/auth_providers.dart';
import 'package:vending_app/features/auth/domain/entities/auth_session.dart';
import 'package:vending_app/features/auth/domain/entities/auth_user.dart';
import 'package:vending_app/features/auth/domain/repositories/auth_repository.dart';
import 'package:vending_app/features/home_map/presentation/v2_home_map_screen.dart';
import 'package:vending_app/features/location/application/providers/location_service_provider.dart';
import 'package:vending_app/features/location/domain/entities/app_location_permission.dart';
import 'package:vending_app/features/location/domain/entities/current_location.dart';
import 'package:vending_app/features/location/domain/services/location_service.dart';

void main() {
  testWidgets('全面地図と上部ラベル・右下アクションを表示する', (WidgetTester tester) async {
    var searchCount = 0;
    var registerCount = 0;
    var profileCount = 0;

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authRepositoryProvider.overrideWithValue(
            _AuthenticatedAuthRepository(),
          ),
          locationServiceProvider.overrideWithValue(_FakeLocationService()),
        ],
        child: MaterialApp(
          home: V2HomeMapScreen(
            autoLocate: false,
            mapBuilder: (_) =>
                const ColoredBox(key: Key('fakeMap'), color: Colors.white),
            onSearchPressed: () => searchCount += 1,
            onRegisterPressed: () => registerCount += 1,
            onProfilePressed: () => profileCount += 1,
          ),
        ),
      ),
    );

    expect(find.byKey(const Key('fakeMap')), findsOneWidget);
    expect(find.text('自販機ナビ'), findsOneWidget);
    expect(find.text('探す'), findsOneWidget);
    expect(find.text('登録'), findsOneWidget);
    expect(find.text('マイ'), findsOneWidget);
    expect(find.byKey(const Key('currentLocationMapAction')), findsOneWidget);

    final searchSize = tester.getSize(find.byKey(const Key('searchMapAction')));
    final registerSize = tester.getSize(
      find.byKey(const Key('registerMapAction')),
    );
    final profileSize = tester.getSize(
      find.byKey(const Key('profileMapAction')),
    );

    expect(searchSize.width, greaterThan(registerSize.width));
    expect(searchSize.height, greaterThan(registerSize.height));
    expect(searchSize.width, greaterThan(profileSize.width));

    await tester.tap(find.byKey(const Key('searchMapAction')));
    await tester.tap(find.byKey(const Key('registerMapAction')));
    await tester.tap(find.byKey(const Key('profileMapAction')));
    await tester.pump();

    expect(searchCount, 1);
    expect(registerCount, 1);
    expect(profileCount, 1);
  });

  testWidgets('位置情報サービスOFFでも地図を残して設定導線を表示する', (WidgetTester tester) async {
    final service = _FakeLocationService(serviceEnabled: false);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [locationServiceProvider.overrideWithValue(service)],
        child: MaterialApp(
          home: V2HomeMapScreen(
            mapBuilder: (_) =>
                const ColoredBox(key: Key('fakeMap'), color: Colors.white),
          ),
        ),
      ),
    );

    await tester.pump();
    await tester.pump();

    expect(find.byKey(const Key('fakeMap')), findsOneWidget);
    expect(find.text('位置情報がオフです'), findsOneWidget);
    expect(find.text('設定を開く'), findsOneWidget);

    await tester.tap(find.text('設定を開く'));
    await tester.pump();

    expect(service.openLocationSettingsCalls, 1);
  });

  testWidgets('現在地取得成功後は位置案内カードを表示し続けない', (WidgetTester tester) async {
    final service = _FakeLocationService(
      permission: AppLocationPermission.whileInUse,
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [locationServiceProvider.overrideWithValue(service)],
        child: MaterialApp(
          home: V2HomeMapScreen(
            mapBuilder: (_) =>
                const ColoredBox(key: Key('fakeMap'), color: Colors.white),
          ),
        ),
      ),
    );

    await tester.pump();
    await tester.pump();

    expect(find.byKey(const Key('fakeMap')), findsOneWidget);
    expect(find.text('現在地を確認しています'), findsNothing);
    expect(find.text('位置情報がオフです'), findsNothing);
    expect(service.getLocationCalls, 1);
  });

  testWidgets('文字を2倍にしてもホーム主要操作が画面内に残る', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          locationServiceProvider.overrideWithValue(_FakeLocationService()),
        ],
        child: MaterialApp(
          builder: (context, child) {
            return MediaQuery(
              data: MediaQuery.of(
                context,
              ).copyWith(textScaler: const TextScaler.linear(2)),
              child: child!,
            );
          },
          home: V2HomeMapScreen(
            autoLocate: false,
            mapBuilder: (_) =>
                const ColoredBox(key: Key('fakeMap'), color: Colors.white),
          ),
        ),
      ),
    );

    await tester.pump();

    expect(tester.takeException(), isNull);
    expect(find.text('探す'), findsOneWidget);
    expect(find.text('登録'), findsOneWidget);
    expect(find.text('マイ'), findsOneWidget);
  });
}

final class _FakeLocationService implements LocationService {
  _FakeLocationService({
    this.serviceEnabled = true,
    this.permission = AppLocationPermission.whileInUse,
  });

  final bool serviceEnabled;
  final AppLocationPermission permission;

  int getLocationCalls = 0;
  int openLocationSettingsCalls = 0;

  @override
  Future<bool> isLocationServiceEnabled() async => serviceEnabled;

  @override
  Future<AppLocationPermission> checkPermission() async => permission;

  @override
  Future<AppLocationPermission> requestPermission() async => permission;

  @override
  Future<AppResult<CurrentLocation>> getCurrentLocation() async {
    getLocationCalls += 1;
    return AppResult<CurrentLocation>.success(
      CurrentLocation(
        latitude: 35.681236,
        longitude: 139.767125,
        accuracyMeters: 10,
        capturedAt: DateTime.utc(2026, 8, 7),
      ),
    );
  }

  @override
  Future<bool> openAppSettings() async => true;

  @override
  Future<bool> openLocationSettings() async {
    openLocationSettingsCalls += 1;
    return true;
  }
}

final class _AuthenticatedAuthRepository implements AuthRepository {
  final AuthSession _session = AuthenticatedAuthSession(
    AuthUser(
      uid: 'home_map_test_user',
      email: 'test@example.com',
      displayName: null,
      providerIds: const <String>['password'],
      emailVerified: false,
    ),
  );

  @override
  AuthSession get currentSession => _session;

  @override
  Stream<AuthSession> watchSession() {
    return Stream<AuthSession>.value(_session);
  }

  @override
  Future<AppResult<AuthSession>> signInWithEmail({
    required String email,
    required String password,
  }) {
    throw UnimplementedError();
  }

  @override
  Future<AppResult<AuthSession>> registerWithEmail({
    required String email,
    required String password,
  }) {
    throw UnimplementedError();
  }

  @override
  Future<AppResult<bool>> reauthenticateWithPassword({
    required String password,
  }) async {
    return const AppResult<bool>.success(true);
  }

  @override
  Future<AppResult<AuthSession>> signOut() {
    return Future<AppResult<AuthSession>>.value(
      const AppResult<AuthSession>.success(GuestAuthSession()),
    );
  }

  @override
  Future<AppResult<bool>> sendPasswordResetEmail({required String email}) {
    throw UnimplementedError();
  }
}
