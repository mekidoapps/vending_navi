import '../../../../core/errors/app_failure.dart';

abstract final class EmailAuthValidator {
  static final RegExp _emailPattern = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');

  static String normalizeEmail(String value) {
    return value.trim();
  }

  static AppFailure? validateEmail(String value) {
    final email = normalizeEmail(value);

    if (email.isEmpty) {
      return const ValidationFailure(
        field: 'email',
        userMessage: 'メールアドレスを入力してください。',
      );
    }

    if (!_emailPattern.hasMatch(email)) {
      return const ValidationFailure(
        field: 'email',
        userMessage: 'メールアドレスの形式を確認してください。',
      );
    }

    return null;
  }

  static AppFailure? validatePassword(String value) {
    if (value.isEmpty) {
      return const ValidationFailure(
        field: 'password',
        userMessage: 'パスワードを入力してください。',
      );
    }

    if (value.length < 6) {
      return const ValidationFailure(
        field: 'password',
        userMessage: 'パスワードは6文字以上で入力してください。',
      );
    }

    return null;
  }

  static AppFailure? validateConfirmation({
    required String password,
    required String confirmation,
  }) {
    if (confirmation.isEmpty) {
      return const ValidationFailure(
        field: 'passwordConfirmation',
        userMessage: '確認用パスワードを入力してください。',
      );
    }

    if (password != confirmation) {
      return const ValidationFailure(
        field: 'passwordConfirmation',
        userMessage: '確認用パスワードが一致していません。',
      );
    }

    return null;
  }
}
