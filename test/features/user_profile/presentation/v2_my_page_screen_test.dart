import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vending_app/app/theme/v2_theme.dart';
import 'package:vending_app/core/result/app_result.dart';
import 'package:vending_app/features/auth/application/providers/auth_providers.dart';
import 'package:vending_app/features/auth/domain/entities/auth_session.dart';
import 'package:vending_app/features/auth/domain/entities/auth_user.dart';
import 'package:vending_app/features/auth/domain/repositories/auth_repository.dart';
import 'package:vending_app/features/user_profile/application/providers/user_profile_providers.dart';
import 'package:vending_app/features/user_profile/domain/entities/user_profile.dart';
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

AuthSession _authenticatedSession() {
  return AuthenticatedAuthSession(
    AuthUser(
      uid: 'screen_user',
      email: 'screen@example.com',
      displayName: 'Auth Name',
      providerIds: const <String>['google.com'],
      emailVerified: true,
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
