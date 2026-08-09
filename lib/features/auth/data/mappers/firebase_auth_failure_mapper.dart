import 'package:firebase_auth/firebase_auth.dart';

import '../../../../core/errors/app_failure.dart';

abstract final class FirebaseAuthFailureMapper {
  static AppFailure fromException(FirebaseAuthException exception) {
    return fromCode(exception.code);
  }

  static AppFailure fromCode(String code) {
    return switch (code.trim().toLowerCase()) {
      'network-request-failed' => const NetworkFailure(),
      'too-many-requests' => const RateLimitFailure(),
      'invalid-email' => const ValidationFailure(
        field: 'email',
        userMessage: 'メールアドレスの形式を確認してください。',
      ),
      'weak-password' => const ValidationFailure(
        field: 'password',
        userMessage: 'パスワードの条件を確認してください。',
      ),
      'email-already-in-use' => const ValidationFailure(
        field: 'email',
        userMessage: 'このメールアドレスはすでに登録されています。ログインをお試しください。',
      ),
      'invalid-credential' ||
      'wrong-password' ||
      'user-not-found' => const ValidationFailure(
        field: 'credentials',
        userMessage: 'メールアドレスまたはパスワードを確認してください。',
      ),
      'user-disabled' => const ValidationFailure(
        field: 'credentials',
        userMessage: 'このアカウントではログインできません。',
      ),
      _ => FirebaseFailure(plugin: 'firebase_auth', sourceCode: code),
    };
  }
}
