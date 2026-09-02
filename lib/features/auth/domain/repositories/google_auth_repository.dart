import '../../../../core/result/app_result.dart';
import '../entities/google_sign_in_outcome.dart';

abstract interface class GoogleAuthRepository {
  Future<AppResult<GoogleSignInOutcome>> signIn();

  /// Returns false when the account chooser is cancelled.
  Future<AppResult<bool>> reauthenticate();
}
