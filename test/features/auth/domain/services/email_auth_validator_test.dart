import 'package:flutter_test/flutter_test.dart';
import 'package:vending_app/features/auth/domain/services/email_auth_validator.dart';

void main() {
  test('email前後空白はnormalizeで除去する', () {
    expect(
      EmailAuthValidator.normalizeEmail('  user@example.com '),
      'user@example.com',
    );
  });

  test('不正emailをrejectする', () {
    expect(EmailAuthValidator.validateEmail('not-an-email'), isNotNull);
  });

  test('6文字未満passwordをrejectする', () {
    expect(EmailAuthValidator.validatePassword('12345'), isNotNull);
  });

  test('確認password不一致をrejectする', () {
    expect(
      EmailAuthValidator.validateConfirmation(
        password: '123456',
        confirmation: '123457',
      ),
      isNotNull,
    );
  });
}
