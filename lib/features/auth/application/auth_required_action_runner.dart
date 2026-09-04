import '../domain/repositories/auth_repository.dart';
import '../domain/entities/auth_session.dart';

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
    final initialSession = await _resolveSession();
    if (initialSession.isAuthenticated) {
      await action();
      return AuthRequiredActionResult.completed;
    }

    final authenticated = await requestAuthentication();
    if (!authenticated) {
      return AuthRequiredActionResult.authenticationCancelled;
    }

    final authenticatedSession = await _resolveSession();
    if (!authenticatedSession.isAuthenticated) {
      return AuthRequiredActionResult.authenticationNotEstablished;
    }

    await action();
    return AuthRequiredActionResult.completed;
  }

  /// Firebase Auth restores persisted credentials asynchronously at startup.
  /// Wait for its first state event instead of treating a transient null
  /// [currentUser] as a guest session.
  Future<AuthSession> _resolveSession() => _repository.watchSession().first;
}
