import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vending_app/core/result/app_result.dart';
import 'package:vending_app/features/auth/application/providers/auth_providers.dart';
import 'package:vending_app/features/auth/domain/entities/auth_session.dart';
import 'package:vending_app/features/auth/domain/entities/auth_user.dart';
import 'package:vending_app/features/auth/domain/repositories/auth_repository.dart';
import 'package:vending_app/features/user_profile/application/providers/user_profile_providers.dart';
import 'package:vending_app/features/user_profile/application/v2_my_page_controller.dart';
import 'package:vending_app/features/user_profile/domain/entities/user_profile.dart';
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
}

AuthSession _authenticatedSession() {
  return AuthenticatedAuthSession(
    AuthUser(
      uid: 'my_page_user',
      email: 'user@example.com',
      displayName: 'Auth Name',
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
  Future<AppResult<AuthSession>> signOut() async {
    session = const GuestAuthSession();
    return AppResult<AuthSession>.success(session);
  }

  @override
  Future<AppResult<bool>> sendPasswordResetEmail({required String email}) {
    throw UnimplementedError();
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
