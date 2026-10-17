import '../../../../core/result/app_result.dart';

abstract interface class AppleAuthRepository {
  /// false means the user cancelled; cancellation is not an authentication error.
  Future<AppResult<bool>> signIn();
  Future<AppResult<bool>> reauthenticateForDeletion();
  Future<AppResult<bool>> revokeForDeletion();
  void discardDeletionAuthorization();
}
