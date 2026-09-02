import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vending_app/app/theme/v2_theme.dart';
import 'package:vending_app/core/result/app_result.dart';
import 'package:vending_app/features/auth/application/providers/auth_providers.dart';
import 'package:vending_app/features/auth/domain/entities/auth_session.dart';
import 'package:vending_app/features/auth/domain/entities/auth_user.dart';
import 'package:vending_app/features/auth/domain/repositories/auth_repository.dart';
import 'package:vending_app/features/auth/presentation/v2_email_auth_screen.dart';

void main() {
  testWidgets('login/registerを切り替えられる', (WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authRepositoryProvider.overrideWithValue(_FakeAuthRepository()),
        ],
        child: MaterialApp(
          theme: V2Theme.light(),
          home: const V2EmailAuthScreen(),
        ),
      ),
    );

    expect(find.byKey(const Key('passwordConfirmationField')), findsNothing);

    await tester.tap(find.byKey(const Key('emailRegisterMode')));
    await tester.pump();

    expect(find.byKey(const Key('passwordConfirmationField')), findsOneWidget);
    expect(find.text('メールで登録する'), findsOneWidget);
  });

  testWidgets('不正emailはFirebaseへ送らず画面内Failureを出す', (WidgetTester tester) async {
    final repository = _FakeAuthRepository();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [authRepositoryProvider.overrideWithValue(repository)],
        child: MaterialApp(
          theme: V2Theme.light(),
          home: const V2EmailAuthScreen(),
        ),
      ),
    );

    await tester.enterText(find.byKey(const Key('emailField')), 'invalid');
    await tester.enterText(find.byKey(const Key('passwordField')), '123456');
    await tester.tap(find.byKey(const Key('emailAuthSubmit')));
    await tester.pump();

    expect(repository.signInCount, 0);
    expect(find.byKey(const Key('emailAuthFailure')), findsOneWidget);
  });

  testWidgets('email login成功時に呼び出し元callbackへ戻せる', (WidgetTester tester) async {
    var authenticated = false;

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authRepositoryProvider.overrideWithValue(_FakeAuthRepository()),
        ],
        child: MaterialApp(
          theme: V2Theme.light(),
          home: V2EmailAuthScreen(
            onAuthenticated: () {
              authenticated = true;
            },
          ),
        ),
      ),
    );

    await tester.enterText(
      find.byKey(const Key('emailField')),
      'user@example.com',
    );
    await tester.enterText(find.byKey(const Key('passwordField')), '123456');
    await tester.tap(find.byKey(const Key('emailAuthSubmit')));
    await tester.pump();

    expect(authenticated, isTrue);
  });

  testWidgets('320x568でもoverflowしない', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authRepositoryProvider.overrideWithValue(_FakeAuthRepository()),
        ],
        child: MaterialApp(
          theme: V2Theme.light(),
          home: const V2EmailAuthScreen(),
        ),
      ),
    );

    await tester.tap(find.byKey(const Key('emailRegisterMode')));
    await tester.pump();

    expect(tester.takeException(), isNull);
    expect(find.byKey(const Key('passwordConfirmationField')), findsOneWidget);
  });
}

final class _FakeAuthRepository implements AuthRepository {
  int signInCount = 0;

  AuthSession get _authenticated => AuthenticatedAuthSession(
    AuthUser(
      uid: 'screen_user',
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
    return AppResult<AuthSession>.success(_authenticated);
  }

  @override
  Future<AppResult<AuthSession>> registerWithEmail({
    required String email,
    required String password,
  }) async {
    return AppResult<AuthSession>.success(_authenticated);
  }

  @override
  Future<AppResult<bool>> reauthenticateWithPassword({
    required String password,
  }) async {
    return const AppResult<bool>.success(true);
  }

  @override
  Future<AppResult<AuthSession>> signOut() async {
    return const AppResult<AuthSession>.success(GuestAuthSession());
  }

  @override
  Future<AppResult<bool>> sendPasswordResetEmail({
    required String email,
  }) async {
    return const AppResult<bool>.success(true);
  }
}
