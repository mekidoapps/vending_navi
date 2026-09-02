import 'package:flutter_test/flutter_test.dart';
import 'package:vending_app/features/user_profile/data/repositories/account_deletion_repository_impl.dart';
import 'package:vending_app/features/user_profile/data/sources/account_deletion_data_source.dart';

void main() {
  test('deleteAccount success requires deleted=true', () async {
    final source = _FakeAccountDeletionDataSource(
      response: const <String, Object?>{'deleted': true},
    );

    final repository = AccountDeletionRepositoryImpl(source);

    final result = await repository.deleteAccount();

    expect(result.isSuccess, isTrue);
    expect(result.valueOrNull, isTrue);
    expect(source.callCount, 1);
  });

  test('deleteAccount rejects malformed success response', () async {
    final source = _FakeAccountDeletionDataSource(
      response: const <String, Object?>{'deleted': false},
    );

    final repository = AccountDeletionRepositoryImpl(source);

    final result = await repository.deleteAccount();

    expect(result.isFailure, isTrue);
  });
}

final class _FakeAccountDeletionDataSource
    implements AccountDeletionDataSource {
  _FakeAccountDeletionDataSource({required this.response});

  final Map<String, Object?> response;

  int callCount = 0;

  @override
  Future<Map<String, Object?>> deleteAccount() async {
    callCount += 1;
    return response;
  }
}
