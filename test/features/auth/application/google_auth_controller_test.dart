import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vending_app/core/errors/app_failure.dart';
import 'package:vending_app/core/result/app_result.dart';
import 'package:vending_app/features/auth/application/google_auth_controller.dart';
import 'package:vending_app/features/auth/application/google_auth_state.dart';
import 'package:vending_app/features/auth/application/providers/google_auth_providers.dart';
import 'package:vending_app/features/auth/domain/entities/auth_session.dart';
import 'package:vending_app/features/auth/domain/entities/auth_user.dart';
import 'package:vending_app/features/auth/domain/entities/google_sign_in_outcome.dart';
import 'package:vending_app/features/auth/domain/repositories/google_auth_repository.dart';

void main() {
  test('successはauthenticatedを返す', () async {
    final container = ProviderContainer(
      overrides: [
        googleAuthRepositoryProvider.overrideWithValue(
          _FakeGoogleAuthRepository(
            AppResult<GoogleSignInOutcome>.success(
              GoogleSignInCompleted(
                AuthenticatedAuthSession(
                  AuthUser(
                    uid: 'google_user',
                    email: 'google@example.com',
                    displayName: 'Google User',
                    providerIds: <String>['google.com'],
                    emailVerified: true,
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
    addTearDown(container.dispose);

    final result = await container
        .read(googleAuthControllerProvider.notifier)
        .signIn();

    expect(result, GoogleAuthActionResult.authenticated);
  });

  test('cancelはFailureを保持しない', () async {
    final container = ProviderContainer(
      overrides: [
        googleAuthRepositoryProvider.overrideWithValue(
          _FakeGoogleAuthRepository(
            const AppResult<GoogleSignInOutcome>.success(
              GoogleSignInCancelled(),
            ),
          ),
        ),
      ],
    );
    addTearDown(container.dispose);

    final result = await container
        .read(googleAuthControllerProvider.notifier)
        .signIn();

    expect(result, GoogleAuthActionResult.cancelled);
    expect(container.read(googleAuthControllerProvider).failure, isNull);
  });

  test('failureはstateへ保持する', () async {
    final container = ProviderContainer(
      overrides: [
        googleAuthRepositoryProvider.overrideWithValue(
          _FakeGoogleAuthRepository(
            const AppResult<GoogleSignInOutcome>.failure(NetworkFailure()),
          ),
        ),
      ],
    );
    addTearDown(container.dispose);

    final result = await container
        .read(googleAuthControllerProvider.notifier)
        .signIn();

    expect(result, GoogleAuthActionResult.failed);
    expect(
      container.read(googleAuthControllerProvider).failure,
      isA<NetworkFailure>(),
    );
  });
}

final class _FakeGoogleAuthRepository implements GoogleAuthRepository {
  const _FakeGoogleAuthRepository(this.result);

  final AppResult<GoogleSignInOutcome> result;

  @override
  Future<AppResult<bool>> reauthenticate() async {
    return const AppResult<bool>.success(true);
  }

  @override
  Future<AppResult<GoogleSignInOutcome>> signIn() async {
    return result;
  }
}
