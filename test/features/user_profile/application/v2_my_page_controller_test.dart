import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vending_app/core/errors/app_failure.dart';
import 'package:vending_app/core/result/app_result.dart';
import 'package:vending_app/features/auth/application/providers/auth_providers.dart';
import 'package:vending_app/features/auth/application/providers/google_auth_providers.dart';
import 'package:vending_app/features/auth/domain/entities/auth_session.dart';
import 'package:vending_app/features/auth/domain/entities/auth_user.dart';
import 'package:vending_app/features/auth/domain/entities/google_sign_in_outcome.dart';
import 'package:vending_app/features/auth/domain/repositories/auth_repository.dart';
import 'package:vending_app/features/auth/domain/repositories/google_auth_repository.dart';
import 'package:vending_app/features/user_profile/application/providers/user_profile_providers.dart';
import 'package:vending_app/features/user_profile/application/v2_my_page_controller.dart';
import 'package:vending_app/features/user_profile/domain/entities/user_profile.dart';
import 'package:vending_app/features/user_profile/domain/repositories/account_deletion_repository.dart';
import 'package:vending_app/features/user_profile/domain/repositories/user_profile_repository.dart';

void main() {
  test('ログイン済みprofileを読み込みappDisplayNameを表示名に使う', () async {
    final authRepository = _FakeAuthRepository(
      session: _authenticatedSession(),
    );
    final profileRepository = _FakeUserProfileRepository(
      profile: UserProfile(
        uid: 'my_page_user',
        appDisplayName: '保存済み表示名',
        legacyDisplayName: 'legacy',
      ),
    );

    final container = ProviderContainer(
      overrides: [
        authRepositoryProvider.overrideWithValue(authRepository),
        userProfileRepositoryProvider.overrideWithValue(profileRepository),
      ],
    );
    addTearDown(container.dispose);

    final subscription = container.listen(
      v2MyPageControllerProvider,
      (_, _) {},
    );
    addTearDown(subscription.close);

    await container.read(v2MyPageControllerProvider.notifier).refresh();

    final state = container.read(v2MyPageControllerProvider);
    expect(state.isAuthenticated, isTrue);
    expect(state.resolvedDisplayName, '保存済み表示名');
    expect(profileRepository.getCount, 1);
  });

  test('auth streamの復元結果へMyPage表示も追従する', () async {
    final sessions = StreamController<AuthSession>.broadcast();
    addTearDown(sessions.close);
    final authRepository = _FakeAuthRepository(
      session: const GuestAuthSession(),
      sessionStream: sessions.stream,
    );
    final container = ProviderContainer(
      overrides: [authRepositoryProvider.overrideWithValue(authRepository)],
    );
    addTearDown(container.dispose);

    final subscription = container.listen(
      v2MyPageControllerProvider,
      (_, _) {},
    );
    addTearDown(subscription.close);

    sessions.add(_authenticatedSession());
    await Future<void>.delayed(Duration.zero);

    expect(container.read(v2MyPageControllerProvider).isAuthenticated, isTrue);
  });

  test('30文字超過の表示名はRepositoryへ送らない', () async {
    final profileRepository = _FakeUserProfileRepository(
      profile: UserProfile(uid: 'my_page_user'),
    );
    final container = ProviderContainer(
      overrides: [
        authRepositoryProvider.overrideWithValue(
          _FakeAuthRepository(session: _authenticatedSession()),
        ),
        userProfileRepositoryProvider.overrideWithValue(profileRepository),
      ],
    );
    addTearDown(container.dispose);

    final subscription = container.listen(
      v2MyPageControllerProvider,
      (_, _) {},
    );
    addTearDown(subscription.close);

    final success = await container
        .read(v2MyPageControllerProvider.notifier)
        .saveDisplayName('1234567890123456789012345678901');

    expect(success, isFalse);
    expect(profileRepository.saveCount, 0);
    expect(container.read(v2MyPageControllerProvider).failure, isNotNull);
  });

  test('logout成功後はGuest stateになる', () async {
    final authRepository = _FakeAuthRepository(
      session: _authenticatedSession(),
    );
    final container = ProviderContainer(
      overrides: [
        authRepositoryProvider.overrideWithValue(authRepository),
        userProfileRepositoryProvider.overrideWithValue(
          _FakeUserProfileRepository(profile: UserProfile(uid: 'my_page_user')),
        ),
      ],
    );
    addTearDown(container.dispose);

    final subscription = container.listen(
      v2MyPageControllerProvider,
      (_, _) {},
    );
    addTearDown(subscription.close);

    final success = await container
        .read(v2MyPageControllerProvider.notifier)
        .signOut();

    expect(success, isTrue);
    expect(container.read(v2MyPageControllerProvider).isAuthenticated, isFalse);
  });

  test('password再認証をAuthRepositoryへ委譲する', () async {
    final authRepository = _FakeAuthRepository(
      session: _authenticatedSession(),
    );

    final container = ProviderContainer(
      overrides: [authRepositoryProvider.overrideWithValue(authRepository)],
    );
    addTearDown(container.dispose);

    final subscription = container.listen(
      v2MyPageControllerProvider,
      (_, _) {},
    );
    addTearDown(subscription.close);

    final success = await container
        .read(v2MyPageControllerProvider.notifier)
        .reauthenticateWithPasswordForDeletion('secret');

    expect(success, isTrue);
    expect(authRepository.passwordReauthCount, 1);
    expect(authRepository.lastPassword, 'secret');
    expect(
      container.read(v2MyPageControllerProvider).isReauthenticating,
      isFalse,
    );
  });

  test('Google再認証をGoogleAuthRepositoryへ委譲する', () async {
    final googleRepository = _FakeGoogleAuthRepository();

    final container = ProviderContainer(
      overrides: [
        authRepositoryProvider.overrideWithValue(
          _FakeAuthRepository(
            session: _authenticatedSession(
              providerIds: const <String>['google.com'],
            ),
          ),
        ),
        googleAuthRepositoryProvider.overrideWithValue(googleRepository),
      ],
    );
    addTearDown(container.dispose);

    final subscription = container.listen(
      v2MyPageControllerProvider,
      (_, _) {},
    );
    addTearDown(subscription.close);

    final success = await container
        .read(v2MyPageControllerProvider.notifier)
        .reauthenticateWithGoogleForDeletion();

    expect(success, isTrue);
    expect(googleRepository.reauthCount, 1);
  });

  test('account deletion成功後はlocal authもGuestへ戻す', () async {
    final authRepository = _FakeAuthRepository(
      session: _authenticatedSession(),
    );

    final deletionRepository = _FakeAccountDeletionRepository(
      result: const AppResult<bool>.success(true),
    );

    final container = ProviderContainer(
      overrides: [
        authRepositoryProvider.overrideWithValue(authRepository),
        accountDeletionRepositoryProvider.overrideWithValue(deletionRepository),
      ],
    );
    addTearDown(container.dispose);

    final subscription = container.listen(
      v2MyPageControllerProvider,
      (_, _) {},
    );
    addTearDown(subscription.close);

    final success = await container
        .read(v2MyPageControllerProvider.notifier)
        .deleteAccount();

    expect(success, isTrue);
    expect(deletionRepository.callCount, 1);
    expect(authRepository.signOutCount, 1);
    expect(container.read(v2MyPageControllerProvider).isAuthenticated, isFalse);
  });

  test('account deletion失敗時は認証状態を維持してFailureを保持する', () async {
    final authRepository = _FakeAuthRepository(
      session: _authenticatedSession(),
    );

    final deletionRepository = _FakeAccountDeletionRepository(
      result: const AppResult<bool>.failure(UnknownFailure()),
    );

    final container = ProviderContainer(
      overrides: [
        authRepositoryProvider.overrideWithValue(authRepository),
        accountDeletionRepositoryProvider.overrideWithValue(deletionRepository),
      ],
    );
    addTearDown(container.dispose);

    final subscription = container.listen(
      v2MyPageControllerProvider,
      (_, _) {},
    );
    addTearDown(subscription.close);

    final success = await container
        .read(v2MyPageControllerProvider.notifier)
        .deleteAccount();

    final state = container.read(v2MyPageControllerProvider);

    expect(success, isFalse);
    expect(state.isAuthenticated, isTrue);
    expect(state.failure, isNotNull);
    expect(state.isDeletingAccount, isFalse);
    expect(authRepository.signOutCount, 0);
  });
}

