import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vending_app/app/theme/v2_theme.dart';
import 'package:vending_app/core/result/app_result.dart';
import 'package:vending_app/features/auth/application/providers/auth_providers.dart';
import 'package:vending_app/features/auth/application/providers/google_auth_providers.dart';
import 'package:vending_app/features/auth/domain/entities/auth_session.dart';
import 'package:vending_app/features/auth/domain/entities/auth_user.dart';
import 'package:vending_app/features/auth/domain/entities/google_sign_in_outcome.dart';
import 'package:vending_app/features/auth/domain/repositories/auth_repository.dart';
import 'package:vending_app/features/auth/domain/repositories/google_auth_repository.dart';
import 'package:vending_app/features/user_profile/application/providers/user_profile_providers.dart';
import 'package:vending_app/features/user_profile/domain/entities/user_profile.dart';
import 'package:vending_app/features/user_profile/domain/repositories/account_deletion_repository.dart';
import 'package:vending_app/features/user_profile/domain/repositories/user_profile_repository.dart';
import 'package:vending_app/features/user_profile/presentation/v2_my_page_screen.dart';

void main() {
  testWidgets('未ログインではゲスト表示とログイン導線を出す', (WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authRepositoryProvider.overrideWithValue(
            _FakeAuthRepository(session: const GuestAuthSession()),
          ),
          userProfileRepositoryProvider.overrideWithValue(
            _FakeUserProfileRepository(),
          ),
        ],
        child: MaterialApp(
          theme: V2Theme.light(),
          home: const V2MyPageScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('v2MyPageGuestView')), findsOneWidget);
    expect(find.text('ゲスト利用中'), findsOneWidget);
    expect(find.byKey(const Key('myPageLoginButton')), findsOneWidget);
    expect(find.byKey(const Key('myPageDeleteAccountButton')), findsNothing);
  });

  testWidgets('ログイン済みではprofile・email・logoutを表示する', (WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authRepositoryProvider.overrideWithValue(
            _FakeAuthRepository(session: _authenticatedSession()),
          ),
          userProfileRepositoryProvider.overrideWithValue(
            _FakeUserProfileRepository(
              profile: UserProfile(
                uid: 'screen_user',
                appDisplayName: 'Mekido',
              ),
            ),
          ),
        ],
        child: MaterialApp(
          theme: V2Theme.light(),
          home: const V2MyPageScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('v2MyPageAuthenticatedView')), findsOneWidget);
    expect(find.text('Mekido'), findsOneWidget);
    expect(find.text('screen@example.com'), findsOneWidget);
    expect(find.byKey(const Key('myPageSignOutButton')), findsOneWidget);
    expect(find.byKey(const Key('myPageDeleteAccountButton')), findsOneWidget);
  });

  testWidgets('表示名dialog保存後もdisposed controller例外を起こさない', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authRepositoryProvider.overrideWithValue(
            _FakeAuthRepository(session: _authenticatedSession()),
          ),
          userProfileRepositoryProvider.overrideWithValue(
            _FakeUserProfileRepository(
              profile: UserProfile(
                uid: 'screen_user',
                appDisplayName: 'Before',
              ),
            ),
          ),
        ],
        child: MaterialApp(
          theme: V2Theme.light(),
          home: const V2MyPageScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('myPageEditDisplayNameButton')));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const Key('myPageDisplayNameField')),
      'After',
    );
    await tester.tap(find.byKey(const Key('myPageDisplayNameSave')));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('After'), findsOneWidget);
  });

  testWidgets('削除開始をキャンセルすると削除処理を実行しない', (WidgetTester tester) async {
    final deletionRepository = _FakeAccountDeletionRepository();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authRepositoryProvider.overrideWithValue(
            _FakeAuthRepository(session: _authenticatedSession()),
          ),
          userProfileRepositoryProvider.overrideWithValue(
            _FakeUserProfileRepository(),
          ),
          accountDeletionRepositoryProvider.overrideWithValue(
            deletionRepository,
          ),
        ],
        child: MaterialApp(
          theme: V2Theme.light(),
          home: const V2MyPageScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final deleteButton = find.byKey(const Key('myPageDeleteAccountButton'));

    await tester.ensureVisible(deleteButton);
    await tester.tap(deleteButton);
    await tester.pumpAndSettle();

    expect(find.text('アカウントを削除しますか？'), findsOneWidget);

    await tester.tap(find.byKey(const Key('myPageDeleteStartCancel')));
    await tester.pumpAndSettle();

    expect(deletionRepository.callCount, 0);
  });

  testWidgets('password本人確認後にアカウントを削除してGuestへ戻る', (WidgetTester tester) async {
    final authRepository = _FakeAuthRepository(
      session: _authenticatedSession(providerIds: const <String>['password']),
    );

    final deletionRepository = _FakeAccountDeletionRepository();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authRepositoryProvider.overrideWithValue(authRepository),
          userProfileRepositoryProvider.overrideWithValue(
            _FakeUserProfileRepository(),
          ),
          accountDeletionRepositoryProvider.overrideWithValue(
            deletionRepository,
          ),
        ],
        child: MaterialApp(
          theme: V2Theme.light(),
          home: const V2MyPageScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final deleteButton = find.byKey(const Key('myPageDeleteAccountButton'));

    await tester.ensureVisible(deleteButton);
    await tester.tap(deleteButton);
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('myPageDeleteStartConfirm')));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const Key('myPageDeletePasswordField')),
      'secret',
    );

    await tester.tap(find.byKey(const Key('myPageDeletePasswordContinue')));
    await tester.pumpAndSettle();

    expect(find.text('本当に削除しますか？'), findsOneWidget);

    await tester.tap(find.byKey(const Key('myPageDeleteFinalConfirm')));
    await tester.pumpAndSettle();

    expect(authRepository.passwordReauthCount, 1);
    expect(authRepository.lastPassword, 'secret');
    expect(deletionRepository.callCount, 1);
    expect(find.byKey(const Key('v2MyPageGuestView')), findsOneWidget);
  });

  testWidgets('Google本人確認後にアカウントを削除してGuestへ戻る', (WidgetTester tester) async {
    final authRepository = _FakeAuthRepository(
      session: _authenticatedSession(providerIds: const <String>['google.com']),
    );

    final googleRepository = _FakeGoogleAuthRepository();
    final deletionRepository = _FakeAccountDeletionRepository();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authRepositoryProvider.overrideWithValue(authRepository),
          googleAuthRepositoryProvider.overrideWithValue(googleRepository),
          userProfileRepositoryProvider.overrideWithValue(
            _FakeUserProfileRepository(),
          ),
          accountDeletionRepositoryProvider.overrideWithValue(
            deletionRepository,
          ),
        ],
        child: MaterialApp(
          theme: V2Theme.light(),
          home: const V2MyPageScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final deleteButton = find.byKey(const Key('myPageDeleteAccountButton'));

    await tester.ensureVisible(deleteButton);
    await tester.tap(deleteButton);
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('myPageDeleteStartConfirm')));
    await tester.pumpAndSettle();

    expect(googleRepository.reauthCount, 1);
    expect(find.text('本当に削除しますか？'), findsOneWidget);

    await tester.tap(find.byKey(const Key('myPageDeleteFinalConfirm')));
    await tester.pumpAndSettle();

    expect(deletionRepository.callCount, 1);
    expect(find.byKey(const Key('v2MyPageGuestView')), findsOneWidget);
  });

  testWidgets('320x568でも主要操作がoverflowしない', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authRepositoryProvider.overrideWithValue(
            _FakeAuthRepository(session: _authenticatedSession()),
          ),
          userProfileRepositoryProvider.overrideWithValue(
            _FakeUserProfileRepository(
              profile: UserProfile(uid: 'screen_user'),
            ),
          ),
        ],
        child: MaterialApp(
          theme: V2Theme.light(),
          home: const V2MyPageScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(
      find.byKey(const Key('myPageEditDisplayNameButton')),
      findsOneWidget,
    );
  });
}

