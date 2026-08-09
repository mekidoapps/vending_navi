import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vending_app/core/result/app_result.dart';
import 'package:vending_app/features/auth/application/email_auth_controller.dart';
import 'package:vending_app/features/auth/application/providers/auth_providers.dart';
import 'package:vending_app/features/auth/domain/entities/auth_session.dart';
import 'package:vending_app/features/auth/domain/entities/auth_user.dart';
import 'package:vending_app/features/auth/domain/repositories/auth_repository.dart';

void main() {
  test('invalid emailならRepositoryを呼ばない', () async {
    final repository = _FakeAuthRepository();
    final container = ProviderContainer(
      overrides: [authRepositoryProvider.overrideWithValue(repository)],
    );
    addTearDown(container.dispose);

    final success = await container
        .read(emailAuthControllerProvider.notifier)
        .signIn(email: 'invalid', password: '123456');

    expect(success, isFalse);
    expect(repository.signInCount, 0);
    expect(container.read(emailAuthControllerProvider).failure, isNotNull);
  });

  test('email login成功時はcompleted actionを保持する', () async {
    final repository = _FakeAuthRepository();
    final container = ProviderContainer(
      overrides: [authRepositoryProvider.overrideWithValue(repository)],
    );
    addTearDown(container.dispose);

    final success = await container
        .read(emailAuthControllerProvider.notifier)
        .signIn(email: ' user@example.com ', password: '123456');

    expect(success, isTrue);
    expect(repository.signInCount, 1);
    expect(repository.lastEmail, 'user@example.com');
  });

  test('registerでは確認password一致を要求する', () async {
    final repository = _FakeAuthRepository();
    final container = ProviderContainer(
      overrides: [authRepositoryProvider.overrideWithValue(repository)],
    );
    addTearDown(container.dispose);

    final success = await container
        .read(emailAuthControllerProvider.notifier)
        .register(
          email: 'user@example.com',
          password: '123456',
          passwordConfirmation: '654321',
        );

    expect(success, isFalse);
    expect(repository.registerCount, 0);
  });
}

final class _FakeAuthRepository implements AuthRepository {
  int signInCount = 0;
  int registerCount = 0;
  String? lastEmail;

  final AuthSession _authenticated = AuthenticatedAuthSession(
    AuthUser(
      uid: 'email_user',
      email: 'user@example.com',
      displayName: null,
      providerIds: const <String>['password'],
      emailVerified: false,
    ),
  );

  @override
  AuthSession get currentSession => const GuestAuthSession();

  @override
  Stream<AuthSession> watchSession() =>
      Stream<AuthSession>.value(currentSession);

  @override
  Future<AppResult<AuthSession>> signInWithEmail({
    required String email,
    required String password,
  }) async {
    signInCount += 1;
    lastEmail = email;
    return AppResult<AuthSession>.success(_authenticated);
  }

  @override
  Future<AppResult<AuthSession>> registerWithEmail({
    required String email,
    required String password,
  }) async {
    registerCount += 1;
    lastEmail = email;
    return AppResult<AuthSession>.success(_authenticated);
  }

  @override
  Future<AppResult<AuthSession>> signOut() async {
    return const AppResult<AuthSession>.success(GuestAuthSession());
  }

  @override
  Future<AppResult<bool>> sendPasswordResetEmail({
    required String email,
  }) async {
    lastEmail = email;
    return const AppResult<bool>.success(true);
  }
}
