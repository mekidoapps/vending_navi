import '../entities/auth_session.dart';

abstract interface class AuthRepository {
  AuthSession get currentSession;

  Stream<AuthSession> watchSession();
}
