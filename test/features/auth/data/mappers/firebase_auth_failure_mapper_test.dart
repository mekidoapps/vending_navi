import 'package:flutter_test/flutter_test.dart';
import 'package:vending_app/core/errors/app_failure.dart';
import 'package:vending_app/features/auth/data/mappers/firebase_auth_failure_mapper.dart';

void main() {
  test('invalid-credentialは入力確認として安全な文言へ変換する', () {
    final failure = FirebaseAuthFailureMapper.fromCode('invalid-credential');

    expect(failure, isA<ValidationFailure>());
    expect(failure.userMessage, 'メールアドレスまたはパスワードを確認してください。');
  });

  test('user-not-foundもアカウント存在を特定しない同じ文言へ変換する', () {
    final failure = FirebaseAuthFailureMapper.fromCode('user-not-found');

    expect(failure, isA<ValidationFailure>());
    expect(failure.userMessage, 'メールアドレスまたはパスワードを確認してください。');
  });

  test('network-request-failedはNetworkFailureになる', () {
    expect(
      FirebaseAuthFailureMapper.fromCode('network-request-failed'),
      isA<NetworkFailure>(),
    );
  });

  test('未知codeはprivacy-safeなFirebaseFailureになる', () {
    final failure = FirebaseAuthFailureMapper.fromCode('unknown-auth-code');

    expect(failure, isA<FirebaseFailure>());
    expect(failure.code, contains('unknown-auth-code'));
  });
}