AuthSession _authenticatedSession({
  List<String> providerIds = const <String>['google.com'],
}) {
  return AuthenticatedAuthSession(
    AuthUser(
      uid: 'screen_user',
      email: 'screen@example.com',
      displayName: 'Auth Name',
      providerIds: providerIds,
      emailVerified: true,
    ),
  );
}

final class _FakeAuthRepository implements AuthRepository {
  _FakeAuthRepository({required this.session});

  AuthSession session;
  int passwordReauthCount = 0;
  String? lastPassword;

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
    passwordReauthCount += 1;
    lastPassword = password;
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
  int callCount = 0;

  @override
  Future<AppResult<bool>> deleteAccount() async {
    callCount += 1;
    return const AppResult<bool>.success(true);
  }
}

final class _FakeUserProfileRepository implements UserProfileRepository {
  _FakeUserProfileRepository({UserProfile? profile}) : _profile = profile;

  UserProfile? _profile;

  @override
  Future<AppResult<UserProfile>> getOrCreateProfile({
    required String uid,
  }) async {
    final profile = _profile ?? UserProfile(uid: uid);
    _profile = profile;
    return AppResult<UserProfile>.success(profile);
  }

  @override
  Future<AppResult<UserProfile>> saveDisplayName({
    required String uid,
    required String? displayName,
  }) async {
    final profile = UserProfile(
      uid: uid,
      appDisplayName: displayName,
      legacyDisplayName: displayName,
    );
    _profile = profile;
    return AppResult<UserProfile>.success(profile);
  }
}
