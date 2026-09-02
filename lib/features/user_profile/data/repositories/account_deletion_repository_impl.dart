import '../../../../core/errors/app_failure.dart';
import '../../../../core/errors/failure_mapper.dart';
import '../../../../core/result/app_result.dart';
import '../../domain/repositories/account_deletion_repository.dart';
import '../sources/account_deletion_data_source.dart';

final class AccountDeletionRepositoryImpl implements AccountDeletionRepository {
  const AccountDeletionRepositoryImpl(this._source);

  final AccountDeletionDataSource _source;

  @override
  Future<AppResult<bool>> deleteAccount() async {
    try {
      final response = await _source.deleteAccount();

      if (response['deleted'] != true) {
        return const AppResult<bool>.failure(
          ValidationFailure(
            field: 'accountDeletion',
            userMessage: 'アカウント削除の完了を確認できませんでした。',
          ),
        );
      }

      return const AppResult<bool>.success(true);
    } on Object catch (error) {
      return AppResult<bool>.failure(FailureMapper.map(error));
    }
  }
}
