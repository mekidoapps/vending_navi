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
  testWidgets('ログイン済みなら登録Actionを直接実行する', (WidgetTester tester) async {
    final authRepository = _FakeAuthRepository(
      session: _authenticatedSession(),
    );

    var authenticationRequestCount = 0;
    var registerCount = 0;

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authRepositoryProvider.overrideWithValue(authRepository),
          locationServiceProvider.overrideWithValue(_FakeLocationService()),
        ],
        child: MaterialApp(
          home: V2HomeMapScreen(
            autoLocate: false,
            mapBuilder: (_) => const ColoredBox(color: Colors.white),
            authenticationRequester: () async {
              authenticationRequestCount += 1;
              return true;
            },
            onRegisterPressed: () {
              registerCount += 1;
            },
          ),
        ),
      ),
    );

    await tester.tap(find.byKey(const Key('registerMapAction')));
    await tester.pump();

    expect(authenticationRequestCount, 0);
    expect(registerCount, 1);
  });

  testWidgets('未ログイン→認証成功後に登録Actionへ復帰する', (WidgetTester tester) async {
    final authRepository = _FakeAuthRepository(
      session: const GuestAuthSession(),
    );

    var registerCount = 0;

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authRepositoryProvider.overrideWithValue(authRepository),
          locationServiceProvider.overrideWithValue(_FakeLocationService()),
        ],
        child: MaterialApp(
          home: V2HomeMapScreen(
            autoLocate: false,
            mapBuilder: (_) => const ColoredBox(color: Colors.white),
            authenticationRequester: () async {
              authRepository.session = _authenticatedSession();
              return true;
            },
            onRegisterPressed: () {
              registerCount += 1;
            },
          ),
        ),
      ),
    );

    await tester.tap(find.byKey(const Key('registerMapAction')));
    await tester.pump();

    expect(registerCount, 1);
  });

  testWidgets('未ログインで認証cancelなら登録Actionを実行しない', (WidgetTester tester) async {
    final authRepository = _FakeAuthRepository(
      session: const GuestAuthSession(),
    );

    var registerCount = 0;

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authRepositoryProvider.overrideWithValue(authRepository),
          locationServiceProvider.overrideWithValue(_FakeLocationService()),
        ],
        child: MaterialApp(
          home: V2HomeMapScreen(
            autoLocate: false,
            mapBuilder: (_) => const ColoredBox(color: Colors.white),
            authenticationRequester: () async => false,
            onRegisterPressed: () {
              registerCount += 1;
            },
          ),
        ),
      ),
    );

    await tester.tap(find.byKey(const Key('registerMapAction')));
    await tester.pump();

    expect(registerCount, 0);
  });
}

AuthSession _authenticatedSession() {
  return AuthenticatedAuthSession(
    AuthUser(
      uid: 'home_auth_user',
      email: 'user@example.com',
      displayName: null,
      providerIds: const <String>['password'],
      emailVerified: false,
    ),
  );
}

final class _FakeAuthRepository implements AuthRepository {
  _FakeAuthRepository({required this.session});

  AuthSession session;

  @override
  AuthSession get currentSession => session;

  @override
  Stream<AuthSession> watchSession() => Stream<AuthSession>.value(session);

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
  Future<AppResult<AuthSession>> signOut() async {
    session = const GuestAuthSession();
    return AppResult<AuthSession>.success(session);
  }

  @override
  Future<AppResult<bool>> sendPasswordResetEmail({required String email}) {
    throw UnimplementedError();
  }
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
