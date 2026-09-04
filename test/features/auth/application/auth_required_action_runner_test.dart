import 'package:flutter_test/flutter_test.dart';
import 'package:vending_app/core/result/app_result.dart';
import 'package:vending_app/features/auth/application/auth_required_action_runner.dart';
import 'package:vending_app/features/auth/domain/entities/auth_session.dart';
import 'package:vending_app/features/auth/domain/entities/auth_user.dart';
import 'package:vending_app/features/auth/domain/repositories/auth_repository.dart';

void main() {
  test('ログイン済みなら認証要求せず元Actionを実行する', () async {
    final repository = _FakeAuthRepository(session: _authenticatedSession());
    final runner = AuthRequiredActionRunner(repository);

    var authRequestCount = 0;
    var actionCount = 0;

    final result = await runner.run(
      requestAuthentication: () async {
        authRequestCount += 1;
        return true;
      },
      action: () async {
        actionCount += 1;
      },
    );

    expect(result, AuthRequiredActionResult.completed);
    expect(authRequestCount, 0);
    expect(actionCount, 1);
  });

  test('session復元イベントが届くまでGuestと判定しない', () async {
    final repository = _FakeAuthRepository(session: const GuestAuthSession());
    repository.sessionStream = Stream<AuthSession>.value(_authenticatedSession());
    final runner = AuthRequiredActionRunner(repository);

    var authenticationRequested = false;
    var actionCount = 0;

    final result = await runner.run(
      requestAuthentication: () async {
        authenticationRequested = true;
        return false;
      },
      action: () async {
        actionCount += 1;
      },
    );

    expect(result, AuthRequiredActionResult.completed);
    expect(authenticationRequested, isFalse);
    expect(actionCount, 1);
  });

  test('未ログインで認証をcancelしたら元Actionを実行しない', () async {
    final repository = _FakeAuthRepository(session: const GuestAuthSession());
    final runner = AuthRequiredActionRunner(repository);

    var actionCount = 0;

    final result = await runner.run(
      requestAuthentication: () async => false,
      action: () async {
        actionCount += 1;
      },
    );

    expect(result, AuthRequiredActionResult.authenticationCancelled);
    expect(actionCount, 0);
  });

  test('未ログイン→認証成功後に元Actionを1回再開する', () async {
    final repository = _FakeAuthRepository(session: const GuestAuthSession());
    final runner = AuthRequiredActionRunner(repository);

    var actionCount = 0;

    final result = await runner.run(
      requestAuthentication: () async {
        repository.session = _authenticatedSession();
        return true;
      },
      action: () async {
        actionCount += 1;
      },
    );

    expect(result, AuthRequiredActionResult.completed);
    expect(actionCount, 1);
  });

  test('認証画面がtrueでもsessionがGuestならActionを実行しない', () async {
    final repository = _FakeAuthRepository(session: const GuestAuthSession());
    final runner = AuthRequiredActionRunner(repository);

    var actionCount = 0;

    final result = await runner.run(
      requestAuthentication: () async => true,
      action: () async {
        actionCount += 1;
      },
    );

    expect(result, AuthRequiredActionResult.authenticationNotEstablished);
    expect(actionCount, 0);
  });
}

AuthSession _authenticatedSession() {
  return AuthenticatedAuthSession(
    AuthUser(
      uid: 'auth_gate_user',
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
  Stream<AuthSession>? sessionStream;

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
