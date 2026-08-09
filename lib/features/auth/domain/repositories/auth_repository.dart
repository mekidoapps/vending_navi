import '../../../../core/result/app_result.dart';
import '../entities/auth_session.dart';

abstract interface class AuthRepository {
  AuthSession get currentSession;

  Stream<AuthSession> watchSession();

  Future<AppResult<AuthSession>> signInWithEmail({
    required String email,
    required String password,
  });

  Future<AppResult<AuthSession>> registerWithEmail({
    required String email,
    required String password,
  });

  Future<AppResult<AuthSession>> signOut();

  Future<AppResult<bool>> sendPasswordResetEmail({required String email});
}
