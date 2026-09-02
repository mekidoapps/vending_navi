import '../../../../core/result/app_result.dart';

abstract interface class AccountDeletionRepository {
  Future<AppResult<bool>> deleteAccount();
}
