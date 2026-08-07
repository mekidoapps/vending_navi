sealed class AppFailure {
  const AppFailure({
    required this.code,
    required this.userTitle,
    required this.userMessage,
    required this.isRetryable,
  });

  /// Internal, privacy-safe error code used for branching and logging.
  final String code;

  /// Short message safe to show in the UI.
  final String userTitle;

  /// Detailed message safe to show in the UI.
  final String userMessage;

  /// Whether retrying the same operation may reasonably succeed.
  final bool isRetryable;

  @override
  String toString() => '$runtimeType(code: $code)';
}

final class NetworkFailure extends AppFailure {
  const NetworkFailure()
    : super(
        code: 'network.unavailable',
        userTitle: '通信できませんでした',
        userMessage: '通信状態を確認して、もう一度お試しください。',
        isRetryable: true,
      );
}

final class AuthenticationFailure extends AppFailure {
  const AuthenticationFailure()
    : super(
        code: 'authentication.required',
        userTitle: 'ログインが必要です',
        userMessage: 'ログインしてから、もう一度お試しください。',
        isRetryable: false,
      );
}

final class PermissionFailure extends AppFailure {
  const PermissionFailure()
    : super(
        code: 'permission.denied',
        userTitle: '操作できませんでした',
        userMessage: 'この操作を行う権限がありません。',
        isRetryable: false,
      );
}

final class LocationUnavailableFailure extends AppFailure {
  const LocationUnavailableFailure()
    : super(
        code: 'location.unavailable',
        userTitle: '現在地を取得できませんでした',
        userMessage: '少し時間をおいて、もう一度お試しください。',
        isRetryable: true,
      );
}

final class ValidationFailure extends AppFailure {
  const ValidationFailure({
    this.field,
    super.userMessage = '入力内容を確認して、もう一度お試しください。',
  }) : super(
         code: 'validation.invalid',
         userTitle: '入力内容を確認してください',
         isRetryable: false,
       );

  /// Field identifier for UI branching. Do not store entered values here.
  final String? field;
}

final class RateLimitFailure extends AppFailure {
  const RateLimitFailure()
    : super(
        code: 'rate_limit.exceeded',
        userTitle: 'しばらく待ってください',
        userMessage: '短時間に操作が集中しています。少し時間をおいて、もう一度お試しください。',
        isRetryable: true,
      );
}

final class NotFoundFailure extends AppFailure {
  const NotFoundFailure()
    : super(
        code: 'not_found',
        userTitle: '情報が見つかりません',
        userMessage: '対象の情報が削除されたか、まだ登録されていない可能性があります。',
        isRetryable: false,
      );
}

final class FirebaseFailure extends AppFailure {
  FirebaseFailure({required String plugin, required String sourceCode})
    : plugin = _safeCodePart(plugin),
      sourceCode = _safeCodePart(sourceCode),
      super(
        code: 'firebase.${_safeCodePart(plugin)}.${_safeCodePart(sourceCode)}',
        userTitle: '処理を完了できませんでした',
        userMessage: '時間をおいて、もう一度お試しください。',
        isRetryable: true,
      );

  final String plugin;
  final String sourceCode;
}

final class UnknownFailure extends AppFailure {
  const UnknownFailure()
    : super(
        code: 'unknown',
        userTitle: '予期しないエラーが発生しました',
        userMessage: '時間をおいて、もう一度お試しください。',
        isRetryable: true,
      );
}

String _safeCodePart(String value) {
  final normalized = value.trim().toLowerCase().replaceAll(
    RegExp(r'[^a-z0-9._-]+'),
    '_',
  );
  if (normalized.isEmpty) {
    return 'unknown';
  }
  return normalized.length <= 64 ? normalized : normalized.substring(0, 64);
}
