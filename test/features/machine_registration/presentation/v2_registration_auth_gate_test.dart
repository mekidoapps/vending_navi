import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:vending_app/app/router/app_route.dart';
import 'package:vending_app/core/result/app_result.dart';
import 'package:vending_app/features/auth/application/providers/auth_providers.dart';
import 'package:vending_app/features/auth/domain/entities/auth_session.dart';
import 'package:vending_app/features/auth/domain/entities/auth_user.dart';
import 'package:vending_app/features/auth/domain/repositories/auth_repository.dart';
import 'package:vending_app/features/machine_registration/application/machine_registration_controller.dart';
import 'package:vending_app/features/machine_registration/presentation/v2_registration_auth_gate.dart';
import 'package:vending_app/features/vending_machine/domain/value_objects/geo_coordinate.dart';

void main() {
  testWidgets('途中ログイン後は同じdraftのまま元操作を続ける', (tester) async {
    final repository = _FakeAuthRepository(const GuestAuthSession());
    final container = ProviderContainer(
      overrides: [authRepositoryProvider.overrideWithValue(repository)],
    );
    addTearDown(container.dispose);
    container
        .read(machineRegistrationControllerProvider.notifier)
        .setLocation(GeoCoordinate(latitude: 35.68, longitude: 139.76));

    var actionCount = 0;
    final router = _router(container, repository, () => actionCount += 1);
    addTearDown(router.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('runRegistrationAuthGate')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('loginRequiredContinue')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('completeRegistrationAuth')));
    await tester.pumpAndSettle();

    expect(actionCount, 1);
    expect(find.byKey(const Key('registrationAuthOrigin')), findsOneWidget);
    expect(
      container
          .read(machineRegistrationControllerProvider)
          .draft
          .location
          ?.latitude,
      35.68,
    );
  });

  testWidgets('途中ログインを中止してもdraftと元画面を維持する', (tester) async {
    final repository = _FakeAuthRepository(const GuestAuthSession());
    final container = ProviderContainer(
      overrides: [authRepositoryProvider.overrideWithValue(repository)],
    );
    addTearDown(container.dispose);
    container
        .read(machineRegistrationControllerProvider.notifier)
        .setLocation(GeoCoordinate(latitude: 35.68, longitude: 139.76));

    var actionCount = 0;
    final router = _router(container, repository, () => actionCount += 1);
    addTearDown(router.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('runRegistrationAuthGate')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('loginRequiredCancel')));
    await tester.pumpAndSettle();

    expect(actionCount, 0);
    expect(find.byKey(const Key('registrationAuthOrigin')), findsOneWidget);
    expect(
      container
          .read(machineRegistrationControllerProvider)
          .draft
          .location
          ?.latitude,
      35.68,
    );
  });
}

GoRouter _router(
  ProviderContainer container,
  _FakeAuthRepository repository,
  VoidCallback onAuthenticatedAction,
) {
  return GoRouter(
    initialLocation: AppRoute.v2RegistrationPhoto.path,
    routes: <RouteBase>[
      GoRoute(
        path: AppRoute.v2RegistrationPhoto.path,
        name: AppRoute.v2RegistrationPhoto.name,
        builder: (_, _) => Consumer(
          builder: (context, ref, _) => Scaffold(
            key: const Key('registrationAuthOrigin'),
            body: Center(
              child: FilledButton(
                key: const Key('runRegistrationAuthGate'),
                onPressed: () {
                  V2RegistrationAuthGate.run(
                    context,
                    ref,
                    actionLabel: '写真からの自販機登録',
                    action: () async => onAuthenticatedAction(),
                  );
                },
                child: const Text('写真を撮る'),
              ),
            ),
          ),
        ),
      ),
      GoRoute(
        path: AppRoute.v2EmailAuth.path,
        name: AppRoute.v2EmailAuth.name,
        builder: (context, _) => Scaffold(
          body: Center(
            child: FilledButton(
              key: const Key('completeRegistrationAuth'),
              onPressed: () {
                repository.session = _authenticatedSession();
                Navigator.of(context).pop(true);
              },
              child: const Text('認証を完了'),
            ),
          ),
        ),
      ),
    ],
  );
}

AuthSession _authenticatedSession() => AuthenticatedAuthSession(
  AuthUser(
    uid: 'registration-user',
    email: 'registration@example.com',
    displayName: null,
    providerIds: const <String>['password'],
    emailVerified: true,
  ),
);

final class _FakeAuthRepository implements AuthRepository {
  _FakeAuthRepository(this.session);

  AuthSession session;

  @override
  AuthSession get currentSession => session;

  @override
  Stream<AuthSession> watchSession() => Stream<AuthSession>.value(session);

  @override
  Future<AppResult<AuthSession>> registerWithEmail({
    required String email,
    required String password,
  }) => throw UnimplementedError();

  @override
  Future<AppResult<AuthSession>> signInWithEmail({
    required String email,
    required String password,
  }) => throw UnimplementedError();

  @override
  Future<AppResult<AuthSession>> signOut() => throw UnimplementedError();

  @override
  Future<AppResult<bool>> reauthenticateWithPassword({
    required String password,
  }) => throw UnimplementedError();

  @override
  Future<AppResult<bool>> sendPasswordResetEmail({required String email}) =>
      throw UnimplementedError();
}
