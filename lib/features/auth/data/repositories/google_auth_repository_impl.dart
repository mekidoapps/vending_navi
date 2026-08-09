import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/services.dart';

import '../../../../core/errors/app_failure.dart';
import '../../../../core/result/app_result.dart';
import '../../domain/entities/google_sign_in_outcome.dart';
import '../../domain/repositories/google_auth_repository.dart';
import '../mappers/auth_user_mapper.dart';
import '../mappers/firebase_auth_failure_mapper.dart';
import '../mappers/google_sign_in_failure_mapper.dart';
import '../sources/google_firebase_auth_client.dart';
import '../sources/google_sign_in_client.dart';

final class GoogleAuthRepositoryImpl implements GoogleAuthRepository {
  const GoogleAuthRepositoryImpl({
    required GoogleSignInClient googleSignInClient,
    required GoogleFirebaseAuthClient firebaseAuthClient,
  }) : _googleSignInClient = googleSignInClient,
       _firebaseAuthClient = firebaseAuthClient;

  final GoogleSignInClient _googleSignInClient;
  final GoogleFirebaseAuthClient _firebaseAuthClient;

  @override
  Future<AppResult<GoogleSignInOutcome>> signIn() async {
    try {
      final tokens = await _googleSignInClient.signIn();

      if (tokens == null) {
        return const AppResult<GoogleSignInOutcome>.success(
          GoogleSignInCancelled(),
        );
      }

      final user = await _firebaseAuthClient.signInWithTokens(tokens);

      return AppResult<GoogleSignInOutcome>.success(
        GoogleSignInCompleted(AuthUserMapper.toSession(user)),
      );
    } on FirebaseAuthException catch (error) {
      return AppResult<GoogleSignInOutcome>.failure(
        FirebaseAuthFailureMapper.fromException(error),
      );
    } on PlatformException catch (error) {
      if (GoogleSignInFailureMapper.isCancellationCode(error.code)) {
        return const AppResult<GoogleSignInOutcome>.success(
          GoogleSignInCancelled(),
        );
      }

      return AppResult<GoogleSignInOutcome>.failure(
        GoogleSignInFailureMapper.fromPlatformException(error),
      );
    } catch (_) {
      return const AppResult<GoogleSignInOutcome>.failure(UnknownFailure());
    }
  }
}
