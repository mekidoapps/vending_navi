import 'package:firebase_auth/firebase_auth.dart';

import '../../../../core/errors/app_failure.dart';
import '../../../../core/result/app_result.dart';
import '../../domain/entities/auth_session.dart';
import '../../domain/repositories/auth_repository.dart';
import '../mappers/auth_user_mapper.dart';
import '../mappers/firebase_auth_failure_mapper.dart';
import '../sources/auth_data_source.dart';

final class AuthRepositoryImpl implements AuthRepository {
  const AuthRepositoryImpl(this._source);

  final AuthDataSource _source;

  @override
  AuthSession get currentSession {
    return AuthUserMapper.toSession(_source.currentUser);
  }

  @override
  Stream<AuthSession> watchSession() {
    return _source.authStateChanges().map(AuthUserMapper.toSession);
  }

  @override
  Future<AppResult<AuthSession>> signInWithEmail({
    required String email,
    required String password,
  }) async {
    try {
      final user = await _source.signInWithEmail(
        email: email,
        password: password,
      );
      return AppResult<AuthSession>.success(AuthUserMapper.toSession(user));
    } on FirebaseAuthException catch (error) {
      return AppResult<AuthSession>.failure(
        FirebaseAuthFailureMapper.fromException(error),
      );
    } catch (_) {
      return const AppResult<AuthSession>.failure(UnknownFailure());
    }
  }

  @override
  Future<AppResult<AuthSession>> registerWithEmail({
    required String email,
    required String password,
  }) async {
    try {
      final user = await _source.registerWithEmail(
        email: email,
        password: password,
      );
      return AppResult<AuthSession>.success(AuthUserMapper.toSession(user));
    } on FirebaseAuthException catch (error) {
      return AppResult<AuthSession>.failure(
        FirebaseAuthFailureMapper.fromException(error),
      );
    } catch (_) {
      return const AppResult<AuthSession>.failure(UnknownFailure());
    }
  }

  @override
  Future<AppResult<AuthSession>> signOut() async {
    try {
      await _source.signOut();
      return const AppResult<AuthSession>.success(GuestAuthSession());
    } on FirebaseAuthException catch (error) {
      return AppResult<AuthSession>.failure(
        FirebaseAuthFailureMapper.fromException(error),
      );
    } catch (_) {
      return const AppResult<AuthSession>.failure(UnknownFailure());
    }
  }

  @override
  Future<AppResult<bool>> sendPasswordResetEmail({
    required String email,
  }) async {
    try {
      await _source.sendPasswordResetEmail(email: email);
      return const AppResult<bool>.success(true);
    } on FirebaseAuthException catch (error) {
      if (error.code.trim().toLowerCase() == 'user-not-found') {
        // Account existence must not be exposed from the password-reset UI.
        return const AppResult<bool>.success(true);
      }

      return AppResult<bool>.failure(
        FirebaseAuthFailureMapper.fromException(error),
      );
    } catch (_) {
      return const AppResult<bool>.failure(UnknownFailure());
    }
  }
}
