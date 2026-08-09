import 'auth_user.dart';

sealed class AuthSession {
  const AuthSession();

  bool get isAuthenticated;
  AuthUser? get userOrNull;
}

final class GuestAuthSession extends AuthSession {
  const GuestAuthSession();

  @override
  bool get isAuthenticated => false;

  @override
  AuthUser? get userOrNull => null;
}

final class AuthenticatedAuthSession extends AuthSession {
  const AuthenticatedAuthSession(this.user);

  final AuthUser user;

  @override
  bool get isAuthenticated => true;

  @override
  AuthUser get userOrNull => user;
}
