import '../domain/repositories/auth_repository.dart';

typedef AuthenticationRequester = Future<bool> Function();
typedef AuthenticatedAction = Future<void> Function();

enum AuthRequiredActionResult {
  completed,
  authenticationCancelled,
  authenticationNotEstablished,
}

final class AuthRequiredActionRunner {
  const AuthRequiredActionRunner(this._repository);

  final AuthRepository _repository;

  Future<AuthRequiredActionResult> run({
    required AuthenticationRequester requestAuthentication,
    required AuthenticatedAction action,
  }) async {
    if (_repository.currentSession.isAuthenticated) {
      await action();
      return AuthRequiredActionResult.completed;
    }

    final authenticated = await requestAuthentication();
    if (!authenticated) {
      return AuthRequiredActionResult.authenticationCancelled;
    }

    if (!_repository.currentSession.isAuthenticated) {
      return AuthRequiredActionResult.authenticationNotEstablished;
    }

    await action();
    return AuthRequiredActionResult.completed;
  }
}