AuthSession _authenticatedSession({
  List<String> providerIds = const <String>['password'],
}) {
  return AuthenticatedAuthSession(
    AuthUser(
      uid: 'my_page_user',
      email: 'user@example.com',
      displayName: 'Auth Name',
      providerIds: providerIds,
      emailVerified: false,
    ),
  );
}

final class _FakeAuthRepository implements AuthRepository {
  _FakeAuthRepository({required this.session, this.sessionStream});

  AuthSession session;
  final Stream<AuthSession>? sessionStream;
  int passwordReauthCount = 0;
  int signOutCount = 0;
  String? lastPassword;

  @override
  AuthSession get currentSession => session;

  @override
  Stream<AuthSession> watchSession() =>
      sessionStream ?? Stream<AuthSession>.value(session);

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
    passwordReauthCount += 1;
    lastPassword = password;
    return const AppResult<bool>.success(true);
  }

  @override
  Future<AppResult<AuthSession>> signOut() async {
    signOutCount += 1;
    session = const GuestAuthSession();
    return AppResult<AuthSession>.success(session);
  }

  @override
  Future<AppResult<bool>> sendPasswordResetEmail({required String email}) {
    throw UnimplementedError();
  }
}

final class _FakeGoogleAuthRepository implements GoogleAuthRepository {
  int reauthCount = 0;

  @override
  Future<AppResult<GoogleSignInOutcome>> signIn() {
    throw UnimplementedError();
  }

  @override
  Future<AppResult<bool>> reauthenticate() async {
    reauthCount += 1;
    return const AppResult<bool>.success(true);
  }
}

final class _FakeAccountDeletionRepository
    implements AccountDeletionRepository {
  _FakeAccountDeletionRepository({required this.result});

  final AppResult<bool> result;
  int callCount = 0;

  @override
  Future<AppResult<bool>> deleteAccount() async {
    callCount += 1;
    return result;
  }
}

final class _FakeUserProfileRepository implements UserProfileRepository {
  _FakeUserProfileRepository({required this.profile});

  UserProfile profile;
  int getCount = 0;
  int saveCount = 0;

  @override
  Future<AppResult<UserProfile>> getOrCreateProfile({
    required String uid,
  }) async {
    getCount += 1;
    return AppResult<UserProfile>.success(profile);
  }

  @override
  Future<AppResult<UserProfile>> saveDisplayName({
    required String uid,
    required String? displayName,
  }) async {
    saveCount += 1;
    profile = UserProfile(
      uid: uid,
      appDisplayName: displayName,
      legacyDisplayName: displayName,
    );
    return AppResult<UserProfile>.success(profile);
  }
}
